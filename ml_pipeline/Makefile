PYTHON ?= .venv/bin/python
PIP ?= .venv/bin/pip

.PHONY: help install generate-data train-baseline train-models tune retrain train-time visualize compare-dose compare-stability evaluate-continual predict mlops-once mlops-loop mlops-force clean

help:
	@echo "Available targets:"
	@echo "  install         Install Python dependencies"
	@echo "  generate-data   Generate synthetic warfarin cohort"
	@echo "  train-baseline  Train baseline XGBoost model"
	@echo "  train-models    Train comparison models"
	@echo "  tune            Run model tuning"
	@echo "  retrain         Incrementally retrain baseline model"
	@echo "  train-time      Train time-to-stability model"
	@echo "  visualize       Generate baseline visualization plots"
	@echo "  compare-dose    Run warfarin dose model comparison evaluation"
	@echo "  compare-stability Run time-to-stability comparison evaluation"
	@echo "  evaluate-continual Run continual-update evaluation"
	@echo "  predict         Run a sample prediction"
	@echo "  mlops-once      Run one shared MLOps cycle (warfarin + acitrom)"
	@echo "  mlops-loop      Run periodic shared MLOps scheduler loop"
	@echo "  mlops-force     Force retraining cycle for all models"
	@echo "  clean           Remove generated artifacts"

install:
	$(PIP) install -r requirements.txt

generate-data:
	$(PYTHON) warfarin_pipeline/data_generator.py

train-baseline:
	$(PYTHON) warfarin_pipeline/train_baseline.py

train-models:
	$(PYTHON) warfarin_pipeline/train_warfarin_models.py

tune:
	$(PYTHON) warfarin_pipeline/tune_warfarin_models.py

retrain:
	$(PYTHON) warfarin_pipeline/retrain.py

train-time:
	$(PYTHON) warfarin_pipeline/time_to_stability_model.py

visualize:
	$(PYTHON) warfarin_pipeline/evaluation/visualize.py

compare-dose:
	$(PYTHON) warfarin_pipeline/evaluation/compare_warfarin_models.py

compare-stability:
	$(PYTHON) warfarin_pipeline/evaluation/compare_time_to_stability_models.py

evaluate-continual:
	$(PYTHON) warfarin_pipeline/evaluation/evaluate_continual_updates.py

predict:
	$(PYTHON) warfarin_pipeline/predict_dose.py --age 6.5 --height 170 --weight 75 --race White --amiodarone 0 --enzyme_inducer 0 --cyp2c9 "*1/*1" --vkorc1 "GG"

mlops-once:
	$(PYTHON) mlops/scheduler.py --once

mlops-loop:
	$(PYTHON) mlops/scheduler.py

mlops-force:
	$(PYTHON) mlops/orchestrator.py --force

clean:
	rm -rf warfarin_pipeline/output/*.png
	rm -rf warfarin_pipeline/evaluation/output/*.png
	rm -rf warfarin_pipeline/evaluation/output/*.csv
	rm -rf warfarin_pipeline/evaluation/output/*.json
	rm -rf warfarin_pipeline/evaluation/docs/*.md
	rm -rf warfarin_pipeline/evaluation/models/*.joblib
	rm -f warfarin_pipeline/data/y_test_baseline.npy warfarin_pipeline/data/y_pred_baseline.npy warfarin_pipeline/data/feature_importances.csv
	rm -f warfarin_pipeline/models/warfarin_model.json warfarin_pipeline/models/warfarin_model_v2.json warfarin_pipeline/models/preprocessor.joblib warfarin_pipeline/models/time_to_stable_model.json warfarin_pipeline/models/time_to_stable_preprocessor.joblib
	rm -rf mlops/reports/*.json mlops/logs/*.log
