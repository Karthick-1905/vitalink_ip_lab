#!/usr/bin/env python3
from __future__ import annotations

import html
import json
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = ROOT / "docs" / "test-results"
BACKEND_TESTS = ROOT / "backend" / "tests"
FRONTEND_TESTS = ROOT / "frontend" / "test"
OUTPUT_HTML = RESULTS_DIR / "visual-test-report.html"


@dataclass
class SuiteCard:
    section: str
    title: str
    source: Path
    total_tests: int
    status: str
    subtitle: str


def count_tests(path: Path) -> int:
    text = path.read_text()
    if path.suffix == ".dart":
        return len(re.findall(r"\btest(?:Widgets)?\(", text))
    return len(re.findall(r"\btest\(", text))


def latest_file(pattern: str) -> Path | None:
    files = sorted(RESULTS_DIR.glob(pattern))
    return files[-1] if files else None


def parse_summary_statuses() -> dict[str, str]:
    summary = latest_file("test-summary-*.md")
    statuses = {"frontend": "NOT RUN", "backend": "NOT RUN"}
    if not summary:
        return statuses

    text = summary.read_text()
    frontend_match = re.search(r"Frontend status: \*\*(.+?)\*\*", text)
    backend_match = re.search(r"Backend status: \*\*(.+?)\*\*", text)
    if frontend_match:
        statuses["frontend"] = frontend_match.group(1).strip()
    if backend_match:
        statuses["backend"] = backend_match.group(1).strip()
    return statuses


def build_cards() -> list[SuiteCard]:
    statuses = parse_summary_statuses()

    backend_cards = [
        SuiteCard(
            section="Backend API Testing",
            title="Authentication Routes",
            source=BACKEND_TESTS / "authcontroller.test.ts",
            total_tests=count_tests(BACKEND_TESTS / "authcontroller.test.ts"),
            status=statuses["backend"],
            subtitle="login, logout, session profile",
        ),
        SuiteCard(
            section="Backend API Testing",
            title="Patient Routes",
            source=BACKEND_TESTS / "patientcontroller.test.ts",
            total_tests=count_tests(BACKEND_TESTS / "patientcontroller.test.ts"),
            status=statuses["backend"],
            subtitle="profile, dosage, missed doses, health logs, notifications, calendar",
        ),
        SuiteCard(
            section="Backend API Testing",
            title="Patient File Upload Routes",
            source=BACKEND_TESTS / "patient_file_upload.test.ts",
            total_tests=count_tests(BACKEND_TESTS / "patient_file_upload.test.ts"),
            status=statuses["backend"],
            subtitle="INR report upload, profile picture upload, S3/Filebase integration",
        ),
        SuiteCard(
            section="Backend API Testing",
            title="Doctor Routes",
            source=BACKEND_TESTS / "doctorcontroller.test.ts",
            total_tests=count_tests(BACKEND_TESTS / "doctorcontroller.test.ts"),
            status=statuses["backend"],
            subtitle="patient management, reports, notifications, reassignment, file access",
        ),
        SuiteCard(
            section="Backend API Testing",
            title="Admin Routes",
            source=BACKEND_TESTS / "admincontroller.test.ts",
            total_tests=count_tests(BACKEND_TESTS / "admincontroller.test.ts"),
            status=statuses["backend"],
            subtitle="doctor/patient administration, password reset, system health",
        ),
        SuiteCard(
            section="Backend API Testing",
            title="Statistics Routes",
            source=BACKEND_TESTS / "statisticscontroller.test.ts",
            total_tests=count_tests(BACKEND_TESTS / "statisticscontroller.test.ts"),
            status=statuses["backend"],
            subtitle="dashboard metrics, trends, compliance, workload, period stats",
        ),
    ]

    frontend_cards = [
        SuiteCard(
            section="Frontend Testing",
            title="Patient Dashboard Shell Logic",
            source=FRONTEND_TESTS / "features" / "patient" / "patient_dashboard_shell_page_test.dart",
            total_tests=count_tests(FRONTEND_TESTS / "features" / "patient" / "patient_dashboard_shell_page_test.dart"),
            status=statuses["frontend"],
            subtitle="unread doctor update popup rules and system announcement popup rules",
        ),
        SuiteCard(
            section="Frontend Testing",
            title="Application Bootstrap Widget",
            source=FRONTEND_TESTS / "widget_test.dart",
            total_tests=count_tests(FRONTEND_TESTS / "widget_test.dart"),
            status=statuses["frontend"],
            subtitle="basic app mount / load verification",
        ),
    ]

    return backend_cards + frontend_cards


