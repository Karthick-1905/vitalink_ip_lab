import json
import warnings
from pathlib import Path

import joblib
import numpy as np
import optuna
import pandas as pd
from lightgbm import LGBMRegressor
from sklearn.base import clone
from sklearn.compose import ColumnTransformer
from sklearn.impute import KNNImputer, SimpleImputer
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import KFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from xgboost import XGBRegressor

warnings.filterwarnings("ignore")

BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "data" / "iwpc_warfarin.xls"
MODEL_OUTPUT_PATH = BASE_DIR / "models" / "best_warfarin_model.joblib"
REPORT_OUTPUT_PATH = BASE_DIR / "docs" / "optuna_tuning_report.md"
SUMMARY_OUTPUT_PATH = BASE_DIR / "output" / "optuna_tuning_summary.json"
RANDOM_STATE = 42
TEST_SIZE = 0.2
CV_SPLITS = 3
N_TRIALS = 25


def map_age(age_str):
    if pd.isna(age_str):
        return np.nan
    age_str = str(age_str).strip()
    mapping = {
        "10 - 19": 1.5,
        "20 - 29": 2.5,
        "30 - 39": 3.5,
        "40 - 49": 4.5,
        "50 - 59": 5.5,
        "60 - 69": 6.5,
        "70 - 79": 7.5,
        "80 - 89": 8.5,
        "90+": 9.5,
    }
    if age_str in mapping:
        return mapping[age_str]
    try:
        return float(age_str)
    except Exception:
        return np.nan


def map_race(race):
    if pd.isna(race):
        return "Unknown"
    race = str(race)
    if "White" in race:
        return "White"
    if "Black" in race or "African" in race:
        return "Black"
    if "Asian" in race:
        return "Asian"
    return "Other"


def load_dataset():
    print("1. Loading and preprocessing data...")
    df = pd.read_excel(DATA_PATH, sheet_name="Subject Data")
    df = df.dropna(subset=["Therapeutic Dose of Warfarin"]).copy()

    y = pd.to_numeric(df["Therapeutic Dose of Warfarin"], errors="coerce")
    y = y.fillna(y.median())

    df["Age_Num"] = df["Age"].apply(map_age)
    df["Race_Group"] = df["Race (Reported)"].apply(map_race)
    df["Amiodarone"] = pd.to_numeric(df["Amiodarone (Cordarone)"], errors="coerce").fillna(0.0)

    enzyme_cols = [
        "Carbamazepine (Tegretol)",
        "Phenytoin (Dilantin)",
        "Rifampin or Rifampicin",
    ]
    for col in enzyme_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0)
    df["Enzyme_Inducer"] = df[enzyme_cols].max(axis=1)

    common_cyp = ["*1/*1", "*1/*2", "*1/*3", "*2/*2", "*2/*3", "*3/*3"]
    df["CYP2C9"] = df["Cyp2C9 genotypes"].fillna("Unknown")
    df["CYP2C9"] = df["CYP2C9"].apply(lambda value: value if value in common_cyp else "Other/Unknown")
    df["VKORC1"] = df["VKORC1 -1639 consensus"].fillna("Unknown")

    num_features = ["Age_Num", "Height (cm)", "Weight (kg)", "Amiodarone", "Enzyme_Inducer"]
    cat_features = ["Race_Group", "CYP2C9", "VKORC1"]
    features = num_features + cat_features
    X = df[features]
    return X, y, num_features, cat_features


def create_preprocessor(num_features, cat_features):
    num_transformer = Pipeline(
        steps=[
            ("imputer", KNNImputer(n_neighbors=5)),
            ("scaler", StandardScaler()),
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
            ("num", num_transformer, num_features),
            ("cat", cat_transformer, cat_features),
        ]
    )


def evaluate_model(model, X_test, y_test):
    predictions = np.maximum(model.predict(X_test), 0)
    mae = mean_absolute_error(y_test, predictions)
    rmse = np.sqrt(mean_squared_error(y_test, predictions))
    r2 = r2_score(y_test, predictions)
    within_20 = float(np.mean(np.abs(predictions - y_test) <= 0.20 * y_test) * 100)
    return {
        "mae": float(mae),
        "rmse": float(rmse),
        "r2": float(r2),
        "within_20_pct": within_20,
    }


def build_pipeline(model, num_features, cat_features):
    return Pipeline(
        steps=[
            ("preprocessor", create_preprocessor(num_features, cat_features)),
            ("regressor", model),
        ]
    )


