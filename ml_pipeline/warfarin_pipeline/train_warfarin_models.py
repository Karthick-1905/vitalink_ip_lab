import pandas as pd
import numpy as np
import os
import json
import matplotlib.pyplot as plt
import shap
import optuna
from sklearn.compose import ColumnTransformer
from sklearn.impute import KNNImputer, SimpleImputer
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import OneHotEncoder, PolynomialFeatures, StandardScaler
from xgboost import XGBRegressor
from lightgbm import LGBMRegressor
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    r2_score,
    recall_score,
)
import warnings

from preprocessing import create_preprocessor, load_dataframe, prepare_warfarin_dose_dataset

warnings.filterwarnings('ignore')

file_path = os.getenv("WARFARIN_TRAIN_DATA", './warfarin_pipeline/data/iwpc_warfarin.xls')

df = load_dataframe(file_path)

X, y, num_features, cat_features_clinical, cat_features_genetic, is_iwpc_schema = prepare_warfarin_dose_dataset(df)

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
y_test_true_dose = y_test

preprocessor_clinical = create_preprocessor(num_features, cat_features_clinical)
preprocessor_pgx = create_preprocessor(num_features, cat_features_clinical + cat_features_genetic)


def create_clinical_formula_preprocessor(num_cols, cat_cols, degree=2, interaction_only=False):
    num_transformer = Pipeline(
        steps=[
            ("imputer", KNNImputer(n_neighbors=5)),
            ("scaler", StandardScaler()),
            (
                "poly",
                PolynomialFeatures(
                    degree=int(degree),
                    include_bias=False,
                    interaction_only=bool(interaction_only),
                ),
            ),
        ]
    )

    cat_transformer = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="constant", fill_value="Unknown")),
            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]
    )

    return ColumnTransformer(
        transformers=[
            ("num", num_transformer, num_cols),
            ("cat", cat_transformer, cat_cols),
        ]
    )

def tune_models(X_tr, y_tr, trials=20, random_state=42):
    x_fit, x_val, y_fit, y_val = train_test_split(X_tr, y_tr, test_size=0.2, random_state=random_state)
    optuna.logging.set_verbosity(optuna.logging.WARNING)

    def xgb_objective(trial):
        params = {
            'objective': 'reg:squarederror',
            'n_estimators': trial.suggest_int('n_estimators', 200, 600),
            'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.12, log=True),
            'max_depth': trial.suggest_int('max_depth', 3, 7),
            'min_child_weight': trial.suggest_int('min_child_weight', 1, 8),
            'subsample': trial.suggest_float('subsample', 0.7, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'gamma': trial.suggest_float('gamma', 1e-8, 1.0, log=True),
            'reg_alpha': trial.suggest_float('reg_alpha', 1e-8, 1.0, log=True),
            'reg_lambda': trial.suggest_float('reg_lambda', 1e-3, 5.0, log=True),
            'random_state': random_state,
            'n_jobs': -1,
        }
        model = Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', XGBRegressor(**params))])
        model.fit(x_fit, y_fit)
        pred = np.maximum(model.predict(x_val), 0)
        return float(np.sqrt(mean_squared_error(y_val, pred)))

    def clinical_objective(trial):
        degree = trial.suggest_int('degree', 1, 3)
        interaction_only = trial.suggest_categorical('interaction_only', [False, True])
        include_genetics = trial.suggest_categorical('include_genetics', [False, True])
        clinical_cats = cat_features_clinical + cat_features_genetic if include_genetics else cat_features_clinical
        clinical_preprocessor = create_clinical_formula_preprocessor(
            num_features,
            clinical_cats,
            degree=degree,
            interaction_only=interaction_only,
        )
        model = Pipeline(steps=[('preprocessor', clinical_preprocessor), ('regressor', LinearRegression())])
        model.fit(x_fit, y_fit)
        pred = np.maximum(model.predict(x_val), 0)
        return float(np.sqrt(mean_squared_error(y_val, pred)))

    def rf_objective(trial):
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 150, 700),
            'max_depth': trial.suggest_int('max_depth', 5, 30),
            'min_samples_split': trial.suggest_int('min_samples_split', 2, 20),
            'min_samples_leaf': trial.suggest_int('min_samples_leaf', 1, 10),
            'max_features': trial.suggest_categorical('max_features', ['sqrt', 'log2', None]),
            'random_state': random_state,
            'n_jobs': -1,
        }
        model = Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', RandomForestRegressor(**params))])
        model.fit(x_fit, y_fit)
        pred = np.maximum(model.predict(x_val), 0)
        return float(np.sqrt(mean_squared_error(y_val, pred)))

    def lgbm_objective(trial):
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 200, 700),
            'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.10, log=True),
            'num_leaves': trial.suggest_int('num_leaves', 20, 80),
            'max_depth': trial.suggest_int('max_depth', 3, 8),
            'min_child_samples': trial.suggest_int('min_child_samples', 10, 50),
            'subsample': trial.suggest_float('subsample', 0.7, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'reg_alpha': trial.suggest_float('reg_alpha', 1e-8, 1.0, log=True),
            'reg_lambda': trial.suggest_float('reg_lambda', 1e-3, 5.0, log=True),
            'random_state': random_state,
            'verbose': -1,
        }
        model = Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', LGBMRegressor(**params))])
        model.fit(x_fit, y_fit)
        pred = np.maximum(model.predict(x_val), 0)
        return float(np.sqrt(mean_squared_error(y_val, pred)))

    xgb_study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed=random_state))
    xgb_study.optimize(xgb_objective, n_trials=trials, show_progress_bar=False)

    rf_study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed=random_state + 2))
    rf_study.optimize(rf_objective, n_trials=trials, show_progress_bar=False)

    clinical_study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed=random_state + 3))
    clinical_study.optimize(clinical_objective, n_trials=trials, show_progress_bar=False)

    lgbm_study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed=random_state + 1))
    lgbm_study.optimize(lgbm_objective, n_trials=trials, show_progress_bar=False)

    return clinical_study.best_params, rf_study.best_params, xgb_study.best_params, lgbm_study.best_params


