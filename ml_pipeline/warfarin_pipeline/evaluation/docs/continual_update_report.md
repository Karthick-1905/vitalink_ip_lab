# Continual Update Evaluation Report

## Scope
This report evaluates a continual-update workflow in which dose and time-to-stability models are repeatedly retrained as new shifted patient batches arrive.

## Experimental Design
- Historical starting dataset: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/data/warfarin_cohort.csv`
- Incoming data: three shifted synthetic batches of 300 patients each
- Future evaluation cohort: one fixed shifted synthetic batch of 600 patients
- Update strategy: cumulative batch retraining from scratch after each incoming batch
- Model family: XGBoost with the repository preprocessing stack

## Round-by-Round Metrics

| round | train_size | dose_rmse | dose_mae | dose_r2 | dose_within_20_pct | stability_rmse | stability_mae | stability_r2 | stability_within_7_days_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Initial | 2500 | 13.5726 | 9.8458 | 0.0853 | 41.8333 | 7.5761 | 5.9861 | -0.5165 | 66.3333 |
| Update 1 | 2800 | 13.4919 | 9.6518 | 0.0961 | 42.1667 | 5.9120 | 4.7204 | 0.0766 | 76.0000 |
| Update 2 | 3100 | 13.5872 | 9.7366 | 0.0833 | 40.0000 | 5.7556 | 4.6189 | 0.1248 | 77.8333 |
| Update 3 | 3400 | 13.1581 | 9.3591 | 0.1403 | 43.1667 | 5.6852 | 4.5376 | 0.1461 | 78.1667 |

## Main Findings
- Dose model RMSE improved from `13.57` to `13.16` mg/week, while within-20% accuracy moved from `41.8%` to `43.2%`.
- Stability model RMSE improved from `7.58` to `5.69` days, while within-7-days accuracy moved from `66.3%` to `78.2%`.
- The experiment uses simulated covariate shift, so the interpretation is: continual retraining helps models adapt when the arriving patient mix differs from the original training cohort.

## Artifacts
- Metrics CSV: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_metrics.csv`
- Summary JSON: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_summary.json`
- Performance plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_performance.png`
- Shift plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_shift.png`
- Scatter plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_scatter.png`
- Final dose model: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/models/continual_dose_model_final.joblib`
- Final stability model: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/models/continual_stability_model_final.joblib`