def format_metrics(metrics):
    return (
        f"R2={metrics['r2']:.4f}, "
        f"RMSE={metrics['rmse']:.2f}, "
        f"MAE={metrics['mae']:.2f}, "
        f"Within20={metrics['within_20_pct']:.2f}%"
    )


def tune_model(study_name, pipeline, objective_builder):
    optuna.logging.set_verbosity(optuna.logging.WARNING)
    study = optuna.create_study(
        study_name=study_name,
        direction="minimize",
        sampler=optuna.samplers.TPESampler(seed=RANDOM_STATE),
    )
    study.optimize(objective_builder(study_name, pipeline), n_trials=N_TRIALS, show_progress_bar=False)
    return study


def make_xgb_objective(X_train, y_train):
    cv = KFold(n_splits=CV_SPLITS, shuffle=True, random_state=RANDOM_STATE)

    def objective(_, base_pipeline):
        def run(trial):
            tuned_pipeline = clone(base_pipeline)
            tuned_pipeline.set_params(
                regressor__n_estimators=trial.suggest_int("n_estimators", 100, 500),
                regressor__learning_rate=trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
                regressor__max_depth=trial.suggest_int("max_depth", 3, 8),
                regressor__min_child_weight=trial.suggest_int("min_child_weight", 1, 10),
                regressor__subsample=trial.suggest_float("subsample", 0.6, 1.0),
                regressor__colsample_bytree=trial.suggest_float("colsample_bytree", 0.6, 1.0),
                regressor__gamma=trial.suggest_float("gamma", 1e-8, 2.0, log=True),
                regressor__reg_alpha=trial.suggest_float("reg_alpha", 1e-8, 1.0, log=True),
                regressor__reg_lambda=trial.suggest_float("reg_lambda", 1e-3, 10.0, log=True),
            )
            scores = cross_val_score(
                tuned_pipeline,
                X_train,
                y_train,
                cv=cv,
                scoring="neg_root_mean_squared_error",
                n_jobs=1,
            )
            return -float(np.mean(scores))

        return run

    return objective


def make_lgbm_objective(X_train, y_train):
    cv = KFold(n_splits=CV_SPLITS, shuffle=True, random_state=RANDOM_STATE)

    def objective(_, base_pipeline):
        def run(trial):
            tuned_pipeline = clone(base_pipeline)
            tuned_pipeline.set_params(
                regressor__n_estimators=trial.suggest_int("n_estimators", 100, 500),
                regressor__learning_rate=trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
                regressor__num_leaves=trial.suggest_int("num_leaves", 15, 127),
                regressor__max_depth=trial.suggest_int("max_depth", 3, 10),
                regressor__min_child_samples=trial.suggest_int("min_child_samples", 5, 40),
                regressor__subsample=trial.suggest_float("subsample", 0.6, 1.0),
                regressor__colsample_bytree=trial.suggest_float("colsample_bytree", 0.6, 1.0),
                regressor__reg_alpha=trial.suggest_float("reg_alpha", 1e-8, 1.0, log=True),
                regressor__reg_lambda=trial.suggest_float("reg_lambda", 1e-3, 10.0, log=True),
            )
            scores = cross_val_score(
                tuned_pipeline,
                X_train,
                y_train,
                cv=cv,
                scoring="neg_root_mean_squared_error",
                n_jobs=1,
            )
            return -float(np.mean(scores))

        return run

    return objective