def build_models(clinical_params, rf_params, xgb_params, lgbm_params):
    clinical_include_genetics = clinical_params.get('include_genetics', False)
    clinical_cats = cat_features_clinical + cat_features_genetic if clinical_include_genetics else cat_features_clinical
    clinical_preprocessor = create_clinical_formula_preprocessor(
        num_features,
        clinical_cats,
        degree=clinical_params.get('degree', 2),
        interaction_only=clinical_params.get('interaction_only', False),
    )
    rf_full = {
        'random_state': 42,
        'n_jobs': -1,
        **rf_params,
    }
    xgb_full = {
        'objective': 'reg:squarederror',
        'random_state': 42,
        'n_jobs': -1,
        **xgb_params,
    }
    lgbm_full = {
        'random_state': 42,
        'verbose': -1,
        **lgbm_params,
    }
    return {
        "1. Clinical Formula": Pipeline(steps=[('preprocessor', clinical_preprocessor), ('regressor', LinearRegression())]),
        "2. Ridge Regression": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', Ridge(alpha=1.0))]),
        "3. Random Forest": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', RandomForestRegressor(**rf_full))]),
        "4. XGBoost": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', XGBRegressor(**xgb_full))]),
        "5. LightGBM": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', LGBMRegressor(**lgbm_full))]),
    }

def calculate_metrics(y_true, y_pred):
    y_true = np.asarray(y_true)
    y_pred = np.asarray(y_pred)

    mae = mean_absolute_error(y_true, y_pred)
    rmse = np.sqrt(mean_squared_error(y_true, y_pred))
    r2 = r2_score(y_true, y_pred)
    within_20 = np.mean(np.abs(y_true - y_pred) <= (0.20 * y_true)) * 100
    return {
        'mae': float(mae),
        'mse': float(mean_squared_error(y_true, y_pred)),
        'rmse': float(rmse),
        'r2': float(r2),
        'within_20_pct': float(within_20),
    }


def dose_to_class(values):
    arr = np.asarray(values, dtype=float)
    return np.where(arr < 21.0, 0, np.where(arr <= 49.0, 1, 2))


def calculate_classification_metrics(y_true, y_pred):
    y_true_class = dose_to_class(y_true)
    y_pred_class = dose_to_class(y_pred)
    return {
        'accuracy': float(accuracy_score(y_true_class, y_pred_class)),
        'precision': float(precision_score(y_true_class, y_pred_class, average='macro', zero_division=0)),
        'recall': float(recall_score(y_true_class, y_pred_class, average='macro', zero_division=0)),
        'f1': float(f1_score(y_true_class, y_pred_class, average='macro', zero_division=0)),
    }