def status_class(status: str) -> str:
    status = status.upper()
    if status == "PASS":
        return "pass"
    if status == "FAIL":
        return "fail"
    return "neutral"


def render_card(card: SuiteCard) -> str:
    items = [
        "Automated test suite discovered successfully",
        f"Assertions defined: {card.total_tests}",
        f"Source file: {card.source.relative_to(ROOT)}",
        f"Coverage focus: {card.subtitle}",
    ]

    if card.status.upper() == "PASS":
        items.insert(1, "Execution completed with passing status")
    elif card.status.upper() == "FAIL":
        items.insert(1, "Execution did not complete with a clean pass status")
    else:
        items.insert(1, "Execution evidence not available yet")

    lis = "\n".join(
        f"<li><span class='tick {status_class(card.status)}'></span>{html.escape(item)}</li>"
        for item in items
    )

    return f"""
    <section class="suite-card">
      <div class="suite-head">
        <div>
          <div class="suite-tag">{html.escape(card.section)}</div>
          <h3>{html.escape(card.title)}</h3>
          <p>{html.escape(card.subtitle)}</p>
        </div>
        <div class="status-pill {status_class(card.status)}">{html.escape(card.status.upper())}</div>
      </div>
      <div class="evidence-box">
        <div class="evidence-meta">
          <span>Assertions: {card.total_tests}</span>
          <span>{html.escape(str(card.source.relative_to(ROOT)))}</span>
        </div>
        <ul class="result-list">
          {lis}
        </ul>
      </div>
    </section>
    """


