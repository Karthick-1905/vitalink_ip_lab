import pandas as pd
import numpy as np
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

print("1. Loading Data...")
file_path = './ml_pipeline/data/iwpc_warfarin.xls'
df = pd.read_excel(file_path, sheet_name='Subject Data')

# 2. Filtering target
print("2. Preprocessing Data...")
df = df.dropna(subset=['Therapeutic Dose of Warfarin'])

# Target Variable (Square root transformation)
y = np.sqrt(df['Therapeutic Dose of Warfarin'])

# Feature Engineering
def map_age(age_str):
    if pd.isna(age_str): return np.nan
    age_str = str(age_str).strip()
    mapping = {
        "10 - 19": 1.5, "20 - 29": 2.5, "30 - 39": 3.5, 
        "40 - 49": 4.5, "50 - 59": 5.5, "60 - 69": 6.5, 
        "70 - 79": 7.5, "80 - 89": 8.5, "90+": 9.5
    }
    return mapping.get(age_str, np.nan)

df['Age_Num'] = df['Age'].apply(map_age)

# Race Consolidation
def map_race(race):
    if pd.isna(race): return 'Unknown'
    race = str(race)
    if 'White' in race: return 'White'
    if 'Black' in race or 'African' in race: return 'Black'
    if 'Asian' in race: return 'Asian'
    return 'Other'

df['Race_Group'] = df['Race (Reported)'].apply(map_race)

# Medications and Clinical
df['Amiodarone'] = df['Amiodarone (Cordarone)'].fillna(0.0)

# Enzyme Inducer
enzyme_cols = ['Carbamazepine (Tegretol)', 'Phenytoin (Dilantin)', 'Rifampin or Rifampicin']
for col in enzyme_cols:
    df[col] = df[col].fillna(0.0)
df['Enzyme_Inducer'] = df[enzyme_cols].max(axis=1)

# Genetics
df['CYP2C9'] = df['Cyp2C9 genotypes'].fillna('Unknown')
# Consolidate rare CYP2C9 variants
common_cyp = ['*1/*1', '*1/*2', '*1/*3', '*2/*2', '*2/*3', '*3/*3']
df['CYP2C9'] = df['CYP2C9'].apply(lambda x: x if x in common_cyp else 'Other/Unknown')

df['VKORC1'] = df['VKORC1 -1639 consensus'].fillna('Unknown')

# Subset columns for modeling
clinical_cols = ['Age_Num', 'Height (cm)', 'Weight (kg)', 'Amiodarone', 'Enzyme_Inducer', 'Race_Group']
genetic_cols = ['CYP2C9', 'VKORC1']
features = clinical_cols + genetic_cols

X = df[features]

# Train-Test Split
print("3. Splitting Data...")
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Save original dose for evaluation (we will square the predictions)
y_test_true_dose = np.square(y_test)

# Pipelines
# 1. Clinical Imputers
num_features = ['Age_Num', 'Height (cm)', 'Weight (kg)', 'Amiodarone', 'Enzyme_Inducer']
cat_features_clinical = ['Race_Group']
cat_features_genetic = ['CYP2C9', 'VKORC1']

num_transformer = Pipeline(steps=[
    ('imputer', KNNImputer(n_neighbors=5)),
    ('scaler', StandardScaler())
])

cat_transformer = Pipeline(steps=[
    ('imputer', SimpleImputer(strategy='constant', fill_value='Unknown')),
    ('onehot', OneHotEncoder(handle_unknown='ignore', sparse_output=False))
])

# Clinical Preprocessor (No Genetics)
preprocessor_clinical = ColumnTransformer(
    transformers=[
        ('num', num_transformer, num_features),
        ('cat', cat_transformer, cat_features_clinical)
    ])

# Pharmacogenetic Preprocessor (Includes Genetics)
preprocessor_pgx = ColumnTransformer(
    transformers=[
        ('num', num_transformer, num_features),
        ('cat', cat_transformer, cat_features_clinical + cat_features_genetic)
    ])

# Define Models
models = {
    "1. Clinical Baseline (Linear)": Pipeline(steps=[('preprocessor', preprocessor_clinical), ('regressor', LinearRegression())]),
    "2. Pharmacogenetic Baseline (Ridge)": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', Ridge(alpha=1.0))]),
    "3. Random Forest": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', RandomForestRegressor(n_estimators=100, random_state=42, max_depth=10))]),
    "4. XGBoost": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', XGBRegressor(n_estimators=100, learning_rate=0.05, max_depth=5, random_state=42))]),
    "5. LightGBM": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', LGBMRegressor(n_estimators=100, learning_rate=0.05, max_depth=5, random_state=42, verbose=-1))]),
    "6. Neural Network (MLP)": Pipeline(steps=[('preprocessor', preprocessor_pgx), ('regressor', MLPRegressor(hidden_layer_sizes=(64, 32), activation='relu', max_iter=500, random_state=42))])
}

# Training and Evaluation Function
def evaluate_model(name, model, X_tr, y_tr, X_te, y_te_true):
    model.fit(X_tr, y_tr)
    # Predict in square root scale, then square to get mg/week
    y_pred_sqrt = model.predict(X_te)
    y_pred_dose = np.square(np.maximum(y_pred_sqrt, 0)) # Ensure no negative predictions before squaring
    
    mae = mean_absolute_error(y_te_true, y_pred_dose)
    rmse = np.sqrt(mean_squared_error(y_te_true, y_pred_dose))
    r2 = r2_score(y_te_true, y_pred_dose)
    
    # Calculate % of predictions within 20% of actual dose
    within_20 = np.sum(np.abs(y_pred_dose - y_te_true) <= 0.20 * y_te_true) / len(y_te_true) * 100
    
    print(f"\n{name}")
    print(f"--------------------------------------------------")
    print(f"MAE: {mae:.2f} mg/week")
    print(f"RMSE: {rmse:.2f} mg/week")
    print(f"R2 Score: {r2:.3f}")
    print(f"Patients within 20% of actual dose: {within_20:.2f}%")
    return model

print("\n4. Training and Evaluating Models...")
trained_models = {}
for name, pipeline in models.items():
    trained_models[name] = evaluate_model(name, pipeline, X_train, y_train, X_test, y_test_true_dose)

print("\nTraining Complete!")

import joblib
# Save the best performing model (Pharmacogenetic Baseline)
best_model = trained_models["2. Pharmacogenetic Baseline (Ridge)"]
joblib.dump(best_model, './ml_pipeline/models/best_warfarin_model.joblib')
print("\nSaved the best model to ./ml_pipeline/models/best_warfarin_model.joblib")
