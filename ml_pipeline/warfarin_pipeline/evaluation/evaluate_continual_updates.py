import json
import os
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
PIPELINE_DIR = BASE_DIR.parent
if str(PIPELINE_DIR) not in sys.path:
    sys.path.insert(0, str(PIPELINE_DIR))

os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import joblib
import matplotlib
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.pipeline import Pipeline
from xgboost import XGBRegressor

from preprocessing import create_preprocessor, load_dataframe, prepare_warfarin_dose_dataset

matplotlib.use("Agg")

PRIMARY_DATA_PATH = PIPELINE_DIR / "data" / "warfarin_cohort.csv"
FALLBACK_DATA_PATH = PIPELINE_DIR / "data" / "iwpc_warfarin.xls"
OUTPUT_DIR = BASE_DIR / "output"
DOCS_DIR = BASE_DIR / "docs"
MODELS_DIR = BASE_DIR / "models"

METRICS_CSV_PATH = OUTPUT_DIR / "continual_update_metrics.csv"
SUMMARY_JSON_PATH = OUTPUT_DIR / "continual_update_summary.json"
PERFORMANCE_PLOT_PATH = OUTPUT_DIR / "continual_update_performance.png"
SHIFT_PLOT_PATH = OUTPUT_DIR / "continual_update_shift.png"
SCATTER_PLOT_PATH = OUTPUT_DIR / "continual_update_scatter.png"
REPORT_PATH = DOCS_DIR / "continual_update_report.md"
DOSE_MODEL_PATH = MODELS_DIR / "continual_dose_model_final.joblib"

RANDOM_STATE = 42


def resolve_data_path() -> Path:
    configured = os.getenv("WARFARIN_CONTINUAL_DATA")
    if configured:
        path = Path(configured)
        if path.exists():
            return path
    if PRIMARY_DATA_PATH.exists():
        return PRIMARY_DATA_PATH
    if FALLBACK_DATA_PATH.exists():
        return FALLBACK_DATA_PATH
    raise FileNotFoundError("No dataset found for continual evaluation. Set WARFARIN_CONTINUAL_DATA to a valid CSV/XLS file.")


def prepare_frame(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series, list[str], list[str]]:
    x, y, num_features, cat_features_clinical, cat_features_genetic, _ = prepare_warfarin_dose_dataset(df)
    cat_features = cat_features_clinical + cat_features_genetic
    return x.reset_index(drop=True), y.reset_index(drop=True), num_features, cat_features


def simulate_shifted_incoming_batch(
    source_x: pd.DataFrame,
    source_y: pd.Series,
    n_rows: int,
    random_seed: int,
    num_features: list[str],
) -> tuple[pd.DataFrame, pd.Series]:
    rng = np.random.default_rng(random_seed)
    idx = rng.choice(len(source_x), size=n_rows, replace=len(source_x) < n_rows)

    x_batch = source_x.iloc[idx].reset_index(drop=True).copy()
    y_batch = source_y.iloc[idx].reset_index(drop=True).copy()
    x_original = x_batch.copy()

    for column in num_features:
        if column not in x_batch.columns:
            continue
        col = pd.to_numeric(x_batch[column], errors="coerce")
        if col.isna().all():
            continue

        if "age" in column.lower():
            shift = rng.integers(1, 6, size=len(x_batch))
            x_batch[column] = np.clip(col + shift, col.quantile(0.01), col.quantile(0.99))
        elif "inr" in column.lower():
            shift = rng.choice([0.0, 0.1, 0.2], size=len(x_batch), p=[0.5, 0.35, 0.15])
            x_batch[column] = np.clip(col + shift, col.quantile(0.01), col.quantile(0.99))
        else:
            std = float(col.std()) if float(col.std()) > 0 else 1.0
            shift = rng.normal(0.1 * std, 0.15 * std, size=len(x_batch))
            x_batch[column] = np.clip(col + shift, col.quantile(0.01), col.quantile(0.99))

    drift_score = np.zeros(len(x_batch), dtype=float)
    for column in num_features:
        if column in x_batch.columns and column in x_original.columns:
            new_col = pd.to_numeric(x_batch[column], errors="coerce").fillna(0.0)
            old_col = pd.to_numeric(x_original[column], errors="coerce").fillna(0.0)
            denom = max(float(old_col.std()), 1.0)
            drift_score += (new_col - old_col) / denom

    y_batch = np.clip(y_batch + 0.9 * drift_score + rng.normal(0, 1.2, size=len(x_batch)), 3, 90)
    return x_batch, y_batch


def build_xgb_pipeline(num_features: list[str], cat_features: list[str]) -> Pipeline:
    return Pipeline(
        steps=[
            ("preprocessor", create_preprocessor(num_features, cat_features)),
            (
                "regressor",
                XGBRegressor(
                    objective="reg:squarederror",
                    n_estimators=300,
                    learning_rate=0.05,
                    max_depth=4,
                    min_child_weight=2,
                    subsample=0.9,
                    colsample_bytree=0.9,
                    random_state=RANDOM_STATE,
                    n_jobs=-1,
                ),
            ),
        ]
    )