def write_markdown_report(results):
    ridge = results["baseline_ridge"]
    xgb_default = results["default_xgb"]
    xgb_tuned = results["tuned_xgb"]
    lgbm_default = results["default_lgbm"]
    lgbm_tuned = results["tuned_lgbm"]
    winner = results["winner"]

    lines = [
        "# Optuna Hyperparameter Tuning Report",
        "",
        "## Overview",
        "This report compares the tree-based warfarin dose models before and after switching to Optuna-based hyperparameter optimization. All metrics below were computed on the same held-out 20% test split using the IWPC dataset.",
        "",
        "## Experimental Setup",
        f"- Dataset: `{DATA_PATH.name}`",
        f"- Test split: {int(TEST_SIZE * 100)}% with `random_state={RANDOM_STATE}`",
        f"- Cross-validation during tuning: {CV_SPLITS}-fold KFold with shuffling",
        f"- Optimization engine: Optuna TPE sampler, {N_TRIALS} trials per model",
        "- Optimization target: cross-validated RMSE",
        "- Common preprocessing: KNN imputation + scaling for numeric fields, constant imputation + one-hot encoding for categorical/genetic fields",
        "",
        "## Before vs After",
        "",
        "| Model | Stage | R2 | RMSE | MAE | Within 20% |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
        f"| Ridge pharmacogenetic baseline | Existing baseline | {ridge['metrics']['r2']:.4f} | {ridge['metrics']['rmse']:.2f} | {ridge['metrics']['mae']:.2f} | {ridge['metrics']['within_20_pct']:.2f}% |",
        f"| XGBoost | Default parameters | {xgb_default['metrics']['r2']:.4f} | {xgb_default['metrics']['rmse']:.2f} | {xgb_default['metrics']['mae']:.2f} | {xgb_default['metrics']['within_20_pct']:.2f}% |",
        f"| XGBoost | Optuna tuned | {xgb_tuned['metrics']['r2']:.4f} | {xgb_tuned['metrics']['rmse']:.2f} | {xgb_tuned['metrics']['mae']:.2f} | {xgb_tuned['metrics']['within_20_pct']:.2f}% |",
        f"| LightGBM | Default parameters | {lgbm_default['metrics']['r2']:.4f} | {lgbm_default['metrics']['rmse']:.2f} | {lgbm_default['metrics']['mae']:.2f} | {lgbm_default['metrics']['within_20_pct']:.2f}% |",
        f"| LightGBM | Optuna tuned | {lgbm_tuned['metrics']['r2']:.4f} | {lgbm_tuned['metrics']['rmse']:.2f} | {lgbm_tuned['metrics']['mae']:.2f} | {lgbm_tuned['metrics']['within_20_pct']:.2f}% |",
        "",
        "## Improvement Summary",
        f"- XGBoost improvement: Delta R2 = {xgb_tuned['metrics']['r2'] - xgb_default['metrics']['r2']:+.4f}, Delta RMSE = {xgb_tuned['metrics']['rmse'] - xgb_default['metrics']['rmse']:+.2f}, Delta MAE = {xgb_tuned['metrics']['mae'] - xgb_default['metrics']['mae']:+.2f}, Delta Within 20% = {xgb_tuned['metrics']['within_20_pct'] - xgb_default['metrics']['within_20_pct']:+.2f} points",
        f"- LightGBM improvement: Delta R2 = {lgbm_tuned['metrics']['r2'] - lgbm_default['metrics']['r2']:+.4f}, Delta RMSE = {lgbm_tuned['metrics']['rmse'] - lgbm_default['metrics']['rmse']:+.2f}, Delta MAE = {lgbm_tuned['metrics']['mae'] - lgbm_default['metrics']['mae']:+.2f}, Delta Within 20% = {lgbm_tuned['metrics']['within_20_pct'] - lgbm_default['metrics']['within_20_pct']:+.2f} points",
        f"- Best overall model on the held-out test set: **{winner['name']}** with {format_metrics(winner['metrics'])}",
        "",
        "## Best Optuna Parameters",
        "",
        "### XGBoost",
        "```json",
        json.dumps(xgb_tuned["best_params"], indent=2, sort_keys=True),
        "```",
        "",
        "### LightGBM",
        "```json",
        json.dumps(lgbm_tuned["best_params"], indent=2, sort_keys=True),
        "```",
        "",
        "## Interpretation",
        "- Optuna replaced the earlier random search with sequential model-based optimization, which searches promising regions of the hyperparameter space more efficiently.",
        "- The tuning objective focused on cross-validated RMSE instead of a single validation draw, which reduces the chance of selecting a brittle parameter set.",
        "- The final winner should still be interpreted in the context of clinical safety and model simplicity. If the Ridge baseline remains competitive or better, that is a meaningful result rather than a failure of tuning.",
        "",
        "## Output Artifacts",
        f"- Tuned summary JSON: `{SUMMARY_OUTPUT_PATH.relative_to(BASE_DIR)}`",
        f"- Best persisted model: `{MODEL_OUTPUT_PATH.relative_to(BASE_DIR)}`",
        "",
    ]
    REPORT_OUTPUT_PATH.write_text("\n".join(lines))


