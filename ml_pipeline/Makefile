ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
VENV_DIR ?= $(ROOT_DIR).venv

PYTHON ?= $(if $(wildcard $(VENV_DIR)/bin/python),$(VENV_DIR)/bin/python,python3)
PIP ?= $(if $(wildcard $(VENV_DIR)/bin/pip),$(VENV_DIR)/bin/pip,$(PYTHON) -m pip)

.PHONY: help venv install train-models retrain evaluate-continual predict mlops-once mlops-loop mlops-force clean

help:
	@echo "Available targets:"
	@echo "  venv            Create local Python virtual environment (.venv)"
	@echo "  install         Install Python dependencies"
	@echo "  train-models    Train comparison models"
	@echo "  retrain         Incrementally retrain baseline model"
	@echo "  evaluate-continual Run dose continual-update evaluation"
	@echo "  predict         Run a sample prediction"
	@echo "  mlops-once      Run one shared MLOps cycle (warfarin + acitrom)"
	@echo "  mlops-loop      Run periodic shared MLOps scheduler loop"
	@echo "  mlops-force     Force retraining cycle for all models"
	@echo "  clean           Remove generated artifacts"

venv:
	python3 -m venv .venv

install: venv
	$(PIP) install -r requirements.txt

train-models:
	$(PYTHON) warfarin_pipeline/train_warfarin_models.py

retrain:
	$(PYTHON) warfarin_pipeline/retrain.py

evaluate-continual:
	$(PYTHON) warfarin_pipeline/evaluation/evaluate_continual_updates.py

predict:
	$(PYTHON) warfarin_pipeline/predict_dose.py --age 4.5 --height 175 --weight 50 --race White --amiodarone 0 --enzyme_inducer 0 --cyp2c9 "*1/*1" --vkorc1 "GG"

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