def evaluate_dose(y_true: pd.Series, y_pred: np.ndarray) -> dict[str, float]:
    pred = np.maximum(np.asarray(y_pred, dtype=float), 0.0)
    return {
        "rmse": float(np.sqrt(mean_squared_error(y_true, pred))),
        "mae": float(mean_absolute_error(y_true, pred)),
        "r2": float(r2_score(y_true, pred)),
        "within_20_pct": float(np.mean(np.abs(pred - y_true) <= 0.20 * y_true) * 100.0),
    }


def flatten_round_metrics(records: list[dict]) -> pd.DataFrame:
    rows = []
    for record in records:
        rows.append(
            {
                "round": record["round"],
                "train_size": record["train_size"],
                "dose_rmse": record["dose"]["rmse"],
                "dose_mae": record["dose"]["mae"],
                "dose_r2": record["dose"]["r2"],
                "dose_within_20_pct": record["dose"]["within_20_pct"],
            }
        )
    return pd.DataFrame(rows)


def create_performance_plot(metrics_df: pd.DataFrame):
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    x = np.arange(len(metrics_df))
    labels = metrics_df["round"].tolist()

    axes[0].plot(x, metrics_df["dose_rmse"], marker="o", linewidth=2.5, color="#9b2226")
    axes[0].set_title("Dose RMSE Across Update Rounds")
    axes[0].set_xticks(x, labels)
    axes[0].grid(alpha=0.25)

    axes[1].plot(x, metrics_df["dose_within_20_pct"], marker="o", linewidth=2.5, color="#0a9396")
    axes[1].set_title("Dose Within 20% Accuracy")
    axes[1].set_xticks(x, labels)
    axes[1].grid(alpha=0.25)

    plt.suptitle("Continual Update Performance on Shifted Future Cohort", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(PERFORMANCE_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_shift_plot(historical_x: pd.DataFrame, future_x: pd.DataFrame, incoming_batches: list[pd.DataFrame], num_features: list[str]):
    tracked = num_features[:4] if len(num_features) >= 4 else num_features
    records = []
    cohorts = [("Historical train", historical_x)] + [
        (f"Incoming {idx}", batch) for idx, batch in enumerate(incoming_batches, start=1)
    ] + [("Future test", future_x)]

    for cohort_name, cohort in cohorts:
        for feature in tracked:
            if feature in cohort.columns:
                value = pd.to_numeric(cohort[feature], errors="coerce").mean()
                records.append({"cohort": cohort_name, "feature": feature, "value": value})

    if not records:
        return

    plot_df = pd.DataFrame(records)
    rows = 2
    cols = 2
    fig, axes = plt.subplots(rows, cols, figsize=(16, 10))
    axes_flat = axes.flatten()

    for idx, feature in enumerate(tracked):
        if idx >= len(axes_flat):
            break
        ax = axes_flat[idx]
        subset = plot_df.loc[plot_df["feature"] == feature]
        sns.barplot(data=subset, x="cohort", y="value", ax=ax, palette="magma")
        ax.set_title(feature)
        ax.set_xlabel("")
        ax.set_ylabel("")
        ax.tick_params(axis="x", rotation=20)

    for idx in range(len(tracked), len(axes_flat)):
        axes_flat[idx].axis("off")

    plt.suptitle("Simulated Covariate Shift in Continual-Update Study", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(SHIFT_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_scatter_plot(y_true_dose, initial_dose_pred, final_dose_pred):
    fig, ax = plt.subplots(1, 1, figsize=(7, 6))

    ax.scatter(y_true_dose, initial_dose_pred, alpha=0.35, s=20, color="#94d2bd", label="Initial")
    ax.scatter(y_true_dose, final_dose_pred, alpha=0.35, s=20, color="#bb3e03", label="Final")
    ax.plot([y_true_dose.min(), y_true_dose.max()], [y_true_dose.min(), y_true_dose.max()], "k--", lw=2)
    ax.set_title("Dose Prediction Before vs After Updates")
    ax.set_xlabel("Actual dose (mg/week)")
    ax.set_ylabel("Predicted dose")
    ax.legend()
    ax.grid(alpha=0.25)

    plt.suptitle("Prediction Fit Improvement After Continual Retraining", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(SCATTER_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def dataframe_to_markdown(df: pd.DataFrame, float_columns: list[str]) -> str:
    rendered = df.copy()
    for col in float_columns:
        if col in rendered.columns:
            rendered[col] = rendered[col].map(lambda value: f"{value:.4f}")
    header = "| " + " | ".join(rendered.columns) + " |"
    separator = "| " + " | ".join(["---"] * len(rendered.columns)) + " |"
    rows = ["| " + " | ".join(map(str, row)) + " |" for row in rendered.to_numpy()]
    return "\n".join([header, separator, *rows])


def write_report(metrics_df: pd.DataFrame, dataset_path: Path):
    initial = metrics_df.iloc[0]
    final = metrics_df.iloc[-1]

    lines = [
        "# Continual Update Evaluation Report",
        "",
        "## Scope",
        "This report evaluates a dose-only continual-update workflow in which the warfarin dose model is repeatedly retrained as new shifted patient batches arrive.",
        "",
        "## Experimental Design",
        f"- Historical starting dataset: `{dataset_path}`",
        "- Incoming data: three shifted batches of 300 patients each (sampled and perturbed from current training cohort)",
        "- Future evaluation cohort: one fixed shifted batch of 600 patients",
        "- Update strategy: cumulative batch retraining from scratch after each incoming batch",
        "- Model family: XGBoost with the repository preprocessing stack",
        "",
        "## Round-by-Round Metrics",
        "",
        dataframe_to_markdown(
            metrics_df,
            ["dose_rmse", "dose_mae", "dose_r2", "dose_within_20_pct"],
        ),
        "",
        "## Main Findings",
        f"- Dose model RMSE changed from `{initial['dose_rmse']:.2f}` to `{final['dose_rmse']:.2f}` mg/week, while within-20% accuracy moved from `{initial['dose_within_20_pct']:.1f}%` to `{final['dose_within_20_pct']:.1f}%`.",
        "- The experiment simulates covariate shift by perturbing real training-cohort rows and is intended for continual-learning behavior analysis.",
        "",
        "## Artifacts",
        f"- Metrics CSV: `{METRICS_CSV_PATH}`",
        f"- Summary JSON: `{SUMMARY_JSON_PATH}`",
        f"- Performance plot: `{PERFORMANCE_PLOT_PATH}`",
        f"- Shift plot: `{SHIFT_PLOT_PATH}`",
        f"- Scatter plot: `{SCATTER_PLOT_PATH}`",
        f"- Final dose model: `{DOSE_MODEL_PATH}`",
        "",
    ]
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines))


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    dataset_path = resolve_data_path()
    source_df = load_dataframe(dataset_path)
    historical_x, historical_y, num_features, cat_features = prepare_frame(source_df)

    incoming_xy = [simulate_shifted_incoming_batch(historical_x, historical_y, 300, seed, num_features) for seed in [111, 222, 333]]
    future_x, future_y_dose = simulate_shifted_incoming_batch(historical_x, historical_y, 600, 999, num_features)

    training_x = historical_x.copy()
    training_y = historical_y.copy()
    round_records = []
    initial_dose_pred = None
    final_dose_pred = None

    for round_idx in range(len(incoming_xy) + 1):
        dose_model = build_xgb_pipeline(num_features, cat_features)
        dose_model.fit(training_x, training_y)

        dose_pred = np.maximum(dose_model.predict(future_x), 0.0)

        record = {
            "round": "Initial" if round_idx == 0 else f"Update {round_idx}",
            "train_size": len(training_x),
            "dose": evaluate_dose(future_y_dose, dose_pred),
        }
        round_records.append(record)

        if round_idx == 0:
            initial_dose_pred = dose_pred.copy()
        if round_idx == len(incoming_xy):
            final_dose_pred = dose_pred.copy()
            joblib.dump(dose_model, DOSE_MODEL_PATH)
        if round_idx < len(incoming_xy):
            next_x, next_y = incoming_xy[round_idx]
            training_x = pd.concat([training_x, next_x], ignore_index=True)
            training_y = pd.concat([training_y, next_y], ignore_index=True)

    metrics_df = flatten_round_metrics(round_records)
    metrics_df.to_csv(METRICS_CSV_PATH, index=False)

    incoming_x_only = [item[0] for item in incoming_xy]
    create_performance_plot(metrics_df)
    create_shift_plot(historical_x, future_x, incoming_x_only, num_features)
    create_scatter_plot(future_y_dose, initial_dose_pred, final_dose_pred)

    summary = {
        "historical_dataset": str(dataset_path),
        "incoming_batches": len(incoming_xy),
        "future_test_size": len(future_x),
        "update_strategy": "cumulative batch retraining on shifted incoming cohorts",
        "rounds": round_records,
        "artifacts": {
            "metrics_csv": str(METRICS_CSV_PATH),
            "summary_json": str(SUMMARY_JSON_PATH),
            "performance_plot": str(PERFORMANCE_PLOT_PATH),
            "shift_plot": str(SHIFT_PLOT_PATH),
            "scatter_plot": str(SCATTER_PLOT_PATH),
            "report": str(REPORT_PATH),
            "dose_model": str(DOSE_MODEL_PATH),
        },
    }
    SUMMARY_JSON_PATH.write_text(json.dumps(summary, indent=2))
    write_report(metrics_df, dataset_path)

    print(metrics_df.to_string(index=False))
    print(f"\nReport written to {REPORT_PATH}")


if __name__ == "__main__":
    main()
