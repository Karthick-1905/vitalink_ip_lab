import json
import os
from pathlib import Path

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

from data_generator import generate_warfarin_data
from train_baseline import create_preprocessor, load_dataframe

matplotlib.use("Agg")

BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "data" / "warfarin_cohort.csv"
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
STABILITY_MODEL_PATH = MODELS_DIR / "continual_stability_model_final.joblib"

NUM_FEATURES = ["Age", "Height", "Weight", "Target_INR", "Renal_Function"]
CAT_FEATURES = ["Gender", "Amiodarone", "Aspirin", "Smoker", "CYP2C9", "VKORC1", "CYP4F2"]
FEATURE_COLUMNS = NUM_FEATURES + CAT_FEATURES
RANDOM_STATE = 42


def prepare_synthetic_frame(df: pd.DataFrame) -> pd.DataFrame:
    work = df.copy()
    for col in NUM_FEATURES + ["WarfarinDose", "Days_To_Stable"]:
        work[col] = pd.to_numeric(work[col], errors="coerce")
    for col in CAT_FEATURES:
        work[col] = work[col].astype(str).fillna("Unknown")
    work = work.dropna(subset=["WarfarinDose", "Days_To_Stable"]).reset_index(drop=True)
    return work


def simulate_shifted_incoming_batch(n_rows: int, random_seed: int) -> pd.DataFrame:
    rng = np.random.default_rng(random_seed)
    batch = prepare_synthetic_frame(generate_warfarin_data(n_rows, random_seed=random_seed))

    original_age = batch["Age"].copy()
    original_weight = batch["Weight"].copy()
    original_renal = batch["Renal_Function"].copy()
    original_target_inr = batch["Target_INR"].copy()
    original_amiodarone = (batch["Amiodarone"].str.lower() == "yes").astype(int)
    original_aspirin = (batch["Aspirin"].str.lower() == "yes").astype(int)

    age_shift = rng.integers(3, 10, size=len(batch))
    weight_shift = rng.normal(2.5, 3.0, size=len(batch))
    renal_shift = rng.normal(-12.0, 5.0, size=len(batch))
    inr_shift = rng.choice([0.0, 0.2, 0.3], size=len(batch), p=[0.35, 0.45, 0.20])

    batch["Age"] = np.clip(batch["Age"] + age_shift, 18, 95)
    batch["Weight"] = np.clip(batch["Weight"] + weight_shift, 35, 220)
    batch["Renal_Function"] = np.clip(batch["Renal_Function"] + renal_shift, 15, 130)
    batch["Target_INR"] = np.clip(batch["Target_INR"] + inr_shift, 1.5, 4.5)

    amio_flip = rng.random(len(batch)) < 0.18
    aspirin_flip = rng.random(len(batch)) < 0.10
    batch.loc[amio_flip, "Amiodarone"] = "Yes"
    batch.loc[aspirin_flip, "Aspirin"] = "Yes"

    batch["BMI"] = np.round(batch["Weight"] / ((batch["Height"] / 100.0) ** 2), 1).clip(14, 60)

    new_amiodarone = (batch["Amiodarone"].str.lower() == "yes").astype(int)
    new_aspirin = (batch["Aspirin"].str.lower() == "yes").astype(int)

    dose_delta = (
        -0.20 * (batch["Age"] - original_age)
        + 0.10 * (batch["Weight"] - original_weight)
        + 3.0 * (batch["Target_INR"] - original_target_inr)
        - 3.5 * (new_amiodarone - original_amiodarone)
        - 1.3 * (new_aspirin - original_aspirin)
        + 0.04 * (batch["Renal_Function"] - original_renal)
        + rng.normal(0, 1.8, len(batch))
    )
    batch["WarfarinDose"] = np.clip(batch["WarfarinDose"] + dose_delta, 3, 90).round(1)

    stability_delta = (
        0.45 * (batch["Age"] - original_age)
        - 0.08 * (batch["Renal_Function"] - original_renal)
        + 4.0 * (new_amiodarone - original_amiodarone)
        + 1.2 * (batch["Target_INR"] - original_target_inr) * 10
        + rng.normal(0, 1.5, len(batch))
    )
    batch["Days_To_Stable"] = np.clip(batch["Days_To_Stable"] + stability_delta, 7, 120).round()

    return batch


