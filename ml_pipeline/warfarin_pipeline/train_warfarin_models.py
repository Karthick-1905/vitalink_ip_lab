import pandas as pd
import numpy as np
import os
import json
import matplotlib.pyplot as plt
import shap
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.ensemble import RandomForestRegressor
from sklearn.neural_network import MLPRegressor
from xgboost import XGBRegressor
from lightgbm import LGBMRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import warnings

warnings.filterwarnings('ignore')

file_path = os.getenv("WARFARIN_TRAIN_DATA", './warfarin_pipeline/data/iwpc_warfarin.xls')

def load_dataframe(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in ['.xls', '.xlsx']:
        try:
            return pd.read_excel(path, sheet_name='Subject Data')
        except Exception:
            return pd.read_excel(path)
    if ext == '.csv':
        return pd.read_csv(path)
    raise ValueError(f"Unsupported file extension: {ext}")

df = load_dataframe(file_path)

# Feature Engineering
def map_age(age_str):
    if pd.isna(age_str):
        return np.nan
    age_str = str(age_str).strip()
    mapping = {
        "10 - 19": 1.5, "20 - 29": 2.5, "30 - 39": 3.5,
        "40 - 49": 4.5, "50 - 59": 5.5, "60 - 69": 6.5,
        "70 - 79": 7.5, "80 - 89": 8.5, "90+": 9.5
    }
    if age_str in mapping:
        return mapping[age_str]
    try:
        return float(age_str)
    except Exception:
        return np.nan

print("2. Preprocessing Data...")

is_iwpc_schema = 'Therapeutic Dose of Warfarin' in df.columns

if 'Therapeutic Dose of Warfarin' in df.columns:
    # IWPC schema
    df = df.dropna(subset=['Therapeutic Dose of Warfarin'])
    y = pd.to_numeric(df['Therapeutic Dose of Warfarin'], errors='coerce')

    race_col = 'Race (Reported)' if 'Race (Reported)' in df.columns else ('Race' if 'Race' in df.columns else None)
    if race_col is None:
        raise ValueError("Could not find race column. Expected 'Race (Reported)' or 'Race'.")

    df['Age_Num'] = df['Age'].apply(map_age)

    def map_race(race):
        if pd.isna(race):
            return 'Unknown'
        race = str(race)
        if 'White' in race:
            return 'White'
        if 'Black' in race or 'African' in race:
            return 'Black'
        if 'Asian' in race:
            return 'Asian'
        return 'Other'

    df['Race_Group'] = df[race_col].apply(map_race)

    amiodarone_col = 'Amiodarone (Cordarone)' if 'Amiodarone (Cordarone)' in df.columns else ('Amiodarone' if 'Amiodarone' in df.columns else None)
    if amiodarone_col is None:
        df['Amiodarone'] = 0.0
    else:
        df['Amiodarone'] = pd.to_numeric(df[amiodarone_col], errors='coerce').fillna(0.0)

    enzyme_cols = ['Carbamazepine (Tegretol)', 'Phenytoin (Dilantin)', 'Rifampin or Rifampicin']
    existing_enzyme_cols = [col for col in enzyme_cols if col in df.columns]
    if existing_enzyme_cols:
        for col in existing_enzyme_cols:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0.0)
        df['Enzyme_Inducer'] = df[existing_enzyme_cols].max(axis=1)
    else:
        df['Enzyme_Inducer'] = 0.0

    df['CYP2C9'] = df['Cyp2C9 genotypes'].fillna('Unknown')
    common_cyp = ['*1/*1', '*1/*2', '*1/*3', '*2/*2', '*2/*3', '*3/*3']
    df['CYP2C9'] = df['CYP2C9'].apply(lambda x: x if x in common_cyp else 'Other/Unknown')

    df['VKORC1'] = df['VKORC1 -1639 consensus'].fillna('Unknown')

    num_features = ['Age_Num', 'Height (cm)', 'Weight (kg)', 'Amiodarone', 'Enzyme_Inducer']
    cat_features_clinical = ['Race_Group']
    cat_features_genetic = ['CYP2C9', 'VKORC1']

    clinical_cols = ['Age_Num', 'Height (cm)', 'Weight (kg)', 'Amiodarone', 'Enzyme_Inducer', 'Race_Group']
    genetic_cols = ['CYP2C9', 'VKORC1']
    features = clinical_cols + genetic_cols
    X = df[features]

