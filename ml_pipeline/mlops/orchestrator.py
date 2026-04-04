import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List

from monitoring import run_monitor
from logger_utils import get_logger


BASE_DIR = Path(__file__).resolve().parent.parent


def _load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def _save_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _rows(path: Path) -> int:
    if not path.exists():
        return 0
    try:
        import pandas as pd
        return int(len(pd.read_csv(path)))
    except Exception:
        return 0


def _run_commands(commands: List[List[str]], logger, cwd: Path) -> bool:
    for cmd in commands:
        logger.info("Running command: %s", " ".join(cmd))
        result = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
        if result.stdout:
            logger.info(result.stdout.strip())
        if result.returncode != 0:
            logger.error(result.stderr.strip())
            return False
    return True


def _hours_since(ts: str) -> float:
    if not ts:
        return 10_000.0
    then = datetime.fromisoformat(ts)
    now = datetime.now(timezone.utc)
    return (now - then).total_seconds() / 3600.0


def _monitor_if_possible(model_name: str, model_cfg: Dict, reports_dir: Path, logger) -> Dict:
    ref = BASE_DIR / model_cfg["reference_data"]
    cur = BASE_DIR / model_cfg["current_data"]
    report_file = reports_dir / f"{model_name}_monitor.json"

    if not ref.exists() or not cur.exists():
        return {
            "status": "missing_data",
            "max_psi": 0.0,
            "max_missing_rate": 0.0,
            "report_file": str(report_file),
        }

    report = run_monitor(ref, cur, report_file)
    logger.info("Monitoring report written: %s", report_file)
    report["report_file"] = str(report_file)
    return report


def run_cycle(config_path: Path, model_filter: str = "all", force: bool = False) -> Dict:
    config = _load_json(config_path, {})
    global_cfg = config.get("global", {})
    models_cfg = config.get("models", {})

    logs_dir = BASE_DIR / global_cfg.get("logs_dir", "mlops/logs")
    reports_dir = BASE_DIR / global_cfg.get("reports_dir", "mlops/reports")
    state_file = BASE_DIR / global_cfg.get("state_file", "mlops/state.json")
    logger = get_logger("mlops.orchestrator", str(logs_dir))

    state = _load_json(state_file, {"models": {}})
    summary = {"timestamp": datetime.now(timezone.utc).isoformat(), "models": {}}

    for model_name, model_cfg in models_cfg.items():
        if model_filter != "all" and model_name != model_filter:
            continue

        model_state = state["models"].get(model_name, {})
        last_run = model_state.get("last_retrain_at")
        prev_rows = int(model_state.get("last_row_count", 0))

        if model_cfg.get("prepare_commands"):
            _run_commands(model_cfg["prepare_commands"], logger, BASE_DIR)

        monitor = _monitor_if_possible(model_name, model_cfg, reports_dir, logger)
        current_rows = _rows(BASE_DIR / model_cfg["current_data"])
        new_rows = max(current_rows - prev_rows, 0)

        drift_flag = monitor.get("max_psi", 0.0) >= float(model_cfg.get("drift_threshold_psi", 0.2))
        quality_flag = monitor.get("max_missing_rate", 0.0) >= float(model_cfg.get("max_missing_rate", 0.2))
        interval_flag = _hours_since(last_run) >= float(model_cfg.get("min_retrain_interval_hours", 168))
        volume_flag = new_rows >= int(model_cfg.get("min_new_rows", 100))

        should_retrain = force or drift_flag or quality_flag or (interval_flag and volume_flag)
        retrain_ok = None
        if should_retrain:
            logger.info("Retraining triggered for %s", model_name)
            retrain_ok = _run_commands(model_cfg.get("retrain_commands", []), logger, BASE_DIR)
            if retrain_ok:
                model_state["last_retrain_at"] = datetime.now(timezone.utc).isoformat()
                model_state["last_row_count"] = current_rows

        state["models"][model_name] = model_state
        summary["models"][model_name] = {
            "new_rows": new_rows,
            "interval_flag": interval_flag,
            "volume_flag": volume_flag,
            "drift_flag": drift_flag,
            "quality_flag": quality_flag,
            "retrain_triggered": should_retrain,
            "retrain_ok": retrain_ok,
            "monitor_report": monitor,
        }

    _save_json(state_file, state)
    summary_file = reports_dir / "last_cycle_summary.json"
    _save_json(summary_file, summary)
    logger.info("Cycle summary written: %s", summary_file)
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Run one shared MLOps cycle")
    parser.add_argument("--config", type=Path, default=BASE_DIR / "mlops" / "config.json")
    parser.add_argument("--model", type=str, default="all", choices=["all", "warfarin", "acitrom"])
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    summary = run_cycle(args.config, model_filter=args.model, force=args.force)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
