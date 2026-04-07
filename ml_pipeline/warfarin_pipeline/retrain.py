import os
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

from train_baseline import load_dataframe, train_xgboost_baseline

BASE_DIR = Path(__file__).resolve().parent
HISTORICAL_DATA_PATH = BASE_DIR / "data" / "warfarin_cohort.csv"


def _prepare_features_targets(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    work = df.copy()
    x = work.drop(columns=["WarfarinDose"], errors="ignore")
    y = pd.to_numeric(work["WarfarinDose"], errors="coerce")
    valid = y.notna()
    return x.loc[valid].reset_index(drop=True), y.loc[valid].reset_index(drop=True)


def _build_weighted_replay_frame(
    df_new: pd.DataFrame,
    replay_source: pd.DataFrame,
    replay_ratio: float,
    recent_weight: float,
    replay_weight: float,
    random_seed: int,
) -> tuple[pd.DataFrame, pd.Series, np.ndarray]:
    x_new, y_new = _prepare_features_targets(df_new)

    replay_count = int(round(len(x_new) * max(replay_ratio, 0.0)))
    if replay_count <= 0 or replay_source.empty:
        sample_weight = np.full(len(x_new), max(recent_weight, 0.0), dtype=float)
        return x_new, y_new, sample_weight

    replay_candidates = replay_source.dropna(subset=["WarfarinDose"]).copy()
    if replay_candidates.empty:
        sample_weight = np.full(len(x_new), max(recent_weight, 0.0), dtype=float)
        return x_new, y_new, sample_weight

    replay_count = min(replay_count, len(replay_candidates))
    replay_df = replay_candidates.sample(n=replay_count, random_state=random_seed).reset_index(drop=True)
    x_replay, y_replay = _prepare_features_targets(replay_df)

    x_mix = pd.concat([x_new, x_replay], ignore_index=True)
    y_mix = pd.concat([y_new, y_replay], ignore_index=True)
    sample_weight = np.concatenate(
        [
            np.full(len(x_new), max(recent_weight, 0.0), dtype=float),
            np.full(len(x_replay), max(replay_weight, 0.0), dtype=float),
        ]
    )
    return x_mix, y_mix, sample_weight


def continuous_retrain(
    new_data_path=HISTORICAL_DATA_PATH,
    model_path=BASE_DIR / "models" / "warfarin_model.json",
    preprocessor_path=BASE_DIR / "models" / "preprocessor.joblib",
    replay_ratio=1.0,
    recent_weight=0.7,
    replay_weight=0.3,
    random_seed=456,
):
    new_data_path = Path(new_data_path)
    if not new_data_path.exists():
        raise FileNotFoundError(f"Incremental training data not found: {new_data_path}")

    print(f"Loading incremental training data from: {new_data_path}")
    df_new = load_dataframe(new_data_path)

    model_path = Path(model_path)
    preprocessor_path = Path(preprocessor_path)

    if not model_path.exists() or not preprocessor_path.exists():
        print("Existing model/preprocessor not found. Bootstrapping baseline training for MLOps...")
        train_xgboost_baseline()
        if not model_path.exists() or not preprocessor_path.exists():
            print("Baseline bootstrap failed; cannot continue retraining.")
            return

    replay_source_path = Path(os.getenv("WARFARIN_REPLAY_SOURCE", str(HISTORICAL_DATA_PATH)))
    replay_source = load_dataframe(replay_source_path) if replay_source_path.exists() else pd.DataFrame()

    x_train, y_train, sample_weight = _build_weighted_replay_frame(
        df_new=df_new,
        replay_source=replay_source,
        replay_ratio=replay_ratio,
        recent_weight=recent_weight,
        replay_weight=replay_weight,
        random_seed=random_seed,
    )

    x_new, y_new = _prepare_features_targets(df_new)
    print(
        f"Weighted replay mix -> recent: {len(x_new)} rows, "
        f"replay: {max(len(x_train) - len(x_new), 0)} rows, "
        f"weights(recent/replay)=({recent_weight}/{replay_weight})"
    )

    preprocessor = joblib.load(preprocessor_path)
    x_train_processed = preprocessor.transform(x_train)
    x_new_processed = preprocessor.transform(x_new)

    print("\n--- Pre-retraining Performance on Incremental Data ---")
    old_model = xgb.XGBRegressor()
    old_model.load_model(model_path)

    preds_before = old_model.predict(x_new_processed)
    r2_before = r2_score(y_new, preds_before)
    rmse_before = np.sqrt(mean_squared_error(y_new, preds_before))
    print(f"Old Model R2: {r2_before:.4f}")
    print(f"Old Model RMSE: {rmse_before:.4f}")

    print("\n--- Retraining Model Incrementally ---")
    previous_params = old_model.get_xgb_params()
    previous_params.update(
        {
            "objective": "reg:squarederror",
            "n_estimators": 50,
            "n_jobs": -1,
        }
    )

    incremental_model = xgb.XGBRegressor(**previous_params)

    incremental_model.fit(
        x_train_processed,
        y_train,
        sample_weight=sample_weight,
        xgb_model=model_path,
        verbose=False,
    )

    print("\n--- Post-retraining Performance on Incremental Data ---")
    preds_after = incremental_model.predict(x_new_processed)
    r2_after = r2_score(y_new, preds_after)
    rmse_after = np.sqrt(mean_squared_error(y_new, preds_after))
    mae_after = mean_absolute_error(y_new, preds_after)

    print(f"Retrained Model R2:   {r2_after:.4f}")
    print(f"Retrained Model RMSE: {rmse_after:.4f}")
    print(f"Retrained Model MAE:  {mae_after:.4f}")
    print(f"R2 Improved by:       {(r2_after - r2_before):.4f}")

    output_path = BASE_DIR / "models" / "warfarin_model_v2.json"
    incremental_model.get_booster().save_model(output_path)
    print(f"\nUpdated model saved to {output_path}")


if __name__ == "__main__":
    continuous_retrain(
        new_data_path=os.getenv("WARFARIN_INCREMENTAL_DATA", str(HISTORICAL_DATA_PATH)),
        replay_ratio=float(os.getenv("WARFARIN_REPLAY_RATIO", "1.0")),
        recent_weight=float(os.getenv("WARFARIN_RECENT_WEIGHT", "0.7")),
        replay_weight=float(os.getenv("WARFARIN_REPLAY_WEIGHT", "0.3")),
        random_seed=int(os.getenv("WARFARIN_RETRAIN_SEED", "456")),
    )
