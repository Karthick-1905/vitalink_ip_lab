# Shared MLOps Stack (Warfarin + Acitrom)

## What this stack does

- Common periodic scheduling for both models.
- Drift + data quality checks on production datasets.
- Triggered retraining based on interval, new data volume, and drift/quality flags.
- Central logs and run reports for auditability.

## Software you need

### Core runtime
- Python 3.10+
- `pandas`, `numpy`, `scipy`, `scikit-learn`, `joblib`

### Scheduling
- Option A (already supported): Linux `cron` calling `python mlops/scheduler.py --once`
- Option B: long-running process `python mlops/scheduler.py`

### Storage and observability
- Local JSON + CSV (current implementation)
- Optional production upgrades:
  - Prometheus + Grafana for metrics
  - ELK/OpenSearch for searchable logs
  - Evidently for richer drift dashboards

## Real-world operating pattern

1. Collect inference data and eventual ground truth.
2. Run monitoring jobs on a fixed cadence.
3. Trigger retraining by policy (time + volume + quality/drift).
4. Validate new model against current champion.
5. Deploy canary/shadow, then promote.
6. Keep rollback artifact and full audit logs.

## Files in this folder

- `config.json`: retraining policy and commands for both models.
- `monitoring.py`: drift/data quality computation.
- `orchestrator.py`: single MLOps cycle.
- `scheduler.py`: periodic loop.
- `logger_utils.py`: shared rotating logs.
