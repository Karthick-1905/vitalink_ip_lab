# Time-to-Stability Prediction Report

## Scope
This report benchmarks multiple regression models for predicting the number of days required to reach a stable warfarin regimen on the synthetic cohort used in this repository.

## Data and Evaluation Setup
- Dataset: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/data/warfarin_cohort.csv`
- Test split: 20% holdout with `random_state=42`
- Target: `Days_To_Stable`
- Features: clinical, medication, and genotype fields from the synthetic cohort
- Metrics: RMSE, MAE, R², and percentage of predictions within 7 days of the observed time to stability

## Result Table

| rank | model | r2 | rmse | mae | within_7_days_pct |
| --- | --- | --- | --- | --- | --- |
| 1 | Linear Regression | 0.2176 | 5.2858 | 4.2334 | 81.6000 |
| 2 | Neural Network | 0.2148 | 5.2951 | 4.2416 | 81.4000 |
| 3 | LightGBM | 0.1555 | 5.4915 | 4.3833 | 80.4000 |
| 4 | XGBoost | 0.1544 | 5.4950 | 4.4075 | 78.8000 |
| 5 | Random Forest | 0.1306 | 5.5718 | 4.4699 | 77.4000 |

## Main Findings
- Best model: **Linear Regression** with RMSE `5.29` days, MAE `4.23` days, R² `0.218`, and `81.6%` within one week.
- Relative to the best nonlinear contender (**Neural Network**), the winner reduced RMSE by `0.01` days and MAE by `0.01` days.

## Explainability Highlights
Top SHAP features for the best time-to-stability model:

| feature | mean_abs_shap |
| --- | --- |
| CYP2C9_*1/*1 | 1.2156 |
| VKORC1_GG | 0.6982 |
| VKORC1_AA | 0.6735 |
| Smoker_No | 0.4239 |
| Smoker_Yes | 0.4239 |
| Age | 0.3416 |
| Renal_Function | 0.2871 |
| Weight | 0.2182 |
| Gender_Female | 0.1668 |
| Gender_Male | 0.1668 |

## Artifacts
- Metrics CSV: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/stability_model_metrics.csv`
- Summary JSON: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/stability_comparison_summary.json`
- Leaderboard plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/stability_model_comparison.png`
- Scatter plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/stability_prediction_scatter.png`
- SHAP bar chart: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/stability_shap_bar.png`
- SHAP beeswarm chart: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/stability_shap_beeswarm.png`
- Best model artifact: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/models/best_time_to_stability_model.joblib`
