import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split, RandomizedSearchCV
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from xgboost import XGBRegressor
from lightgbm import LGBMRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import warnings

warnings.filterwarnings('ignore')

print("1. Loading and Preprocessing Data...")
file_path = './ml_pipeline/data/iwpc_warfarin.xls'
df = pd.read_excel(file_path, sheet_name='Subject Data')
df = df.dropna(subset=['Therapeutic Dose of Warfarin'])

y = np.sqrt(df['Therapeutic Dose of Warfarin'])

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

def map_race(race):
    if pd.isna(race): return 'Unknown'
    race = str(race)
    if 'White' in race: return 'White'
    if 'Black' in race or 'African' in race: return 'Black'
    if 'Asian' in race: return 'Asian'
    return 'Other'

df['Race_Group'] = df['Race (Reported)'].apply(map_race)
df['Amiodarone'] = df['Amiodarone (Cordarone)'].fillna(0.0)

enzyme_cols = ['Carbamazepine (Tegretol)', 'Phenytoin (Dilantin)', 'Rifampin or Rifampicin']
for col in enzyme_cols:
    df[col] = df[col].fillna(0.0)
df['Enzyme_Inducer'] = df[enzyme_cols].max(axis=1)

df['CYP2C9'] = df['Cyp2C9 genotypes'].fillna('Unknown')
common_cyp = ['*1/*1', '*1/*2', '*1/*3', '*2/*2', '*2/*3', '*3/*3']
df['CYP2C9'] = df['CYP2C9'].apply(lambda x: x if x in common_cyp else 'Other/Unknown')
df['VKORC1'] = df['VKORC1 -1639 consensus'].fillna('Unknown')

features = ['Age_Num', 'Height (cm)', 'Weight (kg)', 'Amiodarone', 'Enzyme_Inducer', 'Race_Group', 'CYP2C9', 'VKORC1']
X = df[features]

print("2. Splitting Data...")
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
y_test_true_dose = np.square(y_test)

# Pipelines
num_features = ['Age_Num', 'Height (cm)', 'Weight (kg)', 'Amiodarone', 'Enzyme_Inducer']
cat_features = ['Race_Group', 'CYP2C9', 'VKORC1']

num_transformer = Pipeline(steps=[
    ('imputer', KNNImputer(n_neighbors=5)),
    ('scaler', StandardScaler())
])

cat_transformer = Pipeline(steps=[
    ('imputer', SimpleImputer(strategy='constant', fill_value='Unknown')),
    ('onehot', OneHotEncoder(handle_unknown='ignore', sparse_output=False))
])

preprocessor = ColumnTransformer(
    transformers=[
        ('num', num_transformer, num_features),
        ('cat', cat_transformer, cat_features)
    ])

xgb_pipeline = Pipeline(steps=[('preprocessor', preprocessor), ('regressor', XGBRegressor(random_state=42))])
lgbm_pipeline = Pipeline(steps=[('preprocessor', preprocessor), ('regressor', LGBMRegressor(random_state=42, verbose=-1))])

# Hyperparameter Grids
xgb_param_grid = {
    'regressor__n_estimators': [50, 100, 200, 300],
    'regressor__learning_rate': [0.01, 0.05, 0.1, 0.2],
    'regressor__max_depth': [3, 4, 5, 7],
    'regressor__subsample': [0.7, 0.8, 0.9, 1.0],
    'regressor__colsample_bytree': [0.7, 0.8, 0.9, 1.0]
}

lgbm_param_grid = {
    'regressor__n_estimators': [50, 100, 200, 300],
    'regressor__learning_rate': [0.01, 0.05, 0.1, 0.2],
    'regressor__num_leaves': [15, 31, 63],
    'regressor__max_depth': [-1, 3, 5, 7],
    'regressor__subsample': [0.7, 0.8, 0.9, 1.0]
}

def evaluate_model(name, model, X_te, y_te_true):
    y_pred_sqrt = model.predict(X_te)
    y_pred_dose = np.square(np.maximum(y_pred_sqrt, 0))
    mae = mean_absolute_error(y_te_true, y_pred_dose)
    rmse = np.sqrt(mean_squared_error(y_te_true, y_pred_dose))
    r2 = r2_score(y_te_true, y_pred_dose)
    within_20 = np.sum(np.abs(y_pred_dose - y_te_true) <= 0.20 * y_te_true) / len(y_te_true) * 100
    
    print(f"\n{name} - Test Results")
    print(f"--------------------------------------------------")
    print(f"MAE: {mae:.2f} mg/week")
    print(f"RMSE: {rmse:.2f} mg/week")
    print(f"R2 Score: {r2:.3f}")
    print(f"Patients within 20% of actual dose: {within_20:.2f}%")
    return r2

print("\n3. Tuning XGBoost...")
xgb_search = RandomizedSearchCV(xgb_pipeline, param_distributions=xgb_param_grid, n_iter=10, cv=3, scoring='neg_mean_squared_error', n_jobs=1, random_state=42)
xgb_search.fit(X_train, y_train)
print(f"Best XGBoost Params: {xgb_search.best_params_}")
xgb_r2 = evaluate_model("Tuned XGBoost", xgb_search.best_estimator_, X_test, y_test_true_dose)

print("\n4. Tuning LightGBM...")
lgbm_search = RandomizedSearchCV(lgbm_pipeline, param_distributions=lgbm_param_grid, n_iter=10, cv=3, scoring='neg_mean_squared_error', n_jobs=1, random_state=42)
lgbm_search.fit(X_train, y_train)
print(f"Best LightGBM Params: {lgbm_search.best_params_}")
lgbm_r2 = evaluate_model("Tuned LightGBM", lgbm_search.best_estimator_, X_test, y_test_true_dose)

# Load existing ridge model to compare
print("\n5. Comparing with Baseline (Ridge)...")
try:
    ridge_model = joblib.load('./ml_pipeline/models/best_warfarin_model.joblib')
    ridge_r2 = evaluate_model("Baseline (Ridge)", ridge_model, X_test, y_test_true_dose)
except Exception as e:
    print("Could not load Ridge model.")
    ridge_r2 = 0

# Determine the overall best
best_r2 = max(xgb_r2, lgbm_r2, ridge_r2)
if best_r2 == xgb_r2:
    print("\n[RESULT] Tuned XGBoost is the new best model!")
    joblib.dump(xgb_search.best_estimator_, './ml_pipeline/models/best_warfarin_model.joblib')
elif best_r2 == lgbm_r2:
    print("\n[RESULT] Tuned LightGBM is the new best model!")
    joblib.dump(lgbm_search.best_estimator_, './ml_pipeline/models/best_warfarin_model.joblib')
else:
    print("\n[RESULT] Baseline (Ridge) remains the best model!")

print("\nFinished Tuning!")
