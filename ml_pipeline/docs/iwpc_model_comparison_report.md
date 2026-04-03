# Warfarin Model Comparison Report

## Scope
This report compares the repository model against the requested baseline machine-learning regressors and the IWPC dosing baselines derived from the official IWPC Excel calculator workbook.

## Data and Evaluation Setup
- Dataset: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/data/iwpc_warfarin.xls` (`Subject Data` sheet)
- IWPC calculator workbook referenced: `/home/surya/Downloads/IWPC_dose_calculator.xls`
- Test split: 20% holdout with `random_state=42`
- Shared features: age in decades, height, weight, race, amiodarone, enzyme inducer, CYP2C9, VKORC1
- Numeric missing values for the closed-form IWPC formulas were imputed from training-set medians; categorical missingness was mapped to the calculator's `Unknown` categories
- Metrics: RMSE, MAE, R², and percentage of patients predicted within 20% of the true weekly dose

## IWPC Formula Sources
- Pharmacogenetic dosing algorithm: IWPC supplementary appendix section S1e
- Clinical dosing algorithm: IWPC supplementary appendix section S1f
- Reference PDF: https://stanford.edu/class/gene210/files/readings/IWPC_NEJM_Supplement.pdf

## Result Table

| rank | model | rmse | mae | r2 | within_20_pct |
| --- | --- | --- | --- | --- | --- |
| 1 | Our Model (Tuned LightGBM) | 11.9034 | 8.7012 | 0.4209 | 41.9530 |
| 2 | IWPC Pharmacogenetic Calculator | 11.9198 | 8.6526 | 0.4193 | 41.6817 |
| 3 | Linear Regression | 11.9238 | 8.7364 | 0.4190 | 41.3201 |
| 4 | Neural Network | 12.0937 | 8.8810 | 0.4023 | 41.5009 |
| 5 | XGBoost | 12.2332 | 8.8270 | 0.3884 | 41.4105 |
| 6 | Random Forest | 13.0928 | 9.5326 | 0.2994 | 39.6022 |
| 7 | IWPC Clinical Formula | 13.8394 | 10.0696 | 0.2173 | 35.6239 |

## Main Findings
- Best overall model on this split: **Our Model (Tuned LightGBM)** with RMSE `11.90` mg/week, MAE `8.70` mg/week, R² `0.421`, and `42.0%` within 20% of actual dose.
- Against the **IWPC Pharmacogenetic Calculator**, the best model reduced RMSE by `0.02` mg/week, trailed on MAE by `0.05` mg/week, and gained `0.3` points on within-20% accuracy.
- The **IWPC Clinical Formula** scored RMSE `13.84` mg/week and MAE `10.07` mg/week, showing the expected gap between a clinical-only rule and the stronger genotype-aware models.

## Visual Artifacts
- Model comparison dashboard: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_model_comparison.png`
- Prediction scatter comparison: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_prediction_scatter.png`
- SHAP summary bar chart: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_shap_bar.png`
- SHAP beeswarm chart: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_shap_beeswarm.png`

## SHAP Explainability Highlights
Top global drivers for the best model:

| feature | mean_abs_shap |
| --- | --- |
| VKORC1_A/A | 4.2923 |
| VKORC1_G/G | 3.2022 |
| Weight_kg | 3.0527 |
| Age_Decades | 3.0106 |
| CYP2C9_*1/*1 | 1.8551 |
| Height_cm | 1.0207 |
| Amiodarone | 0.5893 |
| Race_Group_Asian | 0.4400 |
| VKORC1_Unknown | 0.3324 |
| CYP2C9_*1/*3 | 0.3010 |

## Generated Files
- Metrics CSV: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_model_metrics.csv`
- Summary JSON: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_comparison_summary.json`
- SHAP importance CSV: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_shap_top_features.csv`
- Best comparison model artifact: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/models/iwpc_best_comparison_model.joblib`
