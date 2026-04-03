import json
import os
import sys
import warnings
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import joblib
import matplotlib
import numpy as np
import pandas as pd
import seaborn as sns
from lightgbm import LGBMRegressor
from matplotlib import pyplot as plt
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import Pipeline
from xgboost import XGBRegressor

from train_baseline import create_preprocessor, get_feature_names_from_preprocessor, load_dataframe, preprocess_data

warnings.filterwarnings("ignore")
matplotlib.use("Agg")

BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "data" / "warfarin_cohort.csv"
OUTPUT_DIR = BASE_DIR / "output"
DOCS_DIR = BASE_DIR / "docs"
MODELS_DIR = BASE_DIR / "models"

METRICS_CSV_PATH = OUTPUT_DIR / "stability_model_metrics.csv"
SUMMARY_JSON_PATH = OUTPUT_DIR / "stability_comparison_summary.json"
LEADERBOARD_PLOT_PATH = OUTPUT_DIR / "stability_model_comparison.png"
SCATTER_PLOT_PATH = OUTPUT_DIR / "stability_prediction_scatter.png"
SHAP_BAR_PATH = OUTPUT_DIR / "stability_shap_bar.png"
SHAP_BEESWARM_PATH = OUTPUT_DIR / "stability_shap_beeswarm.png"
SHAP_FEATURES_CSV_PATH = OUTPUT_DIR / "stability_shap_top_features.csv"
REPORT_PATH = DOCS_DIR / "time_to_stability_report.md"
MODEL_ARTIFACT_PATH = MODELS_DIR / "best_time_to_stability_model.joblib"

RANDOM_STATE = 42
TEST_SIZE = 0.2


def evaluate_predictions(y_true: pd.Series, y_pred: np.ndarray) -> dict[str, float]:
    predictions = np.maximum(np.asarray(y_pred, dtype=float), 0.0)
    return {
        "r2": float(r2_score(y_true, predictions)),
        "rmse": float(np.sqrt(mean_squared_error(y_true, predictions))),
        "mae": float(mean_absolute_error(y_true, predictions)),
        "within_7_days_pct": float(np.mean(np.abs(predictions - y_true) <= 7.0) * 100.0),
    }


def dataframe_to_markdown(df: pd.DataFrame, float_columns: list[str]) -> str:
    rendered = df.copy()
    for column in float_columns:
        if column in rendered.columns:
            rendered[column] = rendered[column].map(lambda value: f"{value:.4f}")
    header = "| " + " | ".join(rendered.columns) + " |"
    separator = "| " + " | ".join(["---"] * len(rendered.columns)) + " |"
    rows = ["| " + " | ".join(map(str, row)) + " |" for row in rendered.to_numpy()]
    return "\n".join([header, separator, *rows])


def try_import_shap():
    try:
        import shap  # type: ignore

        return shap
    except ModuleNotFoundError:
        extra_path = "/tmp/codex_shap"
        if extra_path not in sys.path and Path(extra_path).exists():
            sys.path.insert(0, extra_path)
        import shap  # type: ignore

        return shap


def create_models(num_features, cat_features):
    return {
        "Linear Regression": Pipeline(
            steps=[("preprocessor", create_preprocessor(num_features, cat_features)), ("regressor", LinearRegression())]
        ),
        "Random Forest": Pipeline(
            steps=[
                ("preprocessor", create_preprocessor(num_features, cat_features)),
                (
                    "regressor",
                    RandomForestRegressor(
                        n_estimators=400,
                        min_samples_leaf=2,
                        random_state=RANDOM_STATE,
                        n_jobs=-1,
                    ),
                ),
            ]
        ),
        "XGBoost": Pipeline(
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
        ),
        "LightGBM": Pipeline(
            steps=[
                ("preprocessor", create_preprocessor(num_features, cat_features)),
                (
                    "regressor",
                    LGBMRegressor(
                        n_estimators=300,
                        learning_rate=0.05,
                        max_depth=4,
                        num_leaves=31,
                        subsample=0.9,
                        colsample_bytree=0.9,
                        random_state=RANDOM_STATE,
                        verbose=-1,
                    ),
                ),
            ]
        ),
        "Neural Network": Pipeline(
            steps=[
                ("preprocessor", create_preprocessor(num_features, cat_features)),
                (
                    "regressor",
                    MLPRegressor(
                        hidden_layer_sizes=(128, 64),
                        activation="relu",
                        alpha=0.0005,
                        learning_rate_init=0.001,
                        max_iter=1000,
                        early_stopping=True,
                        random_state=RANDOM_STATE,
                    ),
                ),
            ]
        ),
    }


