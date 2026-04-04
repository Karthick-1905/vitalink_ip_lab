import json
import os
import sys
import warnings
from dataclasses import dataclass
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import joblib
import matplotlib
import numpy as np
import pandas as pd
import seaborn as sns
from lightgbm import LGBMRegressor
from matplotlib import pyplot as plt
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import KNNImputer, SimpleImputer
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from xgboost import XGBRegressor

warnings.filterwarnings("ignore")
matplotlib.use("Agg")

BASE_DIR = Path(__file__).resolve().parent
PIPELINE_DIR = BASE_DIR.parent
DATA_PATH = PIPELINE_DIR / "data" / "iwpc_warfarin.xls"
IWPC_WORKBOOK_PATH = Path(os.getenv("IWPC_WORKBOOK_PATH", str(DATA_PATH)))
OUTPUT_DIR = BASE_DIR / "output"
DOCS_DIR = BASE_DIR / "docs"
MODELS_DIR = BASE_DIR / "models"
SUMMARY_JSON_PATH = OUTPUT_DIR / "iwpc_comparison_summary.json"
METRICS_CSV_PATH = OUTPUT_DIR / "iwpc_model_metrics.csv"
COMPARISON_PLOT_PATH = OUTPUT_DIR / "iwpc_model_comparison.png"
SCATTER_PLOT_PATH = OUTPUT_DIR / "iwpc_prediction_scatter.png"
SHAP_BAR_PATH = OUTPUT_DIR / "iwpc_shap_bar.png"
SHAP_BEESWARM_PATH = OUTPUT_DIR / "iwpc_shap_beeswarm.png"
SHAP_FEATURES_CSV_PATH = OUTPUT_DIR / "iwpc_shap_top_features.csv"
REPORT_PATH = DOCS_DIR / "iwpc_model_comparison_report.md"
MODEL_ARTIFACT_PATH = MODELS_DIR / "iwpc_best_comparison_model.joblib"
RANDOM_STATE = 42
TEST_SIZE = 0.2


@dataclass
class FormulaContext:
    age_fill: float
    height_fill: float
    weight_fill: float


def load_dataset() -> pd.DataFrame:
    return pd.read_excel(DATA_PATH, sheet_name="Subject Data")


def map_age_band_to_decades(value):
    if pd.isna(value):
        return np.nan
    text = str(value).strip()
    mapping = {
        "10 - 19": 1.0,
        "20 - 29": 2.0,
        "30 - 39": 3.0,
        "40 - 49": 4.0,
        "50 - 59": 5.0,
        "60 - 69": 6.0,
        "70 - 79": 7.0,
        "80 - 89": 8.0,
        "90+": 9.0,
    }
    if text in mapping:
        return mapping[text]
    try:
        numeric = float(text)
        return numeric / 10.0
    except Exception:
        return np.nan


def normalize_race(value: str) -> str:
    if pd.isna(value):
        return "Other/Unknown"
    text = str(value).strip().lower()
    if any(token in text for token in ["asian", "japanese", "chinese", "korean", "malay", "indian", "filipino"]):
        return "Asian"
    if any(token in text for token in ["black", "african"]):
        return "Black"
    if any(token in text for token in ["white", "caucasian"]):
        return "White"
    return "Other/Unknown"


def normalize_cyp2c9(value: str) -> str:
    common = {"*1/*1", "*1/*2", "*1/*3", "*2/*2", "*2/*3", "*3/*3"}
    if pd.isna(value):
        return "Unknown"
    text = str(value).strip()
    return text if text in common else "Unknown"


def normalize_vkorc1(value: str) -> str:
    if pd.isna(value):
        return "Unknown"
    text = str(value).strip()
    return text if text in {"G/G", "A/G", "A/A"} else "Unknown"