def print_metrics(name, metrics):
    print(f"\n{name}")
    print("--------------------------------------------------")
    print(f"MAE: {metrics['mae']:.2f} mg/week")
    print(f"MSE: {metrics['mse']:.2f} (mg/week)^2")
    print(f"RMSE: {metrics['rmse']:.2f} mg/week")
    print(f"R2 Score: {metrics['r2']:.3f}")
    print(f"Patients within 20% of actual dose: {metrics['within_20_pct']:.2f}%")
    if 'train_accuracy' in metrics:
        print(f"Train Accuracy (dose classes): {metrics['train_accuracy']:.3f}")
    if 'test_accuracy' in metrics:
        print(f"Test Accuracy (dose classes):  {metrics['test_accuracy']:.3f}")
    if 'precision' in metrics:
        print(f"Precision (macro): {metrics['precision']:.3f}")
    if 'recall' in metrics:
        print(f"Recall (macro):    {metrics['recall']:.3f}")
    if 'f1' in metrics:
        print(f"F1 Score (macro):  {metrics['f1']:.3f}")


def generate_shap_reports(model_name, model, X_test_frame, output_dir="output"):
    """Generate SHAP explainability artifacts for the selected best model."""
    os.makedirs(output_dir, exist_ok=True)

    model_preprocessor = model.named_steps['preprocessor']
    model_regressor = model.named_steps['regressor']

    X_processed = model_preprocessor.transform(X_test_frame)
    feature_names = model_preprocessor.get_feature_names_out()

    def clean_feature_name(name):
        cleaned = str(name).replace('num__', '').replace('cat__', '')
        cleaned = cleaned.replace('VKORC1_', 'VKORC1 ').replace('CYP2C9_', 'CYP2C9 ')
        return cleaned

    clean_feature_names = [clean_feature_name(name) for name in feature_names]
    X_processed_df = pd.DataFrame(X_processed, columns=clean_feature_names)

    if len(X_processed_df) > 400:
        X_processed_df = X_processed_df.sample(n=400, random_state=42)

    is_tree = isinstance(model_regressor, (RandomForestRegressor, XGBRegressor, LGBMRegressor))
    explainer = shap.TreeExplainer(model_regressor) if is_tree else shap.Explainer(model_regressor, X_processed_df)
    shap_values = explainer(X_processed_df)

    abs_mean = np.abs(shap_values.values).mean(axis=0)
    shap_importance = pd.DataFrame({
        'feature': clean_feature_names,
        'mean_abs_shap': abs_mean,
    }).sort_values('mean_abs_shap', ascending=False)
    shap_importance.to_csv(os.path.join(output_dir, 'shap_top_features.csv'), index=False)

    display_model_name = str(model_name).split('. ', 1)[-1]
    top_shap = shap_importance.head(15).iloc[::-1]
    plt.figure(figsize=(11, 7))
    plt.barh(top_shap['feature'], top_shap['mean_abs_shap'], color='#ff005c')
    plt.xlabel('mean(|SHAP value|)')
    plt.ylabel('Feature')
    plt.title(f"SHAP Global Importance - {display_model_name}")
    plt.grid(axis='x', linestyle='--', alpha=0.25)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'shap_summary_bar.png'), dpi=300, bbox_inches='tight')
    plt.close()

    plt.figure(figsize=(11, 7))
    shap.summary_plot(shap_values.values, X_processed_df, feature_names=clean_feature_names, max_display=15, show=False)
    plt.title(f"SHAP Summary - {display_model_name}")
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'shap_summary_beeswarm.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print("\nSaved SHAP reports:")
    print("- warfarin_pipeline/output/shap_summary_bar.png")
    print("- warfarin_pipeline/output/shap_summary_beeswarm.png")
    print("- warfarin_pipeline/output/shap_top_features.csv")


