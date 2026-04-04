import argparse
import time
from pathlib import Path

from orchestrator import run_cycle


BASE_DIR = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser(description="Run periodic shared MLOps scheduler loop")
    parser.add_argument("--config", type=Path, default=BASE_DIR / "mlops" / "config.json")
    parser.add_argument("--model", type=str, default="all", choices=["all", "warfarin", "acitrom"])
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()

    config = args.config
    if args.once:
        run_cycle(config, model_filter=args.model, force=False)
        return

    import json
    cfg = json.loads(config.read_text(encoding="utf-8"))
    interval_minutes = int(cfg.get("global", {}).get("poll_interval_minutes", 30))

    while True:
        run_cycle(config, model_filter=args.model, force=False)
        time.sleep(interval_minutes * 60)


if __name__ == "__main__":
    main()