def prepare_dataset(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    work = df.dropna(subset=["Therapeutic Dose of Warfarin"]).copy()
    work["Dose_mg_week"] = pd.to_numeric(work["Therapeutic Dose of Warfarin"], errors="coerce")
    work = work.dropna(subset=["Dose_mg_week"]).copy()

    work["Age_Decades"] = work["Age"].apply(map_age_band_to_decades)
    work["Height_cm"] = pd.to_numeric(work["Height (cm)"], errors="coerce")
    work["Weight_kg"] = pd.to_numeric(work["Weight (kg)"], errors="coerce")
    work["Race_Group"] = work["Race (Reported)"].apply(normalize_race)

    amiodarone = pd.to_numeric(work["Amiodarone (Cordarone)"], errors="coerce").fillna(0.0)
    work["Amiodarone"] = (amiodarone > 0).astype(float)

    inducer_cols = [
        "Carbamazepine (Tegretol)",
        "Phenytoin (Dilantin)",
        "Rifampin or Rifampicin",
    ]
    for column in inducer_cols:
        work[column] = pd.to_numeric(work[column], errors="coerce").fillna(0.0)
    work["Enzyme_Inducer"] = (work[inducer_cols].max(axis=1) > 0).astype(float)

    work["CYP2C9"] = work["Cyp2C9 genotypes"].apply(normalize_cyp2c9)
    work["VKORC1"] = work["VKORC1 -1639 consensus"].apply(normalize_vkorc1)

    features = work[
        [
            "Age_Decades",
            "Height_cm",
            "Weight_kg",
            "Race_Group",
            "Amiodarone",
            "Enzyme_Inducer",
            "CYP2C9",
            "VKORC1",
        ]
    ].copy()
    target = work["Dose_mg_week"].copy()
    return features, target


def build_preprocessor() -> ColumnTransformer:
    numeric_features = ["Age_Decades", "Height_cm", "Weight_kg", "Amiodarone", "Enzyme_Inducer"]
    categorical_features = ["Race_Group", "CYP2C9", "VKORC1"]

    numeric_pipeline = Pipeline(
        steps=[
            ("imputer", KNNImputer(n_neighbors=5)),
            ("scaler", StandardScaler()),
        ]
    )
    categorical_pipeline = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="constant", fill_value="Unknown")),
            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]
    )
    return ColumnTransformer(
        transformers=[
            ("num", numeric_pipeline, numeric_features),
            ("cat", categorical_pipeline, categorical_features),
        ]
    )


def build_models() -> dict[str, Pipeline]:
    tuned_lgbm = LGBMRegressor(
        n_estimators=445,
        learning_rate=0.018218827946353038,
        num_leaves=38,
        max_depth=3,
        min_child_samples=20,
        subsample=0.8425019015541142,
        colsample_bytree=0.6528296744060249,
        reg_alpha=0.005545639941752229,
        reg_lambda=0.07097419523880641,
        random_state=RANDOM_STATE,
        verbose=-1,
    )
    return {
        "Linear Regression": Pipeline(
            steps=[("preprocessor", build_preprocessor()), ("regressor", LinearRegression())]
        ),
        "Random Forest": Pipeline(
            steps=[
                ("preprocessor", build_preprocessor()),
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
                ("preprocessor", build_preprocessor()),
                (
                    "regressor",
                    XGBRegressor(
                        objective="reg:squarederror",
                        n_estimators=391,
                        learning_rate=0.030228166354651025,
                        max_depth=3,
                        min_child_weight=3,
                        subsample=0.8975129119153289,
                        colsample_bytree=0.6997735240645564,
                        gamma=4.266370741608514e-06,
                        reg_alpha=1.1291217680012138e-08,
                        reg_lambda=0.2203752223673274,
                        random_state=RANDOM_STATE,
                        n_jobs=-1,
                    ),
                ),
            ]
        ),
        "Neural Network": Pipeline(
            steps=[
                ("preprocessor", build_preprocessor()),
                (
                    "regressor",
                    MLPRegressor(
                        hidden_layer_sizes=(128, 64),
                        activation="relu",
                        alpha=0.001,
                        learning_rate_init=0.001,
                        max_iter=1000,
                        early_stopping=True,
                        random_state=RANDOM_STATE,
                    ),
                ),
            ]
        ),
        "Our Model (Tuned LightGBM)": Pipeline(
            steps=[("preprocessor", build_preprocessor()), ("regressor", tuned_lgbm)]
        ),
    }


def evaluate_predictions(y_true: pd.Series, y_pred: np.ndarray) -> dict[str, float]:
    predictions = np.maximum(np.asarray(y_pred, dtype=float), 0.0)
    return {
        "r2": float(r2_score(y_true, predictions)),
        "rmse": float(np.sqrt(mean_squared_error(y_true, predictions))),
        "mae": float(mean_absolute_error(y_true, predictions)),
        "within_20_pct": float(np.mean(np.abs(predictions - y_true) <= 0.20 * y_true) * 100.0),
    }


def make_formula_context(x_train: pd.DataFrame) -> FormulaContext:
    return FormulaContext(
        age_fill=float(x_train["Age_Decades"].median()),
        height_fill=float(x_train["Height_cm"].median()),
        weight_fill=float(x_train["Weight_kg"].median()),
    )