elif 'WarfarinDose' in df.columns:
    # Synthetic schema
    df = df.dropna(subset=['WarfarinDose'])
    y = pd.to_numeric(df['WarfarinDose'], errors='coerce')

    for col in ['Age', 'Height', 'Weight', 'Target_INR', 'Renal_Function']:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    for col in ['Gender', 'Amiodarone', 'Aspirin', 'Smoker', 'CYP2C9', 'VKORC1', 'CYP4F2']:
        if col not in df.columns:
            df[col] = 'Unknown'
        df[col] = df[col].astype(str).fillna('Unknown')

    num_features = ['Age', 'Height', 'Weight', 'Target_INR', 'Renal_Function']
    cat_features_clinical = ['Gender', 'Amiodarone', 'Aspirin', 'Smoker']
    cat_features_genetic = ['CYP2C9', 'VKORC1', 'CYP4F2']
    features = num_features + cat_features_clinical + cat_features_genetic
    X = df[features]

else:
    raise ValueError(
        "Unsupported dataset schema. Expected either IWPC columns with 'Therapeutic Dose of Warfarin' "
        "or synthetic columns with 'WarfarinDose'."
    )

# Train-Test Split
print("3. Splitting Data...")
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
y_test_true_dose = y_test

# Pipelines
num_transformer = Pipeline(steps=[
    ('imputer', KNNImputer(n_neighbors=5)),
    ('scaler', StandardScaler())
])

cat_transformer = Pipeline(steps=[
    ('imputer', SimpleImputer(strategy='constant', fill_value='Unknown')),
    ('onehot', OneHotEncoder(handle_unknown='ignore', sparse_output=False))
])

preprocessor_clinical = ColumnTransformer(
    transformers=[
        ('num', num_transformer, num_features),
        ('cat', cat_transformer, cat_features_clinical)
    ])

preprocessor_pgx = ColumnTransformer(
    transformers=[
        ('num', num_transformer, num_features),
        ('cat', cat_transformer, cat_features_clinical + cat_features_genetic)
    ])

models = {
    "1. Clinical Baseline (Linear)": Pipeline(steps=[('preprocessor', preprocessor_clinical), ('regressor', LinearRegression())]),
    "2. Pharmacogenetic Baseline (Ridge)": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', Ridge(alpha=1.0))]),
    "3. Random Forest": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', RandomForestRegressor(n_estimators=100, random_state=42, max_depth=10))]),
    "4. XGBoost": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', XGBRegressor(n_estimators=100, learning_rate=0.05, max_depth=5, random_state=42))]),
    "5. LightGBM": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', LGBMRegressor(n_estimators=100, learning_rate=0.05, max_depth=5, random_state=42, verbose=-1))]),
    "6. Neural Network (MLP)": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', MLPRegressor(hidden_layer_sizes=(64, 32), activation='relu', max_iter=500, random_state=42))])
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
        'rmse': float(rmse),
        'r2': float(r2),
        'within_20_pct': float(within_20),
    }


def print_metrics(name, metrics):
    print(f"\n{name}")
    print("--------------------------------------------------")
    print(f"MAE: {metrics['mae']:.2f} mg/week")
    print(f"RMSE: {metrics['rmse']:.2f} mg/week")
    print(f"R2 Score: {metrics['r2']:.3f}")
    print(f"Patients within 20% of actual dose: {metrics['within_20_pct']:.2f}%")


def iwpc_clinical_predict(features_frame):
    """Compute the IWPC clinical algorithm prediction in mg/week.

    Formula (sqrt-dose scale):
    sqrt(weekly_dose) = 4.0376
        - 0.2546 * age_decades
        + 0.0118 * height_cm
        + 0.0134 * weight_kg
        - 0.6752 * asian
        + 0.4060 * black
        + 1.2799 * enzyme_inducer
        - 0.5695 * amiodarone
    """
    race = features_frame['Race_Group'].astype(str)
    asian = (race == 'Asian').astype(float)
    black = (race == 'Black').astype(float)

    age_decades = pd.to_numeric(features_frame['Age_Num'], errors='coerce').fillna(0.0)
    height_cm = pd.to_numeric(features_frame['Height (cm)'], errors='coerce').fillna(0.0)
    weight_kg = pd.to_numeric(features_frame['Weight (kg)'], errors='coerce').fillna(0.0)
    amiodarone = pd.to_numeric(features_frame['Amiodarone'], errors='coerce').fillna(0.0)
    enzyme_inducer = pd.to_numeric(features_frame['Enzyme_Inducer'], errors='coerce').fillna(0.0)

    sqrt_dose = (
        4.0376
        - (0.2546 * age_decades)
        + (0.0118 * height_cm)
        + (0.0134 * weight_kg)
        - (0.6752 * asian)
        + (0.4060 * black)
        + (1.2799 * enzyme_inducer)
        - (0.5695 * amiodarone)
    )
    return np.square(np.maximum(sqrt_dose, 0.0))


