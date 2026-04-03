import html
import json
from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "output"
DOCS_DIR = BASE_DIR / "docs"

DOSE_METRICS = pd.read_csv(OUTPUT_DIR / "iwpc_model_metrics.csv")
DOSE_SHAP = pd.read_csv(OUTPUT_DIR / "iwpc_shap_top_features.csv")
STABILITY_METRICS = pd.read_csv(OUTPUT_DIR / "stability_model_metrics.csv")
STABILITY_SHAP = pd.read_csv(OUTPUT_DIR / "stability_shap_top_features.csv")
UPDATE_METRICS = pd.read_csv(OUTPUT_DIR / "continual_update_metrics.csv")

HTML_PATH = DOCS_DIR / "warfarin_program_slides.html"


def metrics_table(df: pd.DataFrame, columns: list[str], float_columns: set[str]) -> str:
    headers = "".join(f"<th>{html.escape(col.replace('_', ' '))}</th>" for col in columns)
    rows = []
    for _, row in df[columns].iterrows():
        tds = []
        for col in columns:
            value = row[col]
            if col in float_columns:
                tds.append(f"<td>{value:.4f}</td>")
            else:
                tds.append(f"<td>{html.escape(str(value))}</td>")
        rows.append("<tr>" + "".join(tds) + "</tr>")
    return f"<table><thead><tr>{headers}</tr></thead><tbody>{''.join(rows)}</tbody></table>"


def feature_list(df: pd.DataFrame, n: int = 6) -> str:
    items = []
    for row in df.head(n).itertuples(index=False):
        items.append(
            f"""
            <div class="feature-row">
              <span>{html.escape(str(row.feature).replace('_', ' '))}</span>
              <strong>{row.mean_abs_shap:.3f}</strong>
            </div>
            """
        )
    return "".join(items)


def slide(label: str, title: str, body: str, page_num: int, footer: str) -> str:
    return f"""
    <section class="page">
      <div class="slide">
        <div class="header">
          <div class="eyebrow">{html.escape(label)}</div>
          <div class="title">{html.escape(title)}</div>
        </div>
        <div class="body">{body}</div>
        <div class="footer">
          <span>{html.escape(footer)}</span>
          <span>{page_num:02d}</span>
        </div>
      </div>
    </section>
    """