def iwpc_clinical_prediction(frame: pd.DataFrame, context: FormulaContext) -> np.ndarray:
    age = frame["Age_Decades"].fillna(context.age_fill).astype(float)
    height = frame["Height_cm"].fillna(context.height_fill).astype(float)
    weight = frame["Weight_kg"].fillna(context.weight_fill).astype(float)
    race = frame["Race_Group"].fillna("Other/Unknown")
    amiodarone = frame["Amiodarone"].fillna(0.0).astype(float)
    inducer = frame["Enzyme_Inducer"].fillna(0.0).astype(float)

    sqrt_dose = (
        4.0376
        - 0.2546 * age
        + 0.0118 * height
        + 0.0134 * weight
        - 0.6752 * (race == "Asian").astype(float)
        + 0.4060 * (race == "Black").astype(float)
        + 0.0443 * (race == "Other/Unknown").astype(float)
        + 1.2799 * inducer
        - 0.5695 * amiodarone
    )
    return np.square(np.maximum(sqrt_dose, 0.0))


def iwpc_pharmacogenetic_prediction(frame: pd.DataFrame, context: FormulaContext) -> np.ndarray:
    age = frame["Age_Decades"].fillna(context.age_fill).astype(float)
    height = frame["Height_cm"].fillna(context.height_fill).astype(float)
    weight = frame["Weight_kg"].fillna(context.weight_fill).astype(float)
    race = frame["Race_Group"].fillna("Other/Unknown")
    amiodarone = frame["Amiodarone"].fillna(0.0).astype(float)
    inducer = frame["Enzyme_Inducer"].fillna(0.0).astype(float)
    vkorc1 = frame["VKORC1"].fillna("Unknown")
    cyp2c9 = frame["CYP2C9"].fillna("Unknown")

    sqrt_dose = (
        5.6044
        - 0.2614 * age
        + 0.0087 * height
        + 0.0128 * weight
        - 0.8677 * (vkorc1 == "A/G").astype(float)
        - 1.6974 * (vkorc1 == "A/A").astype(float)
        - 0.4854 * (vkorc1 == "Unknown").astype(float)
        - 0.5211 * (cyp2c9 == "*1/*2").astype(float)
        - 0.9357 * (cyp2c9 == "*1/*3").astype(float)
        - 1.0616 * (cyp2c9 == "*2/*2").astype(float)
        - 1.9206 * (cyp2c9 == "*2/*3").astype(float)
        - 2.3312 * (cyp2c9 == "*3/*3").astype(float)
        - 0.2188 * (cyp2c9 == "Unknown").astype(float)
        - 0.1092 * (race == "Asian").astype(float)
        - 0.2760 * (race == "Black").astype(float)
        - 0.1032 * (race == "Other/Unknown").astype(float)
        + 1.1816 * inducer
        - 0.5503 * amiodarone
    )
    return np.square(np.maximum(sqrt_dose, 0.0))


def build_results_table(records: list[dict[str, float]]) -> pd.DataFrame:
    metrics = pd.DataFrame(records)
    metrics = metrics.sort_values(["rmse", "mae"], ascending=[True, True]).reset_index(drop=True)
    metrics["rank"] = np.arange(1, len(metrics) + 1)
    ordered_columns = ["rank", "model", "rmse", "mae", "r2", "within_20_pct"]
    return metrics[ordered_columns]


def dataframe_to_markdown(df: pd.DataFrame, float_columns: list[str]) -> str:
    rendered = df.copy()
    for column in float_columns:
        if column in rendered.columns:
            rendered[column] = rendered[column].map(lambda value: f"{value:.4f}")

    header = "| " + " | ".join(rendered.columns) + " |"
    separator = "| " + " | ".join(["---"] * len(rendered.columns)) + " |"
    rows = ["| " + " | ".join(map(str, row)) + " |" for row in rendered.to_numpy()]
    return "\n".join([header, separator, *rows])


