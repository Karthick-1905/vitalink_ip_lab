import os
from pathlib import Path
import pandas as pd
import numpy as np
import xgboost as xgb
import joblib
from sklearn.metrics import r2_score, mean_squared_error, mean_absolute_error
from data_generator import generate_warfarin_data
from train_baseline import train_xgboost_baseline

BASE_DIR = Path(__file__).resolve().parent


def continuous_retrain(
    new_patients=500,
    model_path=BASE_DIR / "models" / "warfarin_model.json",
    preprocessor_path=BASE_DIR / "models" / "preprocessor.joblib",
):
    """Incrementally retrain the baseline XGBoost model with new synthetic patients."""
    print(f"Acquiring new batch of {new_patients} patients for incremental training...")
    df_new = generate_warfarin_data(new_patients, random_seed=456)
    
    model_path = Path(model_path)
    preprocessor_path = Path(preprocessor_path)

    if not model_path.exists() or not preprocessor_path.exists():
        print("Existing model/preprocessor not found. Bootstrapping baseline training for MLOps...")
        train_xgboost_baseline()
        if not model_path.exists() or not preprocessor_path.exists():
            print("Baseline bootstrap failed; cannot continue retraining.")
            return
        
    X_new = df_new.drop(columns=['WarfarinDose', 'Days_To_Stable'], errors='ignore')
    y_new = df_new['WarfarinDose']
    
    preprocessor = joblib.load(preprocessor_path)
    X_new_processed = preprocessor.transform(X_new)
    
    print("\n--- Pre-retraining Performance on New Data ---")
    old_model = xgb.XGBRegressor()
    old_model.load_model(model_path)
    
    preds_before = old_model.predict(X_new_processed)
    r2_before = r2_score(y_new, preds_before)
    rmse_before = np.sqrt(mean_squared_error(y_new, preds_before))
    print(f"Old Model R2 on new data: {r2_before:.4f}")
    print(f"Old Model RMSE on new data: {rmse_before:.4f}")
    
    print("\n--- Retraining Model Incrementally ---")
    previous_params = old_model.get_xgb_params()
    previous_params.update(
        {
            "objective": "reg:squarederror",
            "n_estimators": 50,
            "n_jobs": -1,
        }
    )

    incremental_model = xgb.XGBRegressor(
        **previous_params
    )
    
    incremental_model.fit(
        X_new_processed, y_new,
        xgb_model=model_path,
        verbose=False
    )
    
    print("\n--- Post-retraining Performance on New Data ---")
    preds_after = incremental_model.predict(X_new_processed)
    r2_after = r2_score(y_new, preds_after)
    rmse_after = np.sqrt(mean_squared_error(y_new, preds_after))
    mae_after = mean_absolute_error(y_new, preds_after)
    
    print(f"Retrained Model R2 on new data:   {r2_after:.4f}")
    print(f"Retrained Model RMSE on new data: {rmse_after:.4f}")
    print(f"Retrained Model MAE on new data:  {mae_after:.4f}")
    print(f"R2 Improved by:                   {(r2_after - r2_before):.4f}")
    
    output_path = BASE_DIR / "models" / "warfarin_model_v2.json"
    incremental_model.get_booster().save_model(output_path)
    print(f"\nUpdated model saved to {output_path}")

if __name__ == "__main__":
    continuous_retrain()
