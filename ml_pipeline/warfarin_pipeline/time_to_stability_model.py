import os
import numpy as np
import xgboost as xgb
import optuna
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, mean_squared_error, mean_absolute_error
from sklearn.base import clone
from train_baseline import load_dataframe, preprocess_data

def train_time_to_stability(data_path="warfarin_pipeline/data/warfarin_cohort.csv"):
    """Train a model to predict days required to reach stable INR dosing."""
    df = load_dataframe(data_path)
    print("--- Time-to-Stability Prediction Framework ---")
    print("Note: quality depends on validity of the Days_To_Stable target.")

    if "Days_To_Stable" not in df.columns:
        raise ValueError("Missing Days_To_Stable column in training data.")
    
    X, _, preprocessor, _, _ = preprocess_data(df)
    y_time = df['Days_To_Stable']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y_time, test_size=0.2, random_state=42)
    
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
            'random_state': 42,
            'n_jobs': -1
        }
        
        m = xgb.XGBRegressor(**params)
        m.fit(X_t_processed, y_t, eval_set=[(X_v_processed, y_v)], verbose=False)
        return np.sqrt(mean_squared_error(y_v, m.predict(X_v_processed)))

    print("Running Optuna study for max 30 trials on Time-to-Stability...")
    optuna.logging.set_verbosity(optuna.logging.WARNING)
    study = optuna.create_study(direction='minimize', sampler=optuna.samplers.TPESampler(seed=42))
    study.optimize(objective, n_trials=30)
    
    best_params = study.best_params
    best_params['objective'] = 'reg:squarederror'
    best_params['random_state'] = 42
    best_params['n_jobs'] = -1
    
    print("Found best hyperparameters!")
    for k, v in best_params.items():
        if k not in ['objective', 'random_state', 'n_jobs']:
            print(f"  {k}: {v}")
            
    print("\nTraining final XGBoost model with best params...")
    time_model = xgb.XGBRegressor(**best_params)

    X_train_processed = preprocessor.fit_transform(X_train)
    X_test_processed = preprocessor.transform(X_test)
    
    time_model.fit(
        X_train_processed, y_train,
        eval_set=[(X_train_processed, y_train), (X_test_processed, y_test)],
        verbose=False
    )
    
    preds = time_model.predict(X_test_processed)
    
    r2 = r2_score(y_test, preds)
    rmse = np.sqrt(mean_squared_error(y_test, preds))
    mae = mean_absolute_error(y_test, preds)
    
    print("\n--- Model Performance (Dummy Data) ---")
    print(f"R2:\t\t{r2:.4f}")
    print(f"RMSE:\t\t{rmse:.2f} days")
    print(f"MAE:\t\t{mae:.2f} days")
    
    within_7days = np.mean(np.abs(y_test - preds) <= 7) * 100
    print(f"Accuracy (Within 1 week):\t{within_7days:.1f}%")
    
    os.makedirs("warfarin_pipeline/models", exist_ok=True)
    time_model.get_booster().save_model("warfarin_pipeline/models/time_to_stable_model.json")
    import joblib
    joblib.dump(preprocessor, "warfarin_pipeline/models/time_to_stable_preprocessor.joblib")
    print("Saved placeholder model to warfarin_pipeline/models/time_to_stable_model.json")
    print("Saved preprocessor to warfarin_pipeline/models/time_to_stable_preprocessor.joblib")

if __name__ == "__main__":
    if not os.path.exists("warfarin_pipeline/data/warfarin_cohort.csv"):
        print("Run data_generator.py first.")
    else:
        train_time_to_stability()
