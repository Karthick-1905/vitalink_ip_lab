import os
import pandas as pd
import numpy as np
import xgboost as xgb
import joblib
import optuna
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer, KNNImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.metrics import r2_score, mean_squared_error, mean_absolute_error
from sklearn.base import clone
import warnings

warnings.filterwarnings('ignore')


def load_dataframe(path):
    """Load data from CSV, XLS, or XLSX files."""
    ext = os.path.splitext(path)[1].lower()
    if ext in ['.xls', '.xlsx']:
        try:
            return pd.read_excel(path, sheet_name='Subject Data')
        except Exception:
            return pd.read_excel(path)
    if ext == '.csv':
        return pd.read_csv(path)
    raise ValueError(f"Unsupported file extension: {ext}")

def map_age(age_str):
    """Convert age bands to numeric values (midpoint)."""
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

def map_race(race):
    """Normalize race values to standard categories."""
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

def create_preprocessor(num_features, cat_features):
    """Create a ColumnTransformer for preprocessing."""
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
    
    return preprocessor

def get_feature_names_from_preprocessor(preprocessor, num_features, cat_features):
    """Extract feature names from the fitted preprocessor."""
    feature_names = []
    
    # Numeric features keep their names
    feature_names.extend(num_features)
    
    # Get categorical feature names from OneHotEncoder
    try:
        cat_transformer = preprocessor.named_transformers_['cat']
        onehot = cat_transformer.named_steps['onehot']
        cat_names = onehot.get_feature_names_out(cat_features)
        feature_names.extend(cat_names)
    except Exception:
        # Fallback if names can't be extracted
        feature_names.extend([f"cat_{i}" for i in range(len(cat_features))])
    
    return feature_names

def preprocess_data(df):
    """
    Preprocess dataframe handling both IWPC and synthetic schemas.
    Returns: X, y, preprocessor, feature_names
    """
    print("2. Preprocessing Data...")
    
    if 'Therapeutic Dose of Warfarin' in df.columns:
        # IWPC schema handling
        df = df.dropna(subset=['Therapeutic Dose of Warfarin'])
        y = df['Therapeutic Dose of Warfarin']
        
        race_col = 'Race (Reported)' if 'Race (Reported)' in df.columns else ('Race' if 'Race' in df.columns else None)
        if race_col is None:
            raise ValueError("Could not find race column. Expected 'Race (Reported)' or 'Race'.")
        
        df['Age_Num'] = df['Age'].apply(map_age)
        
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
        cat_features = ['Race_Group', 'CYP2C9', 'VKORC1']
        features = num_features + cat_features
        X = df[features]
    
    elif 'WarfarinDose' in df.columns:
        # Synthetic schema handling
        df = df.dropna(subset=['WarfarinDose'])
        y = df['WarfarinDose']
        
        for col in ['Age', 'Height', 'Weight', 'Target_INR', 'Renal_Function']:
            df[col] = pd.to_numeric(df[col], errors='coerce')
        
        for col in ['Gender', 'Amiodarone', 'Aspirin', 'Smoker', 'CYP2C9', 'VKORC1', 'CYP4F2']:
            if col not in df.columns:
                df[col] = 'Unknown'
            df[col] = df[col].astype(str).fillna('Unknown')
        
        num_features = ['Age', 'Height', 'Weight', 'Target_INR', 'Renal_Function']
        cat_features = ['Gender', 'Amiodarone', 'Aspirin', 'Smoker', 'CYP2C9', 'VKORC1', 'CYP4F2']
        features = num_features + cat_features
        X = df[features]
    
    else:
        raise ValueError(
            "Unsupported dataset schema. Expected either IWPC columns with 'Therapeutic Dose of Warfarin' "
            "or synthetic columns with 'WarfarinDose'."
        )
    
    preprocessor = create_preprocessor(num_features, cat_features)
    
    return X, y, preprocessor, num_features, cat_features

