from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split


BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "data" / "episodes.csv"
MODEL_PATH = BASE_DIR / "models" / "acitrom_dose_model.joblib"


def main() -> None:
    if not DATA_PATH.exists():
        print(f"Dataset not found: {DATA_PATH}")
        return

    df = pd.read_csv(DATA_PATH)
    feature_cols = [
        "lag_inr_1",
        "lag_inr_2",
        "lag_dose_1",
        "lag_dose_2",
        "delta_inr",
        "delta_dose",
        "rolling_ttr_3",
        "days_since_initiation",
    ]
    target_col = "stable_weekly_dose_mg"

    missing = [c for c in feature_cols + [target_col] if c not in df.columns]
    if missing:
        print(f"Missing required columns in episodes.csv: {missing}")
        return

    df = df.dropna(subset=[target_col])
    if len(df) < 30:
        print("Not enough labeled Acitrom rows for training yet (need at least 30).")
        return

    X = df[feature_cols]
    y = pd.to_numeric(df[target_col], errors="coerce")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
            ("regressor", RandomForestRegressor(n_estimators=200, random_state=42)),
        ]
    )
    model.fit(X_train, y_train)

    preds = model.predict(X_test)
    mae = mean_absolute_error(y_test, preds)
    rmse = mean_squared_error(y_test, preds) ** 0.5
    r2 = r2_score(y_test, preds)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_PATH)

    print("--- Acitrom model training complete ---")
    print(f"Rows used: {len(df)}")
    print(f"MAE:  {mae:.3f}")
    print(f"RMSE: {rmse:.3f}")
    print(f"R2:   {r2:.3f}")
    print(f"Saved model: {MODEL_PATH}")


if __name__ == "__main__":
    main()
