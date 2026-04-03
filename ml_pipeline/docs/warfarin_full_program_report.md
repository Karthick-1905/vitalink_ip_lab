# Warfarin Modeling Program Report

## Executive Summary
This document consolidates the three requested workstreams for the warfarin pipeline:

1. therapeutic dose prediction benchmarked against the IWPC calculator and baseline ML models
2. time-to-stability prediction benchmarked across regression baselines
3. continual-update evaluation showing how models improve after retraining on new shifted data

## 1. Dosage Prediction
- Best model: **Our Model (Tuned LightGBM)**
- Best metrics: RMSE `11.90` mg/week, MAE `8.70` mg/week, R² `0.421`, within 20% `42.0%`
- IWPC pharmacogenetic calculator: RMSE `11.92` mg/week, MAE `8.65` mg/week, R² `0.419`

| rank | model | rmse | mae | r2 | within_20_pct |
| --- | --- | --- | --- | --- | --- |
| 1 | Our Model (Tuned LightGBM) | 11.9034 | 8.7012 | 0.4209 | 41.9530 |
| 2 | IWPC Pharmacogenetic Calculator | 11.9198 | 8.6526 | 0.4193 | 41.6817 |
| 3 | Linear Regression | 11.9238 | 8.7364 | 0.4190 | 41.3201 |
| 4 | Neural Network | 12.0937 | 8.8810 | 0.4023 | 41.5009 |
| 5 | XGBoost | 12.2332 | 8.8270 | 0.3884 | 41.4105 |
| 6 | Random Forest | 13.0928 | 9.5326 | 0.2994 | 39.6022 |
| 7 | IWPC Clinical Formula | 13.8394 | 10.0696 | 0.2173 | 35.6239 |

Top SHAP features for dose prediction:

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

Primary dose artifacts:
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/docs/iwpc_model_comparison_report.md`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_model_comparison.png`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_prediction_scatter.png`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/iwpc_shap_bar.png`

## 2. Time-to-Stability Prediction
- Best model: **Linear Regression**
- Best metrics: RMSE `4.19` days, MAE `3.32` days, R² `0.132`, within 7 days `89.6%`
- Interpretation: this synthetic target is comparatively linear, so classical regression performs as well as or better than tree ensembles.

| rank | model | rmse | mae | r2 | within_7_days_pct |
| --- | --- | --- | --- | --- | --- |
| 1 | Linear Regression | 4.1890 | 3.3222 | 0.1317 | 89.6000 |
| 2 | Neural Network | 4.1973 | 3.3245 | 0.1283 | 90.0000 |
| 3 | XGBoost | 4.2381 | 3.3537 | 0.1112 | 90.2000 |
| 4 | LightGBM | 4.2452 | 3.3213 | 0.1083 | 90.6000 |
| 5 | Random Forest | 4.2930 | 3.3777 | 0.0881 | 89.2000 |

Top SHAP features for time-to-stability prediction:

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

Primary stability artifacts:
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/docs/time_to_stability_report.md`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_model_comparison.png`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_prediction_scatter.png`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/stability_shap_bar.png`

## 3. Continual Updates on New Data
- Setup: historical training cohort plus three incoming shifted synthetic batches, evaluated against one fixed shifted future cohort.
- Dose adaptation: RMSE improved from `17.96` to `6.29` mg/week; within-20% accuracy improved from `22.3%` to `85.7%`.
- Stability adaptation: RMSE improved from `11.47` to `6.06` days; within-7-days accuracy improved from `39.0%` to `75.5%`.

| round | train_size | dose_rmse | dose_mae | dose_r2 | dose_within_20_pct | stability_rmse | stability_mae | stability_r2 | stability_within_7_days_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Initial | 2500 | 17.9595 | 15.5460 | -1.6979 | 22.3333 | 11.4675 | 9.5769 | -1.1793 | 39.0000 |
| Update 1 | 2800 | 7.8012 | 6.0524 | 0.4909 | 74.1667 | 6.2159 | 4.8622 | 0.3597 | 74.3333 |
| Update 2 | 3100 | 6.8023 | 5.2872 | 0.6130 | 81.6667 | 6.1223 | 4.8542 | 0.3788 | 75.3333 |
| Update 3 | 3400 | 6.2852 | 4.8853 | 0.6696 | 85.6667 | 6.0645 | 4.8235 | 0.3905 | 75.5000 |

Primary continual-update artifacts:
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/docs/continual_update_report.md`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_performance.png`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_shift.png`
- `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_scatter.png`

## Overall Recommendation
- Use the tuned LightGBM dose model when the objective is best holdout accuracy against IWPC-like dosing baselines.
- Keep the time-to-stability model simple unless a richer real-world target becomes available; current synthetic behavior does not justify a more complex learner.
- Treat continual retraining as an operational requirement if the arriving patient mix shifts from the original cohort; the update experiment shows this can materially recover performance.

## Presentation Artifacts
- A redesigned combined HTML, PDF, and PPT deck is generated separately to replace the earlier misaligned HTML output.
