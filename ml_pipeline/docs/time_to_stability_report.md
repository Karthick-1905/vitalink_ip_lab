# Time-to-Stability Prediction Report

## Scope
This report benchmarks multiple regression models for predicting the number of days required to reach a stable warfarin regimen on the synthetic cohort used in this repository.

## Data and Evaluation Setup
- Dataset: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/data/warfarin_cohort.csv`
- Test split: 20% holdout with `random_state=42`
- Target: `Days_To_Stable`
- Features: clinical, medication, and genotype fields from the synthetic cohort
- Metrics: RMSE, MAE, R², and percentage of predictions within 7 days of the observed time to stability

## Result Table

| rank | model | r2 | rmse | mae | within_7_days_pct |
| --- | --- | --- | --- | --- | --- |
| 1 | Linear Regression | 0.1317 | 4.1890 | 3.3222 | 89.6000 |
| 2 | Neural Network | 0.1283 | 4.1973 | 3.3245 | 90.0000 |
| 3 | XGBoost | 0.1112 | 4.2381 | 3.3537 | 90.2000 |
| 4 | LightGBM | 0.1083 | 4.2452 | 3.3213 | 90.6000 |
| 5 | Random Forest | 0.0881 | 4.2930 | 3.3777 | 89.2000 |

## Main Findings
- Best model: **Linear Regression** with RMSE `4.19` days, MAE `3.32` days, R² `0.132`, and `89.6%` within one week.
- Relative to the best nonlinear contender (**Neural Network**), the winner reduced RMSE by `0.01` days and MAE by `0.00` days.

## Explainability Highlights
Top SHAP features for the best time-to-stability model:

| feature | mean_abs_shap |
| --- | --- |
| CYP2C9_*1/*1 | 0.8722 |
| VKORC1_GG | 0.5437 |
| Renal_Function | 0.3729 |
| Height | 0.3099 |
| VKORC1_AA | 0.2712 |
| VKORC1_GA | 0.1997 |
| Weight | 0.1750 |
| CYP2C9_*1/*3 | 0.1603 |
| Amiodarone_No | 0.1488 |
| Amiodarone_Yes | 0.1488 |

## Artifacts
- Metrics CSV: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_model_metrics.csv`
- Summary JSON: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_comparison_summary.json`
- Leaderboard plot: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_model_comparison.png`
- Scatter plot: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_prediction_scatter.png`
- SHAP bar chart: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_shap_bar.png`
- SHAP beeswarm chart: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_shap_beeswarm.png`
- Best model artifact: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/models/best_time_to_stability_model.joblib`
