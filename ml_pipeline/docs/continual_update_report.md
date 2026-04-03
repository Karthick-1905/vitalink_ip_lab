# Continual Update Evaluation Report

## Scope
This report evaluates a continual-update workflow in which dose and time-to-stability models are repeatedly retrained as new shifted patient batches arrive.

## Experimental Design
- Historical starting dataset: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/data/warfarin_cohort.csv`
- Incoming data: three shifted synthetic batches of 300 patients each
- Future evaluation cohort: one fixed shifted synthetic batch of 600 patients
- Update strategy: cumulative batch retraining from scratch after each incoming batch
- Model family: XGBoost with the repository preprocessing stack

## Round-by-Round Metrics

| round | train_size | dose_rmse | dose_mae | dose_r2 | dose_within_20_pct | stability_rmse | stability_mae | stability_r2 | stability_within_7_days_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Initial | 2500 | 17.9595 | 15.5460 | -1.6979 | 22.3333 | 11.4675 | 9.5769 | -1.1793 | 39.0000 |
| Update 1 | 2800 | 7.8012 | 6.0524 | 0.4909 | 74.1667 | 6.2159 | 4.8622 | 0.3597 | 74.3333 |
| Update 2 | 3100 | 6.8023 | 5.2872 | 0.6130 | 81.6667 | 6.1223 | 4.8542 | 0.3788 | 75.3333 |
| Update 3 | 3400 | 6.2852 | 4.8853 | 0.6696 | 85.6667 | 6.0645 | 4.8235 | 0.3905 | 75.5000 |

## Main Findings
- Dose model RMSE improved from `17.96` to `6.29` mg/week, while within-20% accuracy moved from `22.3%` to `85.7%`.
- Stability model RMSE improved from `11.47` to `6.06` days, while within-7-days accuracy moved from `39.0%` to `75.5%`.
- The experiment uses simulated covariate shift, so the interpretation is: continual retraining helps models adapt when the arriving patient mix differs from the original training cohort.

## Artifacts
- Metrics CSV: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_metrics.csv`
- Summary JSON: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_summary.json`
- Performance plot: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_performance.png`
- Shift plot: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_shift.png`
- Scatter plot: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/output/continual_update_scatter.png`
- Final dose model: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/models/continual_dose_model_final.joblib`
- Final stability model: `/home/surya/Projects/VitaLink_Karthi/ml_pipeline/models/continual_stability_model_final.joblib`