def create_leaderboard_plot(metrics: pd.DataFrame):
    ordered = metrics.copy()
    ordered["model"] = pd.Categorical(ordered["model"], categories=ordered["model"], ordered=True)
    fig, axes = plt.subplots(2, 2, figsize=(18, 12))
    specs = [
        ("rmse", "RMSE (days)", True),
        ("mae", "MAE (days)", True),
        ("r2", "R²", False),
        ("within_7_days_pct", "Within 7 Days (%)", False),
    ]
    palette = sns.color_palette("crest", n_colors=len(ordered))

    for ax, (column, title, invert) in zip(axes.flat, specs):
        sns.barplot(data=ordered, y="model", x=column, ax=ax, palette=palette)
        ax.set_title(title)
        ax.set_xlabel("")
        ax.set_ylabel("")
        if invert:
            ax.invert_xaxis()
        for container in ax.containers:
            ax.bar_label(container, fmt="%.2f", padding=3)

    plt.suptitle("Time-to-Stability Model Comparison", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(LEADERBOARD_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_scatter_plot(y_true: pd.Series, predictions: dict[str, np.ndarray]):
    top_models = ["XGBoost", "LightGBM", "Linear Regression"]
    fig, axes = plt.subplots(1, 3, figsize=(18, 6), sharex=True, sharey=True)
    min_val = float(np.min(y_true))
    max_val = float(np.max(y_true))

    for ax, model_name in zip(axes, top_models):
        pred = np.maximum(predictions[model_name], 0.0)
        metrics = evaluate_predictions(y_true, pred)
        ax.scatter(y_true, pred, alpha=0.45, s=24, color="#1f6f8b")
        ax.plot([min_val, max_val], [min_val, max_val], linestyle="--", color="#c44536", linewidth=2)
        ax.set_title(model_name)
        ax.grid(alpha=0.25)
        ax.set_xlabel("Actual days to stable dose")
        ax.text(
            0.04,
            0.96,
            (
                f"RMSE {metrics['rmse']:.2f}\n"
                f"MAE {metrics['mae']:.2f}\n"
                f"R² {metrics['r2']:.3f}\n"
                f"Within 7d {metrics['within_7_days_pct']:.1f}%"
            ),
            transform=ax.transAxes,
            va="top",
            bbox={"boxstyle": "round", "facecolor": "white", "alpha": 0.85},
        )

    axes[0].set_ylabel("Predicted days to stable dose")
    plt.suptitle("Time-to-Stability Fit on Shared Test Set", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(SCATTER_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_shap_artifacts(best_model: Pipeline, x_train, x_test, num_features, cat_features):
    shap = try_import_shap()

    preprocessor = best_model.named_steps["preprocessor"]
    regressor = best_model.named_steps["regressor"]
    feature_names = get_feature_names_from_preprocessor(preprocessor, num_features, cat_features)

    x_train_transformed = preprocessor.transform(x_train)
    x_test_transformed = preprocessor.transform(x_test)

    background = x_train_transformed[: min(300, len(x_train_transformed))]
    explain = x_test_transformed[: min(400, len(x_test_transformed))]

    regressor_name = regressor.__class__.__name__.lower()
    if any(name in regressor_name for name in ["xgb", "lgbm", "forest"]):
        explainer = shap.TreeExplainer(regressor, data=background, feature_names=feature_names)
        shap_values = explainer.shap_values(explain, check_additivity=False)
    else:
        explainer = shap.Explainer(regressor, background, feature_names=feature_names)
        shap_values = explainer(explain).values

    mean_abs = np.abs(shap_values).mean(axis=0)
    importance = (
        pd.DataFrame({"feature": feature_names, "mean_abs_shap": mean_abs})
        .sort_values("mean_abs_shap", ascending=False)
        .reset_index(drop=True)
    )
    importance.to_csv(SHAP_FEATURES_CSV_PATH, index=False)

    plt.figure(figsize=(12, 8))
    shap.summary_plot(
        shap_values,
        features=explain,
        feature_names=feature_names,
        plot_type="bar",
        show=False,
        max_display=15,
    )
    plt.tight_layout()
    plt.savefig(SHAP_BAR_PATH, dpi=300, bbox_inches="tight")
    plt.close()

    plt.figure(figsize=(12, 8))
    shap.summary_plot(
        shap_values,
        features=explain,
        feature_names=feature_names,
        show=False,
        max_display=15,
    )
    plt.tight_layout()
    plt.savefig(SHAP_BEESWARM_PATH, dpi=300, bbox_inches="tight")
    plt.close()

    return importance


def write_report(metrics: pd.DataFrame, shap_importance: pd.DataFrame):
    best = metrics.iloc[0]
    best_nonlinear = metrics.loc[metrics["model"] != "Linear Regression"].iloc[0]

    lines = [
        "# Time-to-Stability Prediction Report",
        "",
        "## Scope",
        "This report benchmarks multiple regression models for predicting the number of days required to reach a stable warfarin regimen on the synthetic cohort used in this repository.",
        "",
        "## Data and Evaluation Setup",
        f"- Dataset: `{DATA_PATH}`",
        f"- Test split: {int(TEST_SIZE * 100)}% holdout with `random_state={RANDOM_STATE}`",
        "- Target: `Days_To_Stable`",
        "- Features: clinical, medication, and genotype fields from the synthetic cohort",
        "- Metrics: RMSE, MAE, R², and percentage of predictions within 7 days of the observed time to stability",
        "",
        "## Result Table",
        "",
        dataframe_to_markdown(metrics, ["rmse", "mae", "r2", "within_7_days_pct"]),
        "",
        "## Main Findings",
        f"- Best model: **{best['model']}** with RMSE `{best['rmse']:.2f}` days, MAE `{best['mae']:.2f}` days, R² `{best['r2']:.3f}`, and `{best['within_7_days_pct']:.1f}%` within one week.",
        f"- Relative to the best nonlinear contender (**{best_nonlinear['model']}**), the winner reduced RMSE by `{best_nonlinear['rmse'] - best['rmse']:.2f}` days and MAE by `{best_nonlinear['mae'] - best['mae']:.2f}` days.",
        "",
        "## Explainability Highlights",
        "Top SHAP features for the best time-to-stability model:",
        "",
        dataframe_to_markdown(shap_importance.head(10), ["mean_abs_shap"]),
        "",
        "## Artifacts",
        f"- Metrics CSV: `{METRICS_CSV_PATH}`",
        f"- Summary JSON: `{SUMMARY_JSON_PATH}`",
        f"- Leaderboard plot: `{LEADERBOARD_PLOT_PATH}`",
        f"- Scatter plot: `{SCATTER_PLOT_PATH}`",
        f"- SHAP bar chart: `{SHAP_BAR_PATH}`",
        f"- SHAP beeswarm chart: `{SHAP_BEESWARM_PATH}`",
        f"- Best model artifact: `{MODEL_ARTIFACT_PATH}`",
        "",
    ]

    REPORT_PATH.write_text("\n".join(lines))


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    df = load_dataframe(DATA_PATH)
    if "Days_To_Stable" not in df.columns:
        raise ValueError("Dataset does not contain Days_To_Stable.")

    x, _, _, num_features, cat_features = preprocess_data(df)
    y = pd.to_numeric(df["Days_To_Stable"], errors="coerce")
    valid_mask = y.notna()
    x = x.loc[valid_mask].reset_index(drop=True)
    y = y.loc[valid_mask].reset_index(drop=True)

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=TEST_SIZE, random_state=RANDOM_STATE
    )

    metrics_records = []
    predictions = {}
    fitted_models = {}

    for name, pipeline in create_models(num_features, cat_features).items():
        pipeline.fit(x_train, y_train)
        pred = np.maximum(pipeline.predict(x_test), 0.0)
        metrics_records.append({"model": name, **evaluate_predictions(y_test, pred)})
        predictions[name] = pred
        fitted_models[name] = pipeline

    metrics = pd.DataFrame(metrics_records).sort_values(["rmse", "mae"], ascending=[True, True]).reset_index(drop=True)
    metrics.insert(0, "rank", np.arange(1, len(metrics) + 1))
    metrics.to_csv(METRICS_CSV_PATH, index=False)

    best_model_name = metrics.iloc[0]["model"]
    best_model = fitted_models[best_model_name]
    joblib.dump(best_model, MODEL_ARTIFACT_PATH)

    create_leaderboard_plot(metrics)
    create_scatter_plot(y_test, predictions)
    shap_importance = create_shap_artifacts(best_model, x_train, x_test, num_features, cat_features)

    summary = {
        "dataset": str(DATA_PATH),
        "split": {"test_size": TEST_SIZE, "random_state": RANDOM_STATE},
        "best_model": best_model_name,
        "metrics": metrics.to_dict(orient="records"),
        "artifacts": {
            "metrics_csv": str(METRICS_CSV_PATH),
            "summary_json": str(SUMMARY_JSON_PATH),
            "leaderboard_plot": str(LEADERBOARD_PLOT_PATH),
            "scatter_plot": str(SCATTER_PLOT_PATH),
            "shap_bar": str(SHAP_BAR_PATH),
            "shap_beeswarm": str(SHAP_BEESWARM_PATH),
            "report": str(REPORT_PATH),
        },
    }
    SUMMARY_JSON_PATH.write_text(json.dumps(summary, indent=2))
    write_report(metrics, shap_importance)

    print(metrics.to_string(index=False))
    print(f"\nReport written to {REPORT_PATH}")


if __name__ == "__main__":
    main()