def create_comparison_plot(metrics: pd.DataFrame):
    plot_df = metrics.copy()
    plot_df["model"] = pd.Categorical(plot_df["model"], categories=plot_df["model"], ordered=True)

    fig, axes = plt.subplots(2, 2, figsize=(18, 12))
    metric_specs = [
        ("rmse", "RMSE (mg/week)", True),
        ("mae", "MAE (mg/week)", True),
        ("r2", "R²", False),
        ("within_20_pct", "Within 20% (%)", False),
    ]
    palette = sns.color_palette("viridis", n_colors=len(plot_df))

    for ax, (column, title, invert) in zip(axes.flat, metric_specs):
        sns.barplot(data=plot_df, y="model", x=column, ax=ax, palette=palette)
        ax.set_title(title)
        ax.set_xlabel("")
        ax.set_ylabel("")
        if invert:
            ax.invert_xaxis()
        for container in ax.containers:
            ax.bar_label(container, fmt="%.2f", padding=4)

    plt.suptitle("Warfarin Dose Model Comparison vs. IWPC Baselines", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(COMPARISON_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def create_scatter_plot(y_true: pd.Series, predictions: dict[str, np.ndarray]):
    selected_models = [
        "Our Model (Tuned LightGBM)",
        "IWPC Pharmacogenetic Calculator",
        "XGBoost",
    ]
    fig, axes = plt.subplots(1, 3, figsize=(18, 6), sharex=True, sharey=True)
    min_val = float(np.min(y_true))
    max_val = float(np.max(y_true))

    for ax, model_name in zip(axes, selected_models):
        pred = np.maximum(predictions[model_name], 0.0)
        metrics = evaluate_predictions(y_true, pred)
        ax.scatter(y_true, pred, alpha=0.5, s=24, color="#1f77b4")
        ax.plot([min_val, max_val], [min_val, max_val], linestyle="--", color="#d62728", linewidth=2)
        ax.set_title(model_name)
        ax.set_xlabel("Actual dose (mg/week)")
        ax.grid(alpha=0.25)
        annotation = (
            f"RMSE {metrics['rmse']:.2f}\n"
            f"MAE {metrics['mae']:.2f}\n"
            f"R² {metrics['r2']:.3f}\n"
            f"Within 20% {metrics['within_20_pct']:.1f}%"
        )
        ax.text(
            0.04,
            0.96,
            annotation,
            transform=ax.transAxes,
            va="top",
            bbox={"boxstyle": "round", "facecolor": "white", "alpha": 0.85},
        )

    axes[0].set_ylabel("Predicted dose (mg/week)")
    plt.suptitle("Prediction Fit on Shared Test Set", fontsize=16, fontweight="bold")
    plt.tight_layout()
    fig.savefig(SCATTER_PLOT_PATH, dpi=300, bbox_inches="tight")
    plt.close(fig)


def extract_feature_names(preprocessor: ColumnTransformer) -> list[str]:
    return [name.replace("num__", "").replace("cat__", "") for name in preprocessor.get_feature_names_out()]


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


def create_shap_artifacts(best_model: Pipeline, x_train: pd.DataFrame, x_test: pd.DataFrame) -> pd.DataFrame:
    shap = try_import_shap()

    preprocessor = best_model.named_steps["preprocessor"]
    regressor = best_model.named_steps["regressor"]
    feature_names = extract_feature_names(preprocessor)

    x_train_transformed = preprocessor.transform(x_train)
    x_test_transformed = preprocessor.transform(x_test)

    background = x_train_transformed[: min(300, len(x_train_transformed))]
    explain = x_test_transformed[: min(400, len(x_test_transformed))]

    explainer = shap.TreeExplainer(regressor, data=background, feature_names=feature_names)
    shap_values = explainer.shap_values(explain, check_additivity=False)

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


def write_report(metrics: pd.DataFrame, shap_importance: pd.DataFrame | None):
    best_row = metrics.iloc[0]
    comparator_row = metrics.loc[metrics["model"] == "IWPC Pharmacogenetic Calculator"].iloc[0]
    clinical_row = metrics.loc[metrics["model"] == "IWPC Clinical Formula"].iloc[0]
    delta_rmse = comparator_row["rmse"] - best_row["rmse"]
    delta_mae = comparator_row["mae"] - best_row["mae"]
    delta_within20 = best_row["within_20_pct"] - comparator_row["within_20_pct"]
    mae_phrase = (
        f"reduced MAE by `{delta_mae:.2f}` mg/week"
        if delta_mae >= 0
        else f"trailed on MAE by `{abs(delta_mae):.2f}` mg/week"
    )

    lines = [
        "# Warfarin Model Comparison Report",
        "",
        "## Scope",
        "This report compares the repository model against the requested baseline machine-learning regressors and the IWPC dosing baselines derived from the official IWPC Excel calculator workbook.",
        "",
        "## Data and Evaluation Setup",
        f"- Dataset: `{DATA_PATH}` (`Subject Data` sheet)",
        f"- IWPC calculator workbook referenced: `{IWPC_WORKBOOK_PATH}`",
        f"- Test split: {int(TEST_SIZE * 100)}% holdout with `random_state={RANDOM_STATE}`",
        "- Shared features: age in decades, height, weight, race, amiodarone, enzyme inducer, CYP2C9, VKORC1",
        "- Numeric missing values for the closed-form IWPC formulas were imputed from training-set medians; categorical missingness was mapped to the calculator's `Unknown` categories",
        "- Metrics: RMSE, MAE, R², and percentage of patients predicted within 20% of the true weekly dose",
        "",
        "## IWPC Formula Sources",
        "- Pharmacogenetic dosing algorithm: IWPC supplementary appendix section S1e",
        "- Clinical dosing algorithm: IWPC supplementary appendix section S1f",
        "- Reference PDF: https://stanford.edu/class/gene210/files/readings/IWPC_NEJM_Supplement.pdf",
        "",
        "## Result Table",
        "",
        dataframe_to_markdown(metrics, ["rmse", "mae", "r2", "within_20_pct"]),
        "",
        "## Main Findings",
        f"- Best overall model on this split: **{best_row['model']}** with RMSE `{best_row['rmse']:.2f}` mg/week, MAE `{best_row['mae']:.2f}` mg/week, R² `{best_row['r2']:.3f}`, and `{best_row['within_20_pct']:.1f}%` within 20% of actual dose.",
        f"- Against the **IWPC Pharmacogenetic Calculator**, the best model reduced RMSE by `{delta_rmse:.2f}` mg/week, {mae_phrase}, and gained `{delta_within20:.1f}` points on within-20% accuracy.",
        f"- The **IWPC Clinical Formula** scored RMSE `{clinical_row['rmse']:.2f}` mg/week and MAE `{clinical_row['mae']:.2f}` mg/week, showing the expected gap between a clinical-only rule and the stronger genotype-aware models.",
        "",
        "## Visual Artifacts",
        f"- Model comparison dashboard: `{COMPARISON_PLOT_PATH}`",
        f"- Prediction scatter comparison: `{SCATTER_PLOT_PATH}`",
        f"- SHAP summary bar chart: `{SHAP_BAR_PATH}`",
        f"- SHAP beeswarm chart: `{SHAP_BEESWARM_PATH}`",
        "",
    ]

    if shap_importance is not None and not shap_importance.empty:
        lines.extend(
            [
                "## SHAP Explainability Highlights",
                "Top global drivers for the best model:",
                "",
                dataframe_to_markdown(shap_importance.head(10), ["mean_abs_shap"]),
                "",
            ]
        )

    lines.extend(
        [
            "## Generated Files",
            f"- Metrics CSV: `{METRICS_CSV_PATH}`",
            f"- Summary JSON: `{SUMMARY_JSON_PATH}`",
            f"- SHAP importance CSV: `{SHAP_FEATURES_CSV_PATH}`",
            f"- Best comparison model artifact: `{MODEL_ARTIFACT_PATH}`",
            "",
        ]
    )

    REPORT_PATH.write_text("\n".join(lines))


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    df = load_dataset()
    x, y = prepare_dataset(df)

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=TEST_SIZE, random_state=RANDOM_STATE
    )
    formula_context = make_formula_context(x_train)

    metrics_records = []
    predictions = {}
    fitted_models = {}

    baseline_predictions = {
        "IWPC Clinical Formula": iwpc_clinical_prediction(x_test, formula_context),
        "IWPC Pharmacogenetic Calculator": iwpc_pharmacogenetic_prediction(x_test, formula_context),
    }
    for name, pred in baseline_predictions.items():
        predictions[name] = pred
        metrics_records.append({"model": name, **evaluate_predictions(y_test, pred)})

    for name, pipeline in build_models().items():
        pipeline.fit(x_train, y_train)
        pred = np.maximum(pipeline.predict(x_test), 0.0)
        fitted_models[name] = pipeline
        predictions[name] = pred
        metrics_records.append({"model": name, **evaluate_predictions(y_test, pred)})

    metrics = build_results_table(metrics_records)
    metrics.to_csv(METRICS_CSV_PATH, index=False)

    best_model_name = metrics.iloc[0]["model"]
    best_model = fitted_models.get(best_model_name)
    if best_model is not None:
        joblib.dump(best_model, MODEL_ARTIFACT_PATH)

    create_comparison_plot(metrics)
    create_scatter_plot(y_test, predictions)

    shap_importance = None
    if best_model_name in fitted_models:
        shap_importance = create_shap_artifacts(fitted_models[best_model_name], x_train, x_test)

    summary = {
        "dataset": str(DATA_PATH),
        "iwpc_workbook": str(IWPC_WORKBOOK_PATH),
        "split": {"test_size": TEST_SIZE, "random_state": RANDOM_STATE},
        "best_model": best_model_name,
        "metrics": metrics.to_dict(orient="records"),
        "artifacts": {
            "metrics_csv": str(METRICS_CSV_PATH),
            "comparison_plot": str(COMPARISON_PLOT_PATH),
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
