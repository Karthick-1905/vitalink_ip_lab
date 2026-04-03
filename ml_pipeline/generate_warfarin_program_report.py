import json
from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "output"
DOCS_DIR = BASE_DIR / "docs"

DOSE_METRICS = OUTPUT_DIR / "iwpc_model_metrics.csv"
DOSE_SHAP = OUTPUT_DIR / "iwpc_shap_top_features.csv"
STABILITY_METRICS = OUTPUT_DIR / "stability_model_metrics.csv"
STABILITY_SHAP = OUTPUT_DIR / "stability_shap_top_features.csv"
UPDATE_METRICS = OUTPUT_DIR / "continual_update_metrics.csv"
DOSE_SUMMARY = OUTPUT_DIR / "iwpc_comparison_summary.json"
STABILITY_SUMMARY = OUTPUT_DIR / "stability_comparison_summary.json"
UPDATE_SUMMARY = OUTPUT_DIR / "continual_update_summary.json"
REPORT_PATH = DOCS_DIR / "warfarin_full_program_report.md"


def dataframe_to_markdown(df: pd.DataFrame, float_columns: list[str]) -> str:
    rendered = df.copy()
    for column in float_columns:
        if column in rendered.columns:
            rendered[column] = rendered[column].map(lambda value: f"{value:.4f}")
    header = "| " + " | ".join(rendered.columns) + " |"
    separator = "| " + " | ".join(["---"] * len(rendered.columns)) + " |"
    rows = ["| " + " | ".join(map(str, row)) + " |" for row in rendered.to_numpy()]
    return "\n".join([header, separator, *rows])


def main():
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    dose_metrics = pd.read_csv(DOSE_METRICS)
    dose_shap = pd.read_csv(DOSE_SHAP).head(8)
    stability_metrics = pd.read_csv(STABILITY_METRICS)
    stability_shap = pd.read_csv(STABILITY_SHAP).head(8)
    update_metrics = pd.read_csv(UPDATE_METRICS)

    dose_summary = json.loads(DOSE_SUMMARY.read_text())
    stability_summary = json.loads(STABILITY_SUMMARY.read_text())
    update_summary = json.loads(UPDATE_SUMMARY.read_text())

    dose_best = dose_metrics.iloc[0]
    dose_iwpc = dose_metrics.loc[dose_metrics["model"] == "IWPC Pharmacogenetic Calculator"].iloc[0]
    stability_best = stability_metrics.iloc[0]
    update_initial = update_metrics.iloc[0]
    update_final = update_metrics.iloc[-1]

    lines = [
        "# Warfarin Modeling Program Report",
        "",
        "## Executive Summary",
        "This document consolidates the three requested workstreams for the warfarin pipeline:",
        "",
        "1. therapeutic dose prediction benchmarked against the IWPC calculator and baseline ML models",
        "2. time-to-stability prediction benchmarked across regression baselines",
        "3. continual-update evaluation showing how models improve after retraining on new shifted data",
        "",
        "## 1. Dosage Prediction",
        f"- Best model: **{dose_best['model']}**",
        f"- Best metrics: RMSE `{dose_best['rmse']:.2f}` mg/week, MAE `{dose_best['mae']:.2f}` mg/week, R² `{dose_best['r2']:.3f}`, within 20% `{dose_best['within_20_pct']:.1f}%`",
        f"- IWPC pharmacogenetic calculator: RMSE `{dose_iwpc['rmse']:.2f}` mg/week, MAE `{dose_iwpc['mae']:.2f}` mg/week, R² `{dose_iwpc['r2']:.3f}`",
        "",
        dataframe_to_markdown(dose_metrics[["rank", "model", "rmse", "mae", "r2", "within_20_pct"]], ["rmse", "mae", "r2", "within_20_pct"]),
        "",
        "Top SHAP features for dose prediction:",
        "",
        dataframe_to_markdown(dose_shap, ["mean_abs_shap"]),
        "",
        "Primary dose artifacts:",
        f"- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/docs/iwpc_model_comparison_report.md`",
        f"- `{dose_summary['artifacts']['comparison_plot']}`",
        f"- `{dose_summary['artifacts']['scatter_plot']}`",
        f"- `{dose_summary['artifacts']['shap_bar']}`",
        "",
        "## 2. Time-to-Stability Prediction",
        f"- Best model: **{stability_best['model']}**",
        f"- Best metrics: RMSE `{stability_best['rmse']:.2f}` days, MAE `{stability_best['mae']:.2f}` days, R² `{stability_best['r2']:.3f}`, within 7 days `{stability_best['within_7_days_pct']:.1f}%`",
        "- Interpretation: this synthetic target is comparatively linear, so classical regression performs as well as or better than tree ensembles.",
        "",
        dataframe_to_markdown(stability_metrics[["rank", "model", "rmse", "mae", "r2", "within_7_days_pct"]], ["rmse", "mae", "r2", "within_7_days_pct"]),
        "",
        "Top SHAP features for time-to-stability prediction:",
        "",
        dataframe_to_markdown(stability_shap, ["mean_abs_shap"]),
        "",
        "Primary stability artifacts:",
        f"- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/docs/time_to_stability_report.md`",
        f"- `{stability_summary['artifacts']['leaderboard_plot']}`",
        f"- `{stability_summary['artifacts']['scatter_plot']}`",
        f"- `{stability_summary['artifacts']['shap_bar']}`",
        "",
        "## 3. Continual Updates on New Data",
        "- Setup: historical training cohort plus three incoming shifted synthetic batches, evaluated against one fixed shifted future cohort.",
        f"- Dose adaptation: RMSE improved from `{update_initial['dose_rmse']:.2f}` to `{update_final['dose_rmse']:.2f}` mg/week; within-20% accuracy improved from `{update_initial['dose_within_20_pct']:.1f}%` to `{update_final['dose_within_20_pct']:.1f}%`.",
        f"- Stability adaptation: RMSE improved from `{update_initial['stability_rmse']:.2f}` to `{update_final['stability_rmse']:.2f}` days; within-7-days accuracy improved from `{update_initial['stability_within_7_days_pct']:.1f}%` to `{update_final['stability_within_7_days_pct']:.1f}%`.",
        "",
        dataframe_to_markdown(update_metrics, ["dose_rmse", "dose_mae", "dose_r2", "dose_within_20_pct", "stability_rmse", "stability_mae", "stability_r2", "stability_within_7_days_pct"]),
        "",
        "Primary continual-update artifacts:",
        f"- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/docs/continual_update_report.md`",
        f"- `{update_summary['artifacts']['performance_plot']}`",
        f"- `{update_summary['artifacts']['shift_plot']}`",
        f"- `{update_summary['artifacts']['scatter_plot']}`",
        "",
        "## Overall Recommendation",
        "- Use the tuned LightGBM dose model when the objective is best holdout accuracy against IWPC-like dosing baselines.",
        "- Keep the time-to-stability model simple unless a richer real-world target becomes available; current synthetic behavior does not justify a more complex learner.",
        "- Treat continual retraining as an operational requirement if the arriving patient mix shifts from the original cohort; the update experiment shows this can materially recover performance.",
        "",
        "## Presentation Artifacts",
        "- A redesigned combined HTML, PDF, and PPT deck is generated separately to replace the earlier misaligned HTML output.",
        "",
    ]

    REPORT_PATH.write_text("\n".join(lines))
    print(f"Wrote {REPORT_PATH}")


if __name__ == "__main__":
    main()