def main():
    X, y, num_features, cat_features = load_dataset()

    print("2. Splitting data...")
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=TEST_SIZE,
        random_state=RANDOM_STATE,
    )

    ridge_pipeline = build_pipeline(
        Ridge(alpha=1.0),
        num_features,
        cat_features,
    )
    xgb_default_pipeline = build_pipeline(
        XGBRegressor(
            n_estimators=100,
            learning_rate=0.05,
            max_depth=5,
            random_state=RANDOM_STATE,
            objective="reg:squarederror",
            n_jobs=1,
        ),
        num_features,
        cat_features,
    )
    lgbm_default_pipeline = build_pipeline(
        LGBMRegressor(
            n_estimators=100,
            learning_rate=0.05,
            max_depth=5,
            random_state=RANDOM_STATE,
            verbose=-1,
            n_jobs=1,
        ),
        num_features,
        cat_features,
    )

    print("3. Evaluating before-tuning baselines...")
    ridge_pipeline.fit(X_train, y_train)
    xgb_default_pipeline.fit(X_train, y_train)
    lgbm_default_pipeline.fit(X_train, y_train)

    ridge_metrics = evaluate_model(ridge_pipeline, X_test, y_test)
    xgb_default_metrics = evaluate_model(xgb_default_pipeline, X_test, y_test)
    lgbm_default_metrics = evaluate_model(lgbm_default_pipeline, X_test, y_test)

    print(f"   Ridge baseline: {format_metrics(ridge_metrics)}")
    print(f"   XGBoost default: {format_metrics(xgb_default_metrics)}")
    print(f"   LightGBM default: {format_metrics(lgbm_default_metrics)}")

    print("4. Tuning XGBoost with Optuna...")
    xgb_study = tune_model(
        "warfarin_xgboost_optuna",
        xgb_default_pipeline,
        make_xgb_objective(X_train, y_train),
    )

    tuned_xgb_pipeline = clone(xgb_default_pipeline)
    tuned_xgb_pipeline.set_params(**{f"regressor__{k}": v for k, v in xgb_study.best_params.items()})
    tuned_xgb_pipeline.fit(X_train, y_train)
    tuned_xgb_metrics = evaluate_model(tuned_xgb_pipeline, X_test, y_test)
    print(f"   Tuned XGBoost: {format_metrics(tuned_xgb_metrics)}")

    print("5. Tuning LightGBM with Optuna...")
    lgbm_study = tune_model(
        "warfarin_lightgbm_optuna",
        lgbm_default_pipeline,
        make_lgbm_objective(X_train, y_train),
    )

    tuned_lgbm_pipeline = clone(lgbm_default_pipeline)
    tuned_lgbm_pipeline.set_params(**{f"regressor__{k}": v for k, v in lgbm_study.best_params.items()})
    tuned_lgbm_pipeline.fit(X_train, y_train)
    tuned_lgbm_metrics = evaluate_model(tuned_lgbm_pipeline, X_test, y_test)
    print(f"   Tuned LightGBM: {format_metrics(tuned_lgbm_metrics)}")

    candidates = [
        {"name": "Ridge pharmacogenetic baseline", "model": ridge_pipeline, "metrics": ridge_metrics},
        {"name": "Optuna-tuned XGBoost", "model": tuned_xgb_pipeline, "metrics": tuned_xgb_metrics},
        {"name": "Optuna-tuned LightGBM", "model": tuned_lgbm_pipeline, "metrics": tuned_lgbm_metrics},
    ]
    winner = max(candidates, key=lambda item: item["metrics"]["r2"])

    MODEL_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(winner["model"], MODEL_OUTPUT_PATH)

    results = {
        "dataset": DATA_PATH.name,
        "split": {"test_size": TEST_SIZE, "random_state": RANDOM_STATE},
        "optuna": {"trials_per_model": N_TRIALS, "cv_splits": CV_SPLITS},
        "baseline_ridge": {"metrics": ridge_metrics},
        "default_xgb": {"metrics": xgb_default_metrics},
        "tuned_xgb": {
            "metrics": tuned_xgb_metrics,
            "best_params": xgb_study.best_params,
            "best_cv_rmse": float(xgb_study.best_value),
        },
        "default_lgbm": {"metrics": lgbm_default_metrics},
        "tuned_lgbm": {
            "metrics": tuned_lgbm_metrics,
            "best_params": lgbm_study.best_params,
            "best_cv_rmse": float(lgbm_study.best_value),
        },
        "winner": {"name": winner["name"], "metrics": winner["metrics"]},
    }

    SUMMARY_OUTPUT_PATH.write_text(json.dumps(results, indent=2, sort_keys=True))
    write_markdown_report(results)

    print("6. Final selection...")
    print(f"   Winner: {winner['name']} with {format_metrics(winner['metrics'])}")
    print(f"   Saved model to {MODEL_OUTPUT_PATH}")
    print(f"   Wrote summary to {SUMMARY_OUTPUT_PATH}")
    print(f"   Wrote report to {REPORT_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
