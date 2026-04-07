PYTHON ?= .venv/bin/python
PIP ?= .venv/bin/pip

.PHONY: help install train-baseline train-models tune retrain visualize evaluate-continual predict mlops-once mlops-loop mlops-force clean

help:
	@echo "Available targets:"
	@echo "  install         Install Python dependencies"
	@echo "  train-baseline  Train baseline XGBoost model"
	@echo "  train-models    Train comparison models"
	@echo "  tune            Run model tuning"
	@echo "  retrain         Incrementally retrain baseline model"
	@echo "  visualize       Generate baseline visualization plots"
	@echo "  evaluate-continual Run dose continual-update evaluation"
	@echo "  predict         Run a sample prediction"
	@echo "  mlops-once      Run one shared MLOps cycle (warfarin + acitrom)"
	@echo "  mlops-loop      Run periodic shared MLOps scheduler loop"
	@echo "  mlops-force     Force retraining cycle for all models"
	@echo "  clean           Remove generated artifacts"

install:
	$(PIP) install -r requirements.txt

train-models:
	$(PYTHON) warfarin_pipeline/train_warfarin_models.py

retrain:
	$(PYTHON) warfarin_pipeline/retrain.py

visualize:
	$(PYTHON) warfarin_pipeline/evaluation/visualize.py

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
	rm -f warfarin_pipeline/models/warfarin_model.json warfarin_pipeline/models/warfarin_model_v2.json warfarin_pipeline/models/preprocessor.joblib
	rm -rf mlops/reports/*.json mlops/logs/*.log
