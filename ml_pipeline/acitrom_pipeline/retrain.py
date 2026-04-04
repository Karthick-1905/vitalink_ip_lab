import os
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.pipeline import Pipeline


BASE_DIR = Path(__file__).resolve().parent
EPISODES_PATH = BASE_DIR / "data" / "episodes.csv"
REFERENCE_EPISODES_PATH = BASE_DIR / "data" / "reference_episodes.csv"
MODEL_PATH = BASE_DIR / "models" / "acitrom_dose_model.joblib"

FEATURE_COLS = [
    "lag_inr_1",
    "lag_inr_2",
    "lag_dose_1",
    "lag_dose_2",
    "delta_inr",
    "delta_dose",
    "rolling_ttr_3",
    "days_since_initiation",
]
TARGET_COL = "stable_weekly_dose_mg"


def _safe_frame(path: Path) -> pd.DataFrame:
    if not path.exists():
        return pd.DataFrame()
    return pd.read_csv(path)


def _prepare(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df
    work = df.copy()
    needed = FEATURE_COLS + [TARGET_COL]
    missing = [column for column in needed if column not in work.columns]
    if missing:
        return pd.DataFrame()

    for column in FEATURE_COLS + [TARGET_COL]:
        work[column] = pd.to_numeric(work[column], errors="coerce")
    work = work.dropna(subset=[TARGET_COL]).reset_index(drop=True)

    if "episode_date" in work.columns:
        work["episode_date"] = pd.to_datetime(work["episode_date"], errors="coerce")
        work = work.sort_values("episode_date", ascending=True).reset_index(drop=True)
    return work


def _split_recent_replay(df: pd.DataFrame, recent_count: int, replay_ratio: float, random_seed: int) -> tuple[pd.DataFrame, pd.DataFrame]:
    if len(df) <= recent_count:
        return df.copy(), pd.DataFrame(columns=df.columns)

    recent = df.tail(recent_count).reset_index(drop=True)
    historical_pool = df.iloc[:-recent_count].reset_index(drop=True)

    replay_count = int(round(len(recent) * max(replay_ratio, 0.0)))
    replay_count = min(replay_count, len(historical_pool))
    if replay_count <= 0:
        return recent, pd.DataFrame(columns=df.columns)

    replay = historical_pool.sample(n=replay_count, random_state=random_seed).reset_index(drop=True)
    return recent, replay


def retrain_acitrom(
    recent_count: int = 200,
    replay_ratio: float = 1.0,
    recent_weight: float = 0.7,
    replay_weight: float = 0.3,
    random_seed: int = 42,
) -> None:
    episodes = _prepare(_safe_frame(EPISODES_PATH))
    reference = _prepare(_safe_frame(REFERENCE_EPISODES_PATH))

    if episodes.empty and reference.empty:
        print("No Acitrom episode data available for retraining.")
        return

    if episodes.empty:
        combined = reference.copy()
    elif reference.empty:
        combined = episodes.copy()
    else:
        combined = pd.concat([reference, episodes], ignore_index=True)

    combined = combined.drop_duplicates().reset_index(drop=True)
    if len(combined) < 30:
        print("Not enough Acitrom labeled rows for retraining yet (need at least 30).")
        return

    recent, replay = _split_recent_replay(combined, recent_count=recent_count, replay_ratio=replay_ratio, random_seed=random_seed)
    if recent.empty:
        print("No recent Acitrom rows available; skipping retraining.")
        return

    train_df = pd.concat([recent, replay], ignore_index=True)
    X_train = train_df[FEATURE_COLS]
    y_train = train_df[TARGET_COL]

    sample_weight = np.concatenate(
        [
            np.full(len(recent), max(recent_weight, 0.0), dtype=float),
            np.full(len(replay), max(replay_weight, 0.0), dtype=float),
        ]
    )

    model = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
            ("regressor", RandomForestRegressor(n_estimators=300, random_state=random_seed)),
        ]
    )

    model.fit(X_train, y_train, regressor__sample_weight=sample_weight)

    eval_pred = model.predict(recent[FEATURE_COLS])
    eval_true = recent[TARGET_COL]
    mae = mean_absolute_error(eval_true, eval_pred)
    rmse = mean_squared_error(eval_true, eval_pred) ** 0.5
    r2 = r2_score(eval_true, eval_pred)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_PATH)

    print("--- Acitrom weighted replay retraining complete ---")
    print("Baseline formula predictor remains unchanged (cold-start logic is not retrained).")
    print(f"Recent rows: {len(recent)} | Replay rows: {len(replay)}")
    print(f"Weights (recent/replay): {recent_weight}/{replay_weight}")
    print(f"Recent-window MAE:  {mae:.3f}")
    print(f"Recent-window RMSE: {rmse:.3f}")
    print(f"Recent-window R2:   {r2:.3f}")
    print(f"Saved model: {MODEL_PATH}")


if __name__ == "__main__":
    retrain_acitrom(
        recent_count=int(os.getenv("ACITROM_RECENT_COUNT", "200")),
        replay_ratio=float(os.getenv("ACITROM_REPLAY_RATIO", "1.0")),
        recent_weight=float(os.getenv("ACITROM_RECENT_WEIGHT", "0.7")),
        replay_weight=float(os.getenv("ACITROM_REPLAY_WEIGHT", "0.3")),
        random_seed=int(os.getenv("ACITROM_RETRAIN_SEED", "42")),
    )