def generate_shap_reports(model_name, model, X_test_frame, output_dir="output"):
    """Generate SHAP explainability artifacts for the selected best model."""
    os.makedirs(output_dir, exist_ok=True)

    model_preprocessor = model.named_steps['preprocessor']
    model_regressor = model.named_steps['regressor']

    X_processed = model_preprocessor.transform(X_test_frame)
    feature_names = model_preprocessor.get_feature_names_out()
    X_processed_df = pd.DataFrame(X_processed, columns=feature_names)

    if len(X_processed_df) > 400:
        X_processed_df = X_processed_df.sample(n=400, random_state=42)

    is_tree = isinstance(model_regressor, (RandomForestRegressor, XGBRegressor, LGBMRegressor))
    explainer = shap.TreeExplainer(model_regressor) if is_tree else shap.Explainer(model_regressor, X_processed_df)
    shap_values = explainer(X_processed_df)

    abs_mean = np.abs(shap_values.values).mean(axis=0)
    shap_importance = pd.DataFrame({
        'feature': feature_names,
        'mean_abs_shap': abs_mean,
    }).sort_values('mean_abs_shap', ascending=False)
    shap_importance.to_csv(os.path.join(output_dir, 'shap_top_features.csv'), index=False)

    plt.figure(figsize=(11, 7))
    shap.plots.bar(shap_values, max_display=15, show=False)
    plt.title(f"SHAP Global Importance - {model_name}")
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'shap_summary_bar.png'), dpi=300, bbox_inches='tight')
    plt.close()

    plt.figure(figsize=(11, 7))
    shap.summary_plot(shap_values.values, X_processed_df, feature_names=feature_names, max_display=15, show=False)
    plt.title(f"SHAP Summary - {model_name}")
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'shap_summary_beeswarm.png'), dpi=300, bbox_inches='tight')
    plt.close()

    print("\nSaved SHAP reports:")
    print("- warfarin_pipeline/output/shap_summary_bar.png")
    print("- warfarin_pipeline/output/shap_summary_beeswarm.png")
    print("- warfarin_pipeline/output/shap_top_features.csv")


def evaluate_model(name, model, X_tr, y_tr, X_te, y_te_true):
    model.fit(X_tr, y_tr)
    y_pred_dose = np.maximum(model.predict(X_te), 0)

    metrics = calculate_metrics(y_te_true, y_pred_dose)
    print_metrics(name, metrics)
    return model, metrics

print("\n4. Training and Evaluating Models...")
trained_models = {}
model_results = {}
for name, pipeline in models.items():
    trained_model, metrics = evaluate_model(name, pipeline, X_train, y_train, X_test, y_test_true_dose)
    trained_models[name] = trained_model
    model_results[name] = metrics

if is_iwpc_schema:
    iwpc_preds = iwpc_clinical_predict(X_test)
    iwpc_metrics = calculate_metrics(y_test_true_dose, iwpc_preds)
    model_results["0. IWPC Clinical Calculator"] = iwpc_metrics
    print_metrics("0. IWPC Clinical Calculator", iwpc_metrics)

leaderboard = (
    pd.DataFrame(model_results)
    .T
    .reset_index()
    .rename(columns={'index': 'model'})
    .sort_values(by='rmse', ascending=True)
)

os.makedirs("warfarin_pipeline/output", exist_ok=True)
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
print("\nModel leaderboard (best RMSE first):")
print(leaderboard[['model', 'mae', 'rmse', 'r2', 'within_20_pct']].to_string(index=False))
print("\nSaved comparison reports:")
print("- warfarin_pipeline/output/model_comparison_report.csv")
print("- warfarin_pipeline/output/model_comparison_report.json")

import joblib
best_trained_model_row = leaderboard[leaderboard['model'].isin(trained_models.keys())].iloc[0]
best_model_name = best_trained_model_row['model']
best_model = trained_models[best_model_name]
os.makedirs("warfarin_pipeline/models", exist_ok=True)
joblib.dump(best_model, './warfarin_pipeline/models/best_warfarin_model.joblib')
print(f"\nSaved the best trained model ({best_model_name}) to ./warfarin_pipeline/models/best_warfarin_model.joblib")

generate_shap_reports(best_model_name, best_model, X_test, output_dir="warfarin_pipeline/output")