def build_html() -> str:
    dose_best = DOSE_METRICS.iloc[0]
    dose_iwpc = DOSE_METRICS.loc[DOSE_METRICS["model"] == "IWPC Pharmacogenetic Calculator"].iloc[0]
    stability_best = STABILITY_METRICS.iloc[0]
    update_initial = UPDATE_METRICS.iloc[0]
    update_final = UPDATE_METRICS.iloc[-1]

    slides = []

    slides.append(
        slide(
            "Warfarin Modeling Program",
            "Dose prediction, time-to-stability prediction, and continual model updates",
            f"""
            <div class="hero-grid">
              <div class="hero-copy">
                <p class="lead">This deck consolidates the full workstream: benchmarking dose prediction against the IWPC calculator, building a time-to-stability model, and evaluating continual retraining on new shifted data.</p>
                <div class="pillar-grid">
                  <div class="pillar"><span>01</span><h3>Dosage Prediction</h3><p>Best model edges the IWPC pharmacogenetic calculator on RMSE while keeping clinically plausible drivers.</p></div>
                  <div class="pillar"><span>02</span><h3>Time to Stability</h3><p>Current synthetic target behaves nearly linearly, so simpler models remain competitive.</p></div>
                  <div class="pillar"><span>03</span><h3>Continual Updates</h3><p>Retraining on shifted incoming batches materially recovers performance on future cohorts.</p></div>
                </div>
              </div>
              <div class="hero-metrics panel">
                <div class="metric-kicker">Best dose model</div>
                <div class="metric-headline">{html.escape(str(dose_best['model']))}</div>
                <div class="metric-stat"><span>RMSE</span><strong>{dose_best['rmse']:.2f}</strong></div>
                <div class="metric-stat"><span>Stability RMSE</span><strong>{stability_best['rmse']:.2f} days</strong></div>
                <div class="metric-stat"><span>Dose adaptation</span><strong>{update_initial['dose_rmse']:.1f} → {update_final['dose_rmse']:.1f}</strong></div>
              </div>
            </div>
            """,
            1,
            "Combined summary for all three requested tasks",
        )
    )

    slides.append(
        slide(
            "Dose Prediction",
            "Dose benchmarking against IWPC and baseline machine-learning models",
            f"""
            <div class="two-col">
              <div class="stack">
                <div class="panel summary-panel">
                  <div class="summary-title">Top finding</div>
                  <div class="summary-big">{html.escape(str(dose_best['model']))}</div>
                  <p>RMSE <strong>{dose_best['rmse']:.2f}</strong> mg/week, MAE <strong>{dose_best['mae']:.2f}</strong>, R² <strong>{dose_best['r2']:.3f}</strong>.</p>
                  <p>IWPC PGx comparator: RMSE <strong>{dose_iwpc['rmse']:.2f}</strong>, MAE <strong>{dose_iwpc['mae']:.2f}</strong>.</p>
                </div>
                <div class="panel feature-panel">
                  <div class="summary-title">Top SHAP features</div>
                  {feature_list(DOSE_SHAP)}
                </div>
              </div>
              <div class="panel table-panel">
                {metrics_table(DOSE_METRICS, ["rank", "model", "rmse", "mae", "r2", "within_20_pct"], {"rmse", "mae", "r2", "within_20_pct"})}
              </div>
            </div>
            """,
            2,
            "Dose prediction on the IWPC cohort",
        )
    )

    slides.append(
        slide(
            "Dose Visuals",
            "Leaderboard and fit diagnostics stay tightly clustered at the top",
            """
            <div class="viz-grid">
              <div class="panel image-panel tall">
                <img src="../output/iwpc_model_comparison.png" alt="Dose model comparison" />
              </div>
              <div class="panel image-panel tall">
                <img src="../output/iwpc_prediction_scatter.png" alt="Dose prediction scatter" />
              </div>
            </div>
            """,
            3,
            "Dose comparison and patient-level fit",
        )
    )

    slides.append(
        slide(
            "Time to Stability",
            "The synthetic stability target is comparatively linear",
            f"""
            <div class="two-col">
              <div class="stack">
                <div class="panel summary-panel">
                  <div class="summary-title">Best model</div>
                  <div class="summary-big">{html.escape(str(stability_best['model']))}</div>
                  <p>RMSE <strong>{stability_best['rmse']:.2f}</strong> days, MAE <strong>{stability_best['mae']:.2f}</strong>, within 7 days <strong>{stability_best['within_7_days_pct']:.1f}%</strong>.</p>
                  <p>The top four models are separated by only about 0.06 RMSE days, so there is no strong case for extra complexity on this synthetic target.</p>
                </div>
                <div class="panel feature-panel">
                  <div class="summary-title">Top SHAP features</div>
                  {feature_list(STABILITY_SHAP)}
                </div>
              </div>
              <div class="panel table-panel">
                {metrics_table(STABILITY_METRICS, ["rank", "model", "rmse", "mae", "r2", "within_7_days_pct"], {"rmse", "mae", "r2", "within_7_days_pct"})}
              </div>
            </div>
            """,
            4,
            "Time-to-stability comparison on the synthetic cohort",
        )
    )

    slides.append(
        slide(
            "Stability Visuals",
            "Scatter fit and SHAP views support a simpler operational model",
            """
            <div class="three-grid">
              <div class="panel image-panel">
                <img src="../output/stability_model_comparison.png" alt="Stability comparison" />
              </div>
              <div class="panel image-panel">
                <img src="../output/stability_prediction_scatter.png" alt="Stability scatter" />
              </div>
              <div class="panel image-panel">
                <img src="../output/stability_shap_bar.png" alt="Stability shap bar" />
              </div>
            </div>
            """,
            5,
            "Stability leaderboard, fit, and explainability",
        )
    )

    slides.append(
        slide(
            "Continual Updates",
            "Sequential retraining on shifted incoming cohorts materially restores performance",
            f"""
            <div class="two-col">
              <div class="panel summary-panel">
                <div class="summary-title">Dose adaptation</div>
                <p>RMSE: <strong>{update_initial['dose_rmse']:.2f}</strong> → <strong>{update_final['dose_rmse']:.2f}</strong></p>
                <p>Within 20%: <strong>{update_initial['dose_within_20_pct']:.1f}%</strong> → <strong>{update_final['dose_within_20_pct']:.1f}%</strong></p>
                <div class="summary-title" style="margin-top:18px;">Stability adaptation</div>
                <p>RMSE: <strong>{update_initial['stability_rmse']:.2f}</strong> → <strong>{update_final['stability_rmse']:.2f}</strong></p>
                <p>Within 7 days: <strong>{update_initial['stability_within_7_days_pct']:.1f}%</strong> → <strong>{update_final['stability_within_7_days_pct']:.1f}%</strong></p>
                <p class="small-note">Experiment design: historical training cohort plus three shifted incoming batches, all measured on one fixed shifted future test cohort.</p>
              </div>
              <div class="panel table-panel">
                {metrics_table(UPDATE_METRICS, ["round", "train_size", "dose_rmse", "dose_within_20_pct", "stability_rmse", "stability_within_7_days_pct"], {"dose_rmse", "dose_within_20_pct", "stability_rmse", "stability_within_7_days_pct"})}
              </div>
            </div>
            """,
            6,
            "Continual-update experiment on shifted incoming data",
        )
    )

    slides.append(
        slide(
            "Update Visuals",
            "The first update batch delivers the largest recovery, with smaller gains after that",
            """
            <div class="three-grid">
              <div class="panel image-panel">
                <img src="../output/continual_update_performance.png" alt="Continual performance" />
              </div>
              <div class="panel image-panel">
                <img src="../output/continual_update_shift.png" alt="Continual shift" />
              </div>
              <div class="panel image-panel">
                <img src="../output/continual_update_scatter.png" alt="Continual scatter" />
              </div>
            </div>
            """,
            7,
            "Performance recovery, cohort shift, and pre/post fit",
        )
    )

    slides.append(
        slide(
            "Recommendations",
            "What to use, what to keep simple, and what to operationalize",
            """
            <div class="recommend-grid">
              <div class="panel rec-panel">
                <h3>Deploy for Dose</h3>
                <p>Use the tuned LightGBM dose model when the objective is best predictive accuracy against IWPC-style baselines.</p>
              </div>
              <div class="panel rec-panel">
                <h3>Keep Stability Simple</h3>
                <p>Use the linear stability model unless a richer real-world target is available; current synthetic behavior does not justify a more complex learner.</p>
              </div>
              <div class="panel rec-panel">
                <h3>Operational Retraining</h3>
                <p>Schedule cumulative retraining when incoming patients diverge from the original cohort. The simulated shift study shows large accuracy recovery after updates.</p>
              </div>
            </div>
            <div class="artifact-strip panel">
              <div><span>Master report</span><strong>docs/warfarin_full_program_report.md</strong></div>
              <div><span>HTML deck</span><strong>docs/warfarin_program_slides.html</strong></div>
              <div><span>PDF deck</span><strong>docs/warfarin_program_slides.pdf</strong></div>
              <div><span>PPT deck</span><strong>docs/warfarin_program_slides.pptx</strong></div>
            </div>
            """,
            8,
            "Final recommendations and artifact map",
        )
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Warfarin Program Slides</title>
  <style>
    :root {{
      --paper: #f3ecdf;
      --ink: #1f1b16;
      --muted: #5c564f;
      --edge: rgba(31, 27, 22, 0.14);
      --panel: rgba(255, 251, 245, 0.92);
      --accent: #9b4d2e;
      --accent-2: #3f5a4e;
      --accent-3: #b38a3c;
    }}
    * {{ box-sizing: border-box; }}
    html, body {{
      margin: 0;
      padding: 0;
      background:
        radial-gradient(circle at top left, rgba(179,138,60,0.18), transparent 30%),
        linear-gradient(180deg, #f6efe5 0%, #eee5d6 100%);
      color: var(--ink);
      font-family: Georgia, "Palatino Linotype", "Book Antiqua", serif;
    }}
    .page {{
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 24px 0;
      page-break-after: always;
    }}
    .slide {{
      width: 13.333in;
      height: 7.5in;
      background: linear-gradient(180deg, rgba(255,251,245,0.88), rgba(247,240,230,0.92));
      border: 1px solid var(--edge);
      box-shadow: 0 24px 60px rgba(56, 40, 20, 0.10);
      padding: 0.42in 0.5in 0.36in 0.5in;
      display: grid;
      grid-template-rows: auto 1fr auto;
      gap: 0.18in;
      position: relative;
      overflow: hidden;
    }}
    .slide::before {{
      content: "";
      position: absolute;
      inset: 14px;
      border: 1px solid rgba(31,27,22,0.10);
      pointer-events: none;
    }}
    .header {{
      z-index: 1;
    }}
    .eyebrow {{
      font: 600 10pt/1.2 "Trebuchet MS", "Gill Sans", sans-serif;
      letter-spacing: 0.22em;
      text-transform: uppercase;
      color: var(--accent);
      margin-bottom: 0.08in;
    }}
    .title {{
      font-size: 23pt;
      line-height: 1.06;
      font-weight: 700;
      max-width: 11.6in;
    }}
    .body {{
      min-height: 0;
      display: flex;
      flex-direction: column;
      justify-content: stretch;
      gap: 0.16in;
      z-index: 1;
    }}
    .footer {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      color: var(--muted);
      font: 10pt/1.2 "Trebuchet MS", "Gill Sans", sans-serif;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      z-index: 1;
    }}
    .panel {{
      background: var(--panel);
      border: 1px solid var(--edge);
      border-radius: 16px;
      box-shadow: 0 12px 28px rgba(56, 40, 20, 0.06);
      padding: 0.18in;
      min-height: 0;
    }}
    .hero-grid {{
      display: grid;
      grid-template-columns: 2fr 1fr;
      gap: 0.18in;
      height: 100%;
    }}
    .lead {{
      font-size: 15pt;
      line-height: 1.55;
      max-width: 7.6in;
      margin: 0 0 0.2in 0;
      color: var(--muted);
    }}
    .pillar-grid {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 0.14in;
    }}
    .pillar {{
      background: rgba(255, 248, 238, 0.96);
      border: 1px solid var(--edge);
      border-radius: 14px;
      padding: 0.16in;
      min-height: 2.2in;
    }}
    .pillar span {{
      font: 600 9pt/1 "Trebuchet MS", sans-serif;
      letter-spacing: 0.18em;
      color: var(--accent);
    }}
    .pillar h3 {{
      margin: 0.12in 0 0.08in 0;
      font-size: 15pt;
    }}
    .pillar p {{
      margin: 0;
      color: var(--muted);
      font-size: 11.5pt;
      line-height: 1.45;
    }}
    .hero-metrics {{
      display: flex;
      flex-direction: column;
      justify-content: center;
      gap: 0.14in;
    }}
    .metric-kicker {{
      font: 600 10pt/1.2 "Trebuchet MS", sans-serif;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      color: var(--accent);
    }}
    .metric-headline {{
      font-size: 26pt;
      line-height: 1.02;
      color: var(--accent-2);
      font-weight: 700;
    }}
    .metric-stat {{
      border-top: 1px solid var(--edge);
      padding-top: 0.11in;
    }}
    .metric-stat span {{
      display: block;
      font: 600 9pt/1.2 "Trebuchet MS", sans-serif;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      color: var(--muted);
    }}
    .metric-stat strong {{
      display: block;
      margin-top: 0.03in;
      font-size: 19pt;
      color: var(--accent-2);
    }}
    .two-col {{
      display: grid;
      grid-template-columns: 3.7in 1fr;
      gap: 0.18in;
      height: 100%;
      min-height: 0;
    }}
    .stack {{
      display: grid;
      grid-template-rows: 1fr 1fr;
      gap: 0.18in;
      min-height: 0;
    }}
    .summary-title {{
      font: 600 10pt/1.2 "Trebuchet MS", sans-serif;
      text-transform: uppercase;
      letter-spacing: 0.14em;
      color: var(--accent);
      margin-bottom: 0.08in;
    }}
    .summary-big {{
      font-size: 21pt;
      line-height: 1.04;
      color: var(--accent-2);
      font-weight: 700;
      margin-bottom: 0.12in;
    }}
    .summary-panel p, .small-note {{
      margin: 0 0 0.1in 0;
      font-size: 11.5pt;
      line-height: 1.48;
      color: var(--muted);
    }}
    .feature-panel {{
      display: flex;
      flex-direction: column;
      gap: 0.05in;
    }}
    .feature-row {{
      display: flex;
      justify-content: space-between;
      gap: 0.12in;
      padding: 0.08in 0;
      border-bottom: 1px solid var(--edge);
      font-size: 11pt;
    }}
    .feature-row strong {{
      color: var(--accent-2);
    }}
    .table-panel {{
      overflow: hidden;
      display: flex;
      align-items: stretch;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 10pt;
      table-layout: fixed;
    }}
    th, td {{
      padding: 0.07in 0.08in;
      border-bottom: 1px solid var(--edge);
      text-align: left;
      vertical-align: top;
      word-wrap: break-word;
    }}
    th {{
      background: rgba(179, 138, 60, 0.12);
      font: 600 8.5pt/1.2 "Trebuchet MS", sans-serif;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--ink);
    }}
    .viz-grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.18in;
      height: 100%;
      min-height: 0;
    }}
    .three-grid {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 0.18in;
      height: 100%;
      min-height: 0;
    }}
    .image-panel {{
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 0;
      overflow: hidden;
    }}
    .image-panel img {{
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
    }}
    .tall {{
      height: 100%;
    }}
    .recommend-grid {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 0.18in;
      margin-bottom: 0.18in;
    }}
    .rec-panel h3 {{
      margin: 0 0 0.08in 0;
      font-size: 15pt;
      color: var(--accent-2);
    }}
    .rec-panel p {{
      margin: 0;
      font-size: 11.5pt;
      line-height: 1.5;
      color: var(--muted);
    }}
    .artifact-strip {{
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 0.12in;
      align-items: start;
    }}
    .artifact-strip div {{
      border-top: 1px solid var(--edge);
      padding-top: 0.1in;
    }}
    .artifact-strip span {{
      display: block;
      font: 600 8.5pt/1.2 "Trebuchet MS", sans-serif;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
    }}
    .artifact-strip strong {{
      display: block;
      margin-top: 0.05in;
      font-size: 10.5pt;
      line-height: 1.35;
      color: var(--ink);
      word-break: break-word;
    }}
    @page {{
      size: 13.333in 7.5in;
      margin: 0;
    }}
    @media print {{
      html, body {{
        background: none;
      }}
      .page {{
        padding: 0;
      }}
      .slide {{
        box-shadow: none;
        border: none;
      }}
    }}
  </style>
</head>
<body>
  {''.join(slides)}
</body>
</html>
"""


def main():
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    HTML_PATH.write_text(build_html(), encoding="utf-8")
    print(f"Wrote {HTML_PATH}")


if __name__ == "__main__":
    main()