def generate_metrics_comparison_plot(leaderboard_df, output_dir="warfarin_pipeline/output"):
    os.makedirs(output_dir, exist_ok=True)
    metrics_plot_path = os.path.join(output_dir, 'model_metrics_comparison.png')

    ordered = leaderboard_df.copy().reset_index(drop=True)
    ordered['model_short'] = ordered['model'].str.replace(r'^\d+\.\s*', '', regex=True)

    metrics_spec = [
        ('mse', 'MSE', True),
        ('rmse', 'RMSE', True),
        ('r2', 'R2', False),
        ('within_20_pct', 'Within 20% (%)', False),
        ('test_accuracy', 'Test Accuracy', False),
        ('precision', 'Precision (macro)', False),
        ('recall', 'Recall (macro)', False),
        ('f1', 'F1 (macro)', False),
    ]

    fig, axes = plt.subplots(2, 4, figsize=(22, 10))
    for ax, (col, title, lower_better) in zip(axes.flat, metrics_spec):
        sorted_df = ordered.sort_values(col, ascending=lower_better)
        ax.barh(sorted_df['model_short'], sorted_df[col], color='#1f77b4')
        ax.set_title(title)
        ax.grid(axis='x', linestyle='--', alpha=0.2)

    plt.suptitle('Model Metrics Comparison', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig(metrics_plot_path, dpi=300, bbox_inches='tight')
    plt.close(fig)
    print("- warfarin_pipeline/output/model_metrics_comparison.png")


def generate_bland_altman_plot(y_true, y_pred, model_label, output_dir="warfarin_pipeline/output"):
    os.makedirs(output_dir, exist_ok=True)
    y_true_arr = np.asarray(y_true, dtype=float)
    y_pred_arr = np.asarray(y_pred, dtype=float)

    avg = (y_true_arr + y_pred_arr) / 2.0
    diff = y_pred_arr - y_true_arr
    bias = np.mean(diff)
    std_diff = np.std(diff, ddof=1)
    loa_upper = bias + 1.96 * std_diff
    loa_lower = bias - 1.96 * std_diff
    avg_min = float(np.min(avg))
    avg_max = float(np.max(avg))
    coverage_pct = float(np.mean((diff >= loa_lower) & (diff <= loa_upper)) * 100.0)

    plt.figure(figsize=(10, 7))
    plt.fill_between(
        [avg_min, avg_max],
        [loa_lower, loa_lower],
        [loa_upper, loa_upper],
        color="#7f7f7f",
        alpha=0.18,
        label=f"LoA Coverage Zone ({coverage_pct:.1f}%)",
    )
    plt.scatter(avg, diff, color="#8c2d40", alpha=0.75, s=14, edgecolors="none")
    plt.axhline(bias, color="#333333", linestyle="-", linewidth=1.5, label=f"Bias: {bias:.2f}")
    plt.axhline(loa_upper, color="#555555", linestyle="--", linewidth=1.2, label=f"Upper LoA: {loa_upper:.2f}")
    plt.axhline(loa_lower, color="#555555", linestyle="--", linewidth=1.2, label=f"Lower LoA: {loa_lower:.2f}")
    plt.xlabel("Average of Predicted and Actual Dose (mg/week)")
    plt.ylabel("Difference (Predicted - Actual) (mg/week)")
    plt.title(f"Bland-Altman Plot - {model_label}")
    plt.grid(axis="y", linestyle="--", alpha=0.25)
    plt.legend(loc="best", frameon=True)
    plt.tight_layout()

    safe_name = (
        model_label.lower()
        .replace(".", "")
        .replace(" ", "_")
        .replace("/", "_")
        .replace("-", "_")
    )
    output_path = os.path.join(output_dir, f"bland_altman_{safe_name}.png")
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"- warfarin_pipeline/output/bland_altman_{safe_name}.png")


def generate_bland_altman_for_all_models(trained_models, X_te, y_te, output_dir="warfarin_pipeline/output"):
    print("Saved Bland-Altman reports:")
    for model_name, model in trained_models.items():
        y_pred = np.maximum(model.predict(X_te), 0)
        display_name = str(model_name).split('. ', 1)[-1]
        generate_bland_altman_plot(y_te, y_pred, display_name, output_dir=output_dir)


def generate_actual_vs_predicted_plot(y_true, y_pred, model_label, output_dir="warfarin_pipeline/output"):
    os.makedirs(output_dir, exist_ok=True)
    y_true_arr = np.asarray(y_true, dtype=float)
    y_pred_arr = np.asarray(y_pred, dtype=float)

    min_val = float(min(np.min(y_true_arr), np.min(y_pred_arr)))
    max_val = float(max(np.max(y_true_arr), np.max(y_pred_arr)))

    plt.figure(figsize=(9, 7))
    plt.scatter(y_true_arr, y_pred_arr, color="#8c2d40", alpha=0.72, s=16, edgecolors="none")
    plt.plot([min_val, max_val], [min_val, max_val], color="#2f2f2f", linestyle="--", linewidth=1.6, label="Ideal fit")
    plt.xlabel("Actual Dose (mg/week)")
    plt.ylabel("Predicted Dose (mg/week)")
    plt.title(f"Actual vs Predicted - {model_label}")
    plt.grid(linestyle="--", alpha=0.25)
    plt.legend(loc="best", frameon=True)
    plt.tight_layout()

    safe_name = (
        model_label.lower()
        .replace(".", "")
        .replace(" ", "_")
        .replace("/", "_")
        .replace("-", "_")
    )
    out_path = os.path.join(output_dir, f"actual_vs_predicted_{safe_name}.png")
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"- warfarin_pipeline/output/actual_vs_predicted_{safe_name}.png")


