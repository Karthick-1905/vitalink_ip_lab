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
HISTORICAL_DATA_PATH = BASE_DIR / "data" / "warfarin_cohort.csv"


def _prepare_features_targets(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    work = df.copy()
    X = work.drop(columns=["WarfarinDose", "Days_To_Stable"], errors="ignore")
    y = pd.to_numeric(work["WarfarinDose"], errors="coerce")
    valid = y.notna()
    return X.loc[valid].reset_index(drop=True), y.loc[valid].reset_index(drop=True)


def _build_weighted_replay_frame(
    df_new: pd.DataFrame,
    replay_source: pd.DataFrame,
    replay_ratio: float,
    recent_weight: float,
    replay_weight: float,
    random_seed: int,
) -> tuple[pd.DataFrame, pd.Series, np.ndarray]:
    X_new, y_new = _prepare_features_targets(df_new)

    replay_count = int(round(len(X_new) * max(replay_ratio, 0.0)))
    if replay_count <= 0 or replay_source.empty:
        sample_weight = np.full(len(X_new), max(recent_weight, 0.0), dtype=float)
        return X_new, y_new, sample_weight

    replay_candidates = replay_source.dropna(subset=["WarfarinDose"]).copy()
    if replay_candidates.empty:
        sample_weight = np.full(len(X_new), max(recent_weight, 0.0), dtype=float)
        return X_new, y_new, sample_weight

    replay_count = min(replay_count, len(replay_candidates))
    replay_df = replay_candidates.sample(n=replay_count, random_state=random_seed).reset_index(drop=True)
    X_replay, y_replay = _prepare_features_targets(replay_df)

    X_mix = pd.concat([X_new, X_replay], ignore_index=True)
    y_mix = pd.concat([y_new, y_replay], ignore_index=True)
    sample_weight = np.concatenate(
        [
            np.full(len(X_new), max(recent_weight, 0.0), dtype=float),
            np.full(len(X_replay), max(replay_weight, 0.0), dtype=float),
        ]
    )
    return X_mix, y_mix, sample_weight


def continuous_retrain(
    new_patients=500,
    model_path=BASE_DIR / "models" / "warfarin_model.json",
    preprocessor_path=BASE_DIR / "models" / "preprocessor.joblib",
    replay_ratio=1.0,
    recent_weight=0.7,
    replay_weight=0.3,
    random_seed=456,
):
    """Retrain with weighted replay: recent data plus sampled historical data."""
    print(f"Acquiring new batch of {new_patients} patients for incremental training...")
    df_new = generate_warfarin_data(new_patients, random_seed=random_seed)
    
    model_path = Path(model_path)
    preprocessor_path = Path(preprocessor_path)

    if not model_path.exists() or not preprocessor_path.exists():
        print("Existing model/preprocessor not found. Bootstrapping baseline training for MLOps...")
        train_xgboost_baseline()
        if not model_path.exists() or not preprocessor_path.exists():
            print("Baseline bootstrap failed; cannot continue retraining.")
            return

    if HISTORICAL_DATA_PATH.exists():
        replay_source = pd.read_csv(HISTORICAL_DATA_PATH)
    else:
        replay_source = pd.DataFrame()

    X_train, y_train, sample_weight = _build_weighted_replay_frame(
        df_new=df_new,
        replay_source=replay_source,
        replay_ratio=replay_ratio,
        recent_weight=recent_weight,
        replay_weight=replay_weight,
        random_seed=random_seed,
    )

    X_new, y_new = _prepare_features_targets(df_new)
    print(
        f"Weighted replay mix -> recent: {len(X_new)} rows, "
        f"replay: {max(len(X_train) - len(X_new), 0)} rows, "
        f"weights(recent/replay)=({recent_weight}/{replay_weight})"
    )
    
    preprocessor = joblib.load(preprocessor_path)
    X_train_processed = preprocessor.transform(X_train)
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
            X_train_processed,
            y_train,
            sample_weight=sample_weight,
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
    continuous_retrain(
        new_patients=int(os.getenv("WARFARIN_NEW_PATIENTS", "500")),
        replay_ratio=float(os.getenv("WARFARIN_REPLAY_RATIO", "1.0")),
        recent_weight=float(os.getenv("WARFARIN_RECENT_WEIGHT", "0.7")),
        replay_weight=float(os.getenv("WARFARIN_REPLAY_WEIGHT", "0.3")),
        random_seed=int(os.getenv("WARFARIN_RETRAIN_SEED", "456")),
    )
