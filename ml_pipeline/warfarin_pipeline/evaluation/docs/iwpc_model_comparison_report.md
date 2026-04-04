# Warfarin Model Comparison Report

## Scope
This report compares the repository model against the requested baseline machine-learning regressors and the IWPC dosing baselines derived from the official IWPC Excel calculator workbook.

## Data and Evaluation Setup
- Dataset: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/data/iwpc_warfarin.xls` (`Subject Data` sheet)
- IWPC calculator workbook referenced: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/data/iwpc_warfarin.xls`
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
| 1 | Our Model (Tuned LightGBM) | 11.8946 | 8.7178 | 0.4218 | 41.9530 |
| 2 | IWPC Pharmacogenetic Calculator | 11.9198 | 8.6526 | 0.4193 | 41.6817 |
| 3 | Linear Regression | 11.9216 | 8.7350 | 0.4192 | 42.0434 |
| 4 | Neural Network | 12.1569 | 8.8823 | 0.3960 | 41.7722 |
| 5 | XGBoost | 12.2350 | 8.8401 | 0.3882 | 41.7722 |
| 6 | Random Forest | 13.0668 | 9.5442 | 0.3022 | 40.3255 |
| 7 | IWPC Clinical Formula | 13.8394 | 10.0696 | 0.2173 | 35.6239 |

## Main Findings
- Best overall model on this split: **Our Model (Tuned LightGBM)** with RMSE `11.89` mg/week, MAE `8.72` mg/week, R² `0.422`, and `42.0%` within 20% of actual dose.
- Against the **IWPC Pharmacogenetic Calculator**, the best model reduced RMSE by `0.03` mg/week, trailed on MAE by `0.07` mg/week, and gained `0.3` points on within-20% accuracy.
- The **IWPC Clinical Formula** scored RMSE `13.84` mg/week and MAE `10.07` mg/week, showing the expected gap between a clinical-only rule and the stronger genotype-aware models.

## Visual Artifacts
- Model comparison dashboard: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_model_comparison.png`
- Prediction scatter comparison: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_prediction_scatter.png`
- SHAP summary bar chart: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_shap_bar.png`
- SHAP beeswarm chart: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_shap_beeswarm.png`

## SHAP Explainability Highlights
Top global drivers for the best model:

| feature | mean_abs_shap |
| --- | --- |
| VKORC1_A/A | 4.2535 |
| VKORC1_G/G | 3.2412 |
| Weight_kg | 3.0852 |
| Age_Decades | 2.9233 |
| CYP2C9_*1/*1 | 1.8285 |
| Height_cm | 1.0199 |
| Amiodarone | 0.5920 |
| Race_Group_Asian | 0.3484 |
| CYP2C9_*1/*3 | 0.3115 |
| VKORC1_Unknown | 0.3077 |

## Generated Files
- Metrics CSV: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_model_metrics.csv`
- Summary JSON: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_comparison_summary.json`
- SHAP importance CSV: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/iwpc_shap_top_features.csv`
- Best comparison model artifact: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/models/iwpc_best_comparison_model.joblib`