def build_xgb_pipeline() -> Pipeline:
    return Pipeline(
        steps=[
            ("preprocessor", create_preprocessor(NUM_FEATURES, CAT_FEATURES)),
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


def evaluate_stability(y_true: pd.Series, y_pred: np.ndarray) -> dict[str, float]:
    pred = np.maximum(np.asarray(y_pred, dtype=float), 0.0)
    return {
        "rmse": float(np.sqrt(mean_squared_error(y_true, pred))),
        "mae": float(mean_absolute_error(y_true, pred)),
        "r2": float(r2_score(y_true, pred)),
        "within_7_days_pct": float(np.mean(np.abs(pred - y_true) <= 7.0) * 100.0),
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
                "stability_rmse": record["stability"]["rmse"],
                "stability_mae": record["stability"]["mae"],
                "stability_r2": record["stability"]["r2"],
                "stability_within_7_days_pct": record["stability"]["within_7_days_pct"],
            }
        )
    return pd.DataFrame(rows)


def create_performance_plot(metrics_df: pd.DataFrame):
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    x = np.arange(len(metrics_df))
    labels = metrics_df["round"].tolist()

    axes[0, 0].plot(x, metrics_df["dose_rmse"], marker="o", linewidth=2.5, color="#9b2226")
    axes[0, 0].set_title("Dose RMSE Across Update Rounds")
    axes[0, 0].set_xticks(x, labels)
    axes[0, 0].grid(alpha=0.25)

    axes[0, 1].plot(x, metrics_df["dose_within_20_pct"], marker="o", linewidth=2.5, color="#0a9396")
    axes[0, 1].set_title("Dose Within 20% Accuracy")
    axes[0, 1].set_xticks(x, labels)
    axes[0, 1].grid(alpha=0.25)

    axes[1, 0].plot(x, metrics_df["stability_rmse"], marker="o", linewidth=2.5, color="#bb3e03")
    axes[1, 0].set_title("Stability RMSE Across Update Rounds")
    axes[1, 0].set_xticks(x, labels)
    axes[1, 0].grid(alpha=0.25)

    axes[1, 1].plot(x, metrics_df["stability_within_7_days_pct"], marker="o", linewidth=2.5, color="#005f73")
    axes[1, 1].set_title("Stability Within 7 Days Accuracy")
    axes[1, 1].set_xticks(x, labels)
    axes[1, 1].grid(alpha=0.25)

    plt.suptitle("Continual Update Performance on Shifted Future Cohort", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(PERFORMANCE_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_shift_plot(historical_df: pd.DataFrame, future_df: pd.DataFrame, incoming_batches: list[pd.DataFrame]):
    records = []
    cohorts = [("Historical train", historical_df)] + [
        (f"Incoming {idx}", batch) for idx, batch in enumerate(incoming_batches, start=1)
    ] + [("Future test", future_df)]

    for cohort_name, cohort in cohorts:
        records.extend(
            [
                {"cohort": cohort_name, "feature": "Age", "value": cohort["Age"].mean()},
                {"cohort": cohort_name, "feature": "Target INR", "value": cohort["Target_INR"].mean()},
                {"cohort": cohort_name, "feature": "Renal Function", "value": cohort["Renal_Function"].mean()},
                {"cohort": cohort_name, "feature": "Amiodarone rate", "value": (cohort["Amiodarone"].str.lower() == "yes").mean() * 100},
            ]
        )

    plot_df = pd.DataFrame(records)
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    for ax, feature in zip(axes.flat, ["Age", "Target INR", "Renal Function", "Amiodarone rate"]):
        subset = plot_df.loc[plot_df["feature"] == feature]
        sns.barplot(data=subset, x="cohort", y="value", ax=ax, palette="magma")
        ax.set_title(feature)
        ax.set_xlabel("")
        ax.set_ylabel("")
        ax.tick_params(axis="x", rotation=20)

    plt.suptitle("Simulated Covariate Shift in Continual-Update Study", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(SHIFT_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_scatter_plot(y_true_dose, initial_dose_pred, final_dose_pred, y_true_stability, initial_stab_pred, final_stab_pred):
    fig, axes = plt.subplots(1, 2, figsize=(14, 6))

    axes[0].scatter(y_true_dose, initial_dose_pred, alpha=0.35, s=20, color="#94d2bd", label="Initial")
    axes[0].scatter(y_true_dose, final_dose_pred, alpha=0.35, s=20, color="#bb3e03", label="Final")
    axes[0].plot([y_true_dose.min(), y_true_dose.max()], [y_true_dose.min(), y_true_dose.max()], "k--", lw=2)
    axes[0].set_title("Dose Prediction Before vs After Updates")
    axes[0].set_xlabel("Actual dose (mg/week)")
    axes[0].set_ylabel("Predicted dose")
    axes[0].legend()
    axes[0].grid(alpha=0.25)

    axes[1].scatter(y_true_stability, initial_stab_pred, alpha=0.35, s=20, color="#94d2bd", label="Initial")
    axes[1].scatter(y_true_stability, final_stab_pred, alpha=0.35, s=20, color="#bb3e03", label="Final")
    axes[1].plot([y_true_stability.min(), y_true_stability.max()], [y_true_stability.min(), y_true_stability.max()], "k--", lw=2)
    axes[1].set_title("Time-to-Stability Before vs After Updates")
    axes[1].set_xlabel("Actual days to stable dose")
    axes[1].set_ylabel("Predicted days")
    axes[1].legend()
    axes[1].grid(alpha=0.25)

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


def write_report(metrics_df: pd.DataFrame):
    initial = metrics_df.iloc[0]
    final = metrics_df.iloc[-1]

    lines = [
        "# Continual Update Evaluation Report",
        "",
        "## Scope",
        "This report evaluates a continual-update workflow in which dose and time-to-stability models are repeatedly retrained as new shifted patient batches arrive.",
        "",
        "## Experimental Design",
        f"- Historical starting dataset: `{DATA_PATH}`",
        "- Incoming data: three shifted synthetic batches of 300 patients each",
        "- Future evaluation cohort: one fixed shifted synthetic batch of 600 patients",
        "- Update strategy: cumulative batch retraining from scratch after each incoming batch",
        "- Model family: XGBoost with the repository preprocessing stack",
        "",
        "## Round-by-Round Metrics",
        "",
        dataframe_to_markdown(
            metrics_df,
            [
                "dose_rmse",
                "dose_mae",
                "dose_r2",
                "dose_within_20_pct",
                "stability_rmse",
                "stability_mae",
                "stability_r2",
                "stability_within_7_days_pct",
            ],
        ),
        "",
        "## Main Findings",
        f"- Dose model RMSE improved from `{initial['dose_rmse']:.2f}` to `{final['dose_rmse']:.2f}` mg/week, while within-20% accuracy moved from `{initial['dose_within_20_pct']:.1f}%` to `{final['dose_within_20_pct']:.1f}%`.",
        f"- Stability model RMSE improved from `{initial['stability_rmse']:.2f}` to `{final['stability_rmse']:.2f}` days, while within-7-days accuracy moved from `{initial['stability_within_7_days_pct']:.1f}%` to `{final['stability_within_7_days_pct']:.1f}%`.",
        "- The experiment uses simulated covariate shift, so the interpretation is: continual retraining helps models adapt when the arriving patient mix differs from the original training cohort.",
        "",
        "## Artifacts",
        f"- Metrics CSV: `{METRICS_CSV_PATH}`",
        f"- Summary JSON: `{SUMMARY_JSON_PATH}`",
        f"- Performance plot: `{PERFORMANCE_PLOT_PATH}`",
        f"- Shift plot: `{SHIFT_PLOT_PATH}`",
        f"- Scatter plot: `{SCATTER_PLOT_PATH}`",
        f"- Final dose model: `{DOSE_MODEL_PATH}`",
        f"- Final stability model: `{STABILITY_MODEL_PATH}`",
        "",
    ]
    REPORT_PATH.write_text("\n".join(lines))


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    historical_df = prepare_synthetic_frame(load_dataframe(DATA_PATH))
    incoming_batches = [simulate_shifted_incoming_batch(300, seed) for seed in [111, 222, 333]]
    future_test = simulate_shifted_incoming_batch(600, 999)

    x_future = future_test[FEATURE_COLUMNS]
    y_future_dose = future_test["WarfarinDose"]
    y_future_stability = future_test["Days_To_Stable"]

    training_df = historical_df.copy()
    round_records = []
    initial_dose_pred = None
    initial_stability_pred = None
    final_dose_pred = None
    final_stability_pred = None

    for round_idx in range(len(incoming_batches) + 1):
        x_train = training_df[FEATURE_COLUMNS]
        y_train_dose = training_df["WarfarinDose"]
        y_train_stability = training_df["Days_To_Stable"]

        dose_model = build_xgb_pipeline()
        stability_model = build_xgb_pipeline()
        dose_model.fit(x_train, y_train_dose)
        stability_model.fit(x_train, y_train_stability)

        dose_pred = np.maximum(dose_model.predict(x_future), 0.0)
        stability_pred = np.maximum(stability_model.predict(x_future), 0.0)

        record = {
            "round": "Initial" if round_idx == 0 else f"Update {round_idx}",
            "train_size": len(training_df),
            "dose": evaluate_dose(y_future_dose, dose_pred),
            "stability": evaluate_stability(y_future_stability, stability_pred),
        }
        round_records.append(record)

        if round_idx == 0:
            initial_dose_pred = dose_pred.copy()
            initial_stability_pred = stability_pred.copy()
        if round_idx == len(incoming_batches):
            final_dose_pred = dose_pred.copy()
            final_stability_pred = stability_pred.copy()
            joblib.dump(dose_model, DOSE_MODEL_PATH)
            joblib.dump(stability_model, STABILITY_MODEL_PATH)
        if round_idx < len(incoming_batches):
            training_df = pd.concat([training_df, incoming_batches[round_idx]], ignore_index=True)

    metrics_df = flatten_round_metrics(round_records)
    metrics_df.to_csv(METRICS_CSV_PATH, index=False)

    create_performance_plot(metrics_df)
    create_shift_plot(historical_df, future_test, incoming_batches)
    create_scatter_plot(
        y_future_dose,
        initial_dose_pred,
        final_dose_pred,
        y_future_stability,
        initial_stability_pred,
        final_stability_pred,
    )

    summary = {
        "historical_dataset": str(DATA_PATH),
        "incoming_batches": len(incoming_batches),
        "future_test_size": len(future_test),
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
            "stability_model": str(STABILITY_MODEL_PATH),
        },
    }
    SUMMARY_JSON_PATH.write_text(json.dumps(summary, indent=2))
    write_report(metrics_df)

    print(metrics_df.to_string(index=False))
    print(f"\nReport written to {REPORT_PATH}")


if __name__ == "__main__":
    main()