def train_xgboost_baseline(data_path="warfarin_pipeline/data/warfarin_cohort.csv"):
    df = load_dataframe(data_path)
    print(f"Loaded {len(df)} patients for baseline training.")
    
    X, y, preprocessor, num_features, cat_features = preprocess_data(df)
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=123)

    preprocessor = preprocessor.fit(X_train)
    X_train_processed = preprocessor.transform(X_train)
    X_test_processed = preprocessor.transform(X_test)

    feature_names = get_feature_names_from_preprocessor(preprocessor, num_features, cat_features)
    print(f"Training on {X_train_processed.shape[0]} samples, {X_train_processed.shape[1]} features.")
    
    def objective(trial):
        X_t, X_v, y_t, y_v = train_test_split(X_train, y_train, test_size=0.2, random_state=42)
        fold_preprocessor = clone(preprocessor)
        X_t_processed = fold_preprocessor.fit_transform(X_t)
        X_v_processed = fold_preprocessor.transform(X_v)

        params = {
            'objective': 'reg:squarederror',
            'max_depth': trial.suggest_int('max_depth', 3, 10),
            'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.2, log=True),
            'n_estimators': trial.suggest_int('n_estimators', 50, 400),
            'min_child_weight': trial.suggest_int('min_child_weight', 1, 10),
            'gamma': trial.suggest_float('gamma', 1e-8, 1.0, log=True),
            'subsample': trial.suggest_float('subsample', 0.5, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.5, 1.0),
            'random_state': 123,
            'n_jobs': -1
        }
        
        m = xgb.XGBRegressor(**params)
        m.fit(X_t_processed, y_t, eval_set=[(X_v_processed, y_v)], verbose=False)
        return np.sqrt(mean_squared_error(y_v, m.predict(X_v_processed)))

    print("\n3. Running Optuna hyperparameter tuning (30 trials)...")
    optuna.logging.set_verbosity(optuna.logging.WARNING)
    study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed=123))
    study.optimize(objective, n_trials=30)
    
    best_params = study.best_params
    best_params['objective'] = 'reg:squarederror'
    best_params['random_state'] = 123
    best_params['n_jobs'] = -1
    
    print("\n✓ Found best hyperparameters!")
    for k, v in best_params.items():
        if k not in ['objective', 'random_state', 'n_jobs']:
            print(f"  {k}: {v}")
    
    print("\n4. Training final XGBoost baseline model...")
    model = xgb.XGBRegressor(**best_params)
    
    model.fit(
        X_train_processed, y_train,
        eval_set=[(X_train_processed, y_train), (X_test_processed, y_test)],
        verbose=False
    )
    
    predictions = model.predict(X_test_processed)
    
    r2 = r2_score(y_test, predictions)
    rmse = np.sqrt(mean_squared_error(y_test, predictions))
    mae = mean_absolute_error(y_test, predictions)
    within_20pct = np.mean(np.abs(y_test - predictions) <= 0.2 * y_test) * 100
    
    print("\n" + "="*50)
    print("EVALUATION METRICS (Clinical Baseline)")
    print("="*50)
    print(f"R² Score:              {r2:.4f}")
    print(f"RMSE:                  {rmse:.2f} mg/week")
    print(f"MAE:                   {mae:.2f} mg/week")
    print(f"Patients within 20%:   {within_20pct:.1f}%")
    print("="*50)
    
    os.makedirs("warfarin_pipeline/models", exist_ok=True)
    os.makedirs("warfarin_pipeline/data", exist_ok=True)
    
    model.get_booster().save_model("warfarin_pipeline/models/warfarin_model.json")
    joblib.dump(preprocessor, "warfarin_pipeline/models/preprocessor.joblib")
    
    np.save("warfarin_pipeline/data/y_test_baseline.npy", y_test.values)
    np.save("warfarin_pipeline/data/y_pred_baseline.npy", predictions)
    
    feature_importances = model.feature_importances_
    if len(feature_names) == len(feature_importances):
        importance_df = pd.DataFrame({
            'Feature': feature_names,
            'Gain': feature_importances
        }).sort_values('Gain', ascending=False)
        importance_df.to_csv("warfarin_pipeline/data/feature_importances.csv", index=False)
        print("\nTop 10 Most Important Features:")
        print(importance_df.head(10).to_string(index=False))
    
    print("\n✓ Saved model to: models/warfarin_model.json")
    print("✓ Saved preprocessor to: models/preprocessor.joblib")
    print("✓ Saved predictions to: data/y_test_baseline.npy, data/y_pred_baseline.npy")
    print("✓ Saved feature importances to: data/feature_importances.csv")
    
    return model, r2, rmse, mae, within_20pct

if __name__ == "__main__":
    train_xgboost_baseline()
