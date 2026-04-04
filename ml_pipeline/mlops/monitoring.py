import argparse
import json
from pathlib import Path
from typing import Dict, List

import numpy as np
import pandas as pd
from scipy.stats import ks_2samp


def _psi(expected: pd.Series, actual: pd.Series, buckets: int = 10) -> float:
    expected = pd.to_numeric(expected, errors="coerce").dropna()
    actual = pd.to_numeric(actual, errors="coerce").dropna()
    if expected.empty or actual.empty:
        return 0.0

    quantiles = np.linspace(0, 1, buckets + 1)
    breaks = np.unique(np.quantile(expected, quantiles))
    if len(breaks) < 3:
        return 0.0

    expected_counts, _ = np.histogram(expected, bins=breaks)
    actual_counts, _ = np.histogram(actual, bins=breaks)

    expected_ratio = np.where(expected_counts == 0, 1e-6, expected_counts / expected_counts.sum())
    actual_ratio = np.where(actual_counts == 0, 1e-6, actual_counts / actual_counts.sum())
    return float(np.sum((actual_ratio - expected_ratio) * np.log(actual_ratio / expected_ratio)))


def _numeric_columns(df: pd.DataFrame) -> List[str]:
    return [c for c in df.columns if pd.api.types.is_numeric_dtype(df[c])]


def compute_monitor_report(reference_df: pd.DataFrame, current_df: pd.DataFrame) -> Dict:
    common_cols = [c for c in reference_df.columns if c in current_df.columns]
    if not common_cols:
        return {
            "status": "no_common_columns",
            "max_psi": 0.0,
            "max_missing_rate": 0.0,
            "feature_reports": {},
        }

    feature_reports = {}
    max_psi = 0.0
    max_missing = 0.0

    ref = reference_df[common_cols].copy()
    cur = current_df[common_cols].copy()

    for col in common_cols:
        missing_rate = float(cur[col].isna().mean())
        max_missing = max(max_missing, missing_rate)

        report = {
            "missing_rate": missing_rate,
            "psi": 0.0,
            "ks_pvalue": None,
        }

        if pd.api.types.is_numeric_dtype(ref[col]) and pd.api.types.is_numeric_dtype(cur[col]):
            psi = _psi(ref[col], cur[col])
            report["psi"] = psi
            max_psi = max(max_psi, psi)

            ref_vals = pd.to_numeric(ref[col], errors="coerce").dropna()
            cur_vals = pd.to_numeric(cur[col], errors="coerce").dropna()
            if not ref_vals.empty and not cur_vals.empty:
                report["ks_pvalue"] = float(ks_2samp(ref_vals, cur_vals).pvalue)

        feature_reports[col] = report

    return {
        "status": "ok",
        "rows_reference": int(len(reference_df)),
        "rows_current": int(len(current_df)),
        "max_psi": float(max_psi),
        "max_missing_rate": float(max_missing),
        "feature_reports": feature_reports,
    }


def run_monitor(reference_path: Path, current_path: Path, report_path: Path) -> Dict:
    reference_df = pd.read_csv(reference_path)
    current_df = pd.read_csv(current_path)
    report = compute_monitor_report(reference_df, current_df)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Run drift/data-quality monitoring for tabular datasets")
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    report = run_monitor(args.reference, args.current, args.report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
