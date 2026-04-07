# Continual Update Evaluation Report

## Scope
This report evaluates a dose-only continual-update workflow in which the warfarin dose model is repeatedly retrained as new shifted patient batches arrive.

## Experimental Design
- Historical starting dataset: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/data/iwpc_warfarin.xls`
- Incoming data: three shifted batches of 300 patients each (sampled and perturbed from current training cohort)
- Future evaluation cohort: one fixed shifted batch of 600 patients
- Update strategy: cumulative batch retraining from scratch after each incoming batch
- Model family: XGBoost with the repository preprocessing stack

## Round-by-Round Metrics

| round | train_size | dose_rmse | dose_mae | dose_r2 | dose_within_20_pct |
| --- | --- | --- | --- | --- | --- |
| Initial | 5528 | 12.2598 | 9.2063 | 0.3323 | 40.0000 |
| Update 1 | 5828 | 11.8181 | 8.9779 | 0.3796 | 42.6667 |
| Update 2 | 6128 | 12.1027 | 9.1702 | 0.3493 | 41.3333 |
| Update 3 | 6428 | 11.8783 | 9.0278 | 0.3732 | 43.6667 |

## Main Findings
- Dose model RMSE changed from `12.26` to `11.88` mg/week, while within-20% accuracy moved from `40.0%` to `43.7%`.
- The experiment simulates covariate shift by perturbing real training-cohort rows and is intended for continual-learning behavior analysis.

## Artifacts
- Metrics CSV: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_metrics.csv`
- Summary JSON: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_summary.json`
- Performance plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_performance.png`
- Shift plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_shift.png`
- Scatter plot: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/output/continual_update_scatter.png`
- Final dose model: `/home/karthick_js/Documents/programs/vitalink_ip_lab/ml_pipeline/warfarin_pipeline/evaluation/models/continual_dose_model_final.joblib`