def main() -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    cards = build_cards()

    sections: dict[str, list[SuiteCard]] = {}
    for card in cards:
        sections.setdefault(card.section, []).append(card)

    latest_summary = latest_file("test-summary-*.md")
    generated_from = latest_summary.name if latest_summary else "no summary found yet"

    backend_total = sum(card.total_tests for card in cards if card.section == "Backend API Testing")
    frontend_total = sum(card.total_tests for card in cards if card.section == "Frontend Testing")

    rendered_sections = []
    figure_no = 14
    for section_name, section_cards in sections.items():
        section_html = [f"<div class='section-title'>{html.escape(section_name)}</div>"]
        for card in section_cards:
            section_html.append(render_card(card))
            section_html.append(
                f"<div class='figure-caption'>Figure {figure_no}: Test evidence for {html.escape(card.title.lower())}</div>"
            )
            figure_no += 1
        rendered_sections.append("\n".join(section_html))

    html_text = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>VitaLink Test Evidence Report</title>
  <style>
    :root {{
      --bg: #262321;
      --panel: #312d2a;
      --ink: #f7f4ef;
      --muted: #c4bbae;
      --line: #49413c;
      --paper: #fbfaf7;
      --ok: #2e9d63;
      --bad: #c54a4a;
      --neutral: #a98e50;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.04), transparent 140px),
        var(--bg);
      color: var(--ink);
    }}
    .page {{
      max-width: 1280px;
      margin: 0 auto;
      padding: 42px 28px 80px;
    }}
    .report-frame {{
      border: 1px solid var(--line);
      background: rgba(0,0,0,0.05);
      padding: 28px 22px 36px;
      box-shadow: inset 0 0 0 1px rgba(255,255,255,0.03);
    }}
    h1 {{
      margin: 0 0 8px;
      font-size: 34px;
      letter-spacing: 0.02em;
    }}
    .lead {{
      margin: 0 0 24px;
      color: var(--muted);
      font-size: 16px;
      line-height: 1.55;
      max-width: 920px;
    }}
    .summary-grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
      margin-bottom: 26px;
    }}
    .summary-card {{
      border: 1px solid var(--line);
      background: var(--panel);
      padding: 16px 18px;
    }}
    .summary-card strong {{
      display: block;
      font-size: 26px;
      margin-top: 6px;
    }}
    .summary-card span {{
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }}
    .section-title {{
      margin: 34px 0 14px;
      font-size: 18px;
      font-weight: 700;
      border-bottom: 1px solid var(--line);
      padding-bottom: 10px;
    }}
    .suite-card {{
      margin: 0 0 10px;
      padding: 0;
      border: 1px solid var(--line);
      background: rgba(255,255,255,0.015);
    }}
    .suite-head {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      padding: 18px 18px 12px;
    }}
    .suite-tag {{
      color: var(--muted);
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      margin-bottom: 6px;
    }}
    .suite-head h3 {{
      margin: 0;
      font-size: 26px;
      color: var(--ink);
    }}
    .suite-head p {{
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 14px;
    }}
    .status-pill {{
      white-space: nowrap;
      border: 1px solid currentColor;
      border-radius: 999px;
      padding: 6px 12px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
      margin-top: 4px;
    }}
    .status-pill.pass {{ color: var(--ok); }}
    .status-pill.fail {{ color: var(--bad); }}
    .status-pill.neutral {{ color: var(--neutral); }}
    .evidence-box {{
      margin: 0 14px 14px;
      background: var(--paper);
      color: #222;
      border: 1px solid #d9d2c6;
      min-height: 180px;
      padding: 16px 18px 14px;
    }}
    .evidence-meta {{
      display: flex;
      justify-content: space-between;
      gap: 12px;
      color: #6d655c;
      font-size: 12px;
      margin-bottom: 12px;
    }}
    .result-list {{
      list-style: none;
      padding: 0;
      margin: 0;
      display: grid;
      gap: 9px;
    }}
    .result-list li {{
      display: flex;
      align-items: flex-start;
      gap: 10px;
      font-family: "Trebuchet MS", Arial, sans-serif;
      font-size: 14px;
      line-height: 1.35;
      color: #3a342d;
    }}
    .tick {{
      width: 14px;
      height: 14px;
      margin-top: 2px;
      border-radius: 999px;
      flex: 0 0 auto;
      border: 1px solid transparent;
    }}
    .tick.pass {{ background: rgba(46,157,99,0.18); border-color: var(--ok); }}
    .tick.fail {{ background: rgba(197,74,74,0.16); border-color: var(--bad); }}
    .tick.neutral {{ background: rgba(169,142,80,0.18); border-color: var(--neutral); }}
    .figure-caption {{
      text-align: center;
      color: #151515;
      background: rgba(255,255,255,0.02);
      padding: 8px 12px 18px;
      margin: 0 0 8px;
      font-size: 16px;
      font-weight: 700;
    }}
    .footer-note {{
      margin-top: 30px;
      color: var(--muted);
      font-size: 14px;
      line-height: 1.55;
    }}
    @media (max-width: 900px) {{
      .summary-grid {{ grid-template-columns: 1fr; }}
      .suite-head {{ flex-direction: column; }}
      .evidence-meta {{ flex-direction: column; }}
    }}
  </style>
</head>
<body>
  <main class="page">
    <div class="report-frame">
      <h1>5.3 Application Functionality Testing</h1>
      <p class="lead">
        Visual test evidence report for VitaLink. This page is designed to be opened in a browser and captured as documentation imagery in the same style as the sample screenshot: dark report background, white assertion cards, figure captions, and suite-by-suite pass/fail status.
      </p>

      <section class="summary-grid">
        <article class="summary-card">
          <span>Backend automated assertions</span>
          <strong>{backend_total}</strong>
        </article>
        <article class="summary-card">
          <span>Frontend automated assertions</span>
          <strong>{frontend_total}</strong>
        </article>
        <article class="summary-card">
          <span>Generated from</span>
          <strong style="font-size:18px">{html.escape(generated_from)}</strong>
        </article>
      </section>

      {''.join(rendered_sections)}

      <p class="footer-note">
        Source-driven totals are computed from the repository test files. Execution status is taken from the latest generated summary in <code>docs/test-results</code>. Open this file in a browser and take screenshots for thesis/report insertion.
      </p>
    </div>
  </main>
</body>
</html>
"""

    OUTPUT_HTML.write_text(html_text)
    print(f"Wrote {OUTPUT_HTML}")


if __name__ == "__main__":
    main()