def generate_actual_vs_predicted_for_all_models(trained_models, X_te, y_te, output_dir="warfarin_pipeline/output"):
    print("Saved Actual-vs-Predicted reports:")
    for model_name, model in trained_models.items():
        y_pred = np.maximum(model.predict(X_te), 0)
        display_name = str(model_name).split('. ', 1)[-1]
        generate_actual_vs_predicted_plot(y_te, y_pred, display_name, output_dir=output_dir)


def evaluate_model(name, model, X_tr, y_tr, X_te, y_te_true):
    model.fit(X_tr, y_tr)
    y_pred_train = np.maximum(model.predict(X_tr), 0)
    y_pred_dose = np.maximum(model.predict(X_te), 0)

    metrics = calculate_metrics(y_te_true, y_pred_dose)
    train_cls = calculate_classification_metrics(y_tr, y_pred_train)
    test_cls = calculate_classification_metrics(y_te_true, y_pred_dose)
    metrics.update(
        {
            'train_accuracy': train_cls['accuracy'],
            'test_accuracy': test_cls['accuracy'],
            'precision': test_cls['precision'],
            'recall': test_cls['recall'],
            'f1': test_cls['f1'],
        }
    )
    print_metrics(name, metrics)
    return model, metrics

print("\n4. Training and Evaluating Models...")
optuna_trials = int(os.getenv("WARFARIN_OPTUNA_TRIALS", "20"))
clinical_best_params, rf_best_params, xgb_best_params, lgbm_best_params = tune_models(X_train, y_train, trials=optuna_trials, random_state=42)
models = build_models(clinical_best_params, rf_best_params, xgb_best_params, lgbm_best_params)

os.makedirs("warfarin_pipeline/output", exist_ok=True)
with open("warfarin_pipeline/output/booster_best_params.json", "w", encoding="utf-8") as param_file:
    json.dump(
        {
            "clinical_formula": clinical_best_params,
            "random_forest": rf_best_params,
            "xgboost": xgb_best_params,
            "lightgbm": lgbm_best_params,
        },
        param_file,
        indent=2,
    )

trained_models = {}
model_results = {}
for name, pipeline in models.items():
    trained_model, metrics = evaluate_model(name, pipeline, X_train, y_train, X_test, y_test_true_dose)
    trained_models[name] = trained_model
    model_results[name] = metrics

leaderboard = (
    pd.DataFrame(model_results)
    .T
    .reset_index()
    .rename(columns={'index': 'model'})
    .sort_values(by='rmse', ascending=True)
)

leaderboard.to_csv("warfarin_pipeline/output/model_comparison_report.csv", index=False)

summary_payload = {
    'dataset': os.path.basename(file_path),
    'split': {'test_size': 0.2, 'random_state': 42},
    'models': model_results,
    'winner': leaderboard.iloc[0].to_dict(),
}
with open("warfarin_pipeline/output/model_comparison_report.json", "w", encoding="utf-8") as summary_file:
    json.dump(summary_payload, summary_file, indent=2)

print("\nTraining Complete!")
print("\nModels Metrics:")
print(leaderboard[['model', 'mae', 'mse', 'rmse', 'r2', 'within_20_pct', 'test_accuracy', 'precision', 'recall', 'f1']].to_string(index=False))
print("\nSaved comparison reports:")
print("- warfarin_pipeline/output/model_comparison_report.csv")
print("- warfarin_pipeline/output/model_comparison_report.json")
print("- warfarin_pipeline/output/booster_best_params.json")
print("Saved model metrics plot:")
generate_metrics_comparison_plot(leaderboard, output_dir="warfarin_pipeline/output")

import joblib
best_trained_model_row = leaderboard[leaderboard['model'].isin(trained_models.keys())].iloc[0]
best_model_name = best_trained_model_row['model']
best_model = trained_models[best_model_name]
os.makedirs("warfarin_pipeline/models", exist_ok=True)
joblib.dump(best_model, './warfarin_pipeline/models/best_warfarin_model.joblib')
print(f"\nSaved the best trained model ({best_model_name}) to ./warfarin_pipeline/models/best_warfarin_model.joblib")

generate_shap_reports(best_model_name, best_model, X_test, output_dir="warfarin_pipeline/output")
generate_bland_altman_for_all_models(trained_models, X_test, y_test_true_dose, output_dir="warfarin_pipeline/output")
generate_actual_vs_predicted_for_all_models(trained_models, X_test, y_test_true_dose, output_dir="warfarin_pipeline/output")
