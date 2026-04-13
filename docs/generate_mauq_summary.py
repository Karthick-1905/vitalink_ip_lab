#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from statistics import mean
from textwrap import fill

import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages


WORKBOOK_PATH = Path("MAUQ QUESTIONNAIRE (Responses).xlsx")
SUMMARY_CSV_PATH = Path("MAUQ_anonymized_question_means.csv")
RANKED_CHART_PATH = Path("MAUQ_anonymized_question_means.png")
PIE_CHART_BASENAME = "MAUQ_all_question_pies"
BAR_CHART_PATH = Path("MAUQ_top10_vertical_bar.png")
REPORT_PATH = Path("MAUQ_report_summary.md")
PDF_REPORT_PATH = Path("VitaLink_MAUQ_Report.pdf")
DOCUMENT_TITLE = "VITALINK – AN IMPROVED ANTI-COAGULANT DOSAGE MANAGEMENT PLATFORM"

NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}

TOP10_BAR_QUESTIONS = [1, 7, 8, 13, 16, 17, 18, 19, 20, 22]
PIE_QUESTIONS_PER_PAGE = 6


def col_to_num(col: str) -> int:
    value = 0
    for ch in col:
        value = value * 26 + ord(ch) - 64
    return value


def num_to_col(num: int) -> str:
    parts: list[str] = []
    while num:
        num, rem = divmod(num - 1, 26)
        parts.append(chr(65 + rem))
    return "".join(reversed(parts))


def iter_cols(start: str, end: str) -> list[str]:
    return [num_to_col(i) for i in range(col_to_num(start), col_to_num(end) + 1)]


def clean_question(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text.replace("\n", " ")).strip()
    return cleaned.rstrip(".")


def question_group(question_no: int) -> str:
    if 1 <= question_no <= 8:
        return "Ease of use and satisfaction"
    if 9 <= question_no <= 15:
        return "System information and organization"
    return "Usefulness and provider interaction"


def parse_workbook(path: Path) -> tuple[str, list[dict[str, str]]]:
    with zipfile.ZipFile(path) as zf:
        shared_strings: list[str] = []
        shared_root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
        for item in shared_root.findall("a:si", NS):
            shared_strings.append("".join(node.text or "" for node in item.iterfind(".//a:t", NS)))

        workbook_root = ET.fromstring(zf.read("xl/workbook.xml"))
        relationships_root = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        rel_map = {rel.attrib["Id"]: rel.attrib["Target"] for rel in relationships_root}

        first_sheet = workbook_root.find("a:sheets", NS)[0]
        sheet_name = first_sheet.attrib["name"]
        target = "xl/" + rel_map[first_sheet.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]]
        sheet_root = ET.fromstring(zf.read(target))

        rows: list[dict[str, str]] = []
        for row in sheet_root.findall(".//a:sheetData/a:row", NS):
            row_map: dict[str, str] = {}
            for cell in row.findall("a:c", NS):
                ref = cell.attrib.get("r", "")
                col = "".join(ch for ch in ref if ch.isalpha())
                cell_type = cell.attrib.get("t")
                value_node = cell.find("a:v", NS)
                if cell_type == "s" and value_node is not None:
                    value = shared_strings[int(value_node.text)]
                elif cell_type == "inlineStr":
                    value = "".join(node.text or "" for node in cell.findall(".//a:t", NS))
                else:
                    value = value_node.text if value_node is not None else ""
                row_map[col] = value
            rows.append(row_map)
    return sheet_name, rows


def build_question_summary(rows: list[dict[str, str]]) -> tuple[int, list[dict[str, str | float | int | list[float]]]]:
    if not rows:
        return 0, []

    header = rows[0]
    response_rows = rows[1:]
    question_columns = iter_cols("F", "AA")
    summary: list[dict[str, str | float | int | list[float]]] = []

    for index, col in enumerate(question_columns, start=1):
        values: list[float] = []
        for row in response_rows:
            raw = row.get(col, "").strip()
            if not raw:
                continue
            try:
                values.append(float(raw))
            except ValueError:
                continue
        question = clean_question(header.get(col, f"Question {index}"))
        if values:
            summary.append(
                {
                    "question_no": index,
                    "question": question,
                    "mean_score": round(mean(values), 2),
                    "response_count": len(values),
                    "values": values,
                }
            )

    return len(response_rows), summary


def write_summary_csv(summary: list[dict[str, str | float | int | list[float]]], path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["question_no", "question", "mean_score", "response_count"])
        writer.writeheader()
        for item in summary:
            writer.writerow(
                {
                    "question_no": item["question_no"],
                    "question": item["question"],
                    "mean_score": item["mean_score"],
                    "response_count": item["response_count"],
                }
            )


def create_chart(summary: list[dict[str, str | float | int | list[float]]], sample_count: int, path: Path) -> None:
    plt.style.use("seaborn-v0_8-whitegrid")
    ranked = sorted(summary, key=lambda item: (-float(item["mean_score"]), int(item["question_no"])))
    fig_height = max(8.5, len(ranked) * 0.38)
    fig, ax = plt.subplots(figsize=(13.5, fig_height))

    y_positions = list(range(len(ranked)))
    scores = [float(item["mean_score"]) for item in ranked]
    labels = [f"Q{item['question_no']}" for item in ranked]
    palette = {
        "Ease of use and satisfaction": "#2563eb",
        "System information and organization": "#0f766e",
        "Usefulness and provider interaction": "#dc2626",
    }
    colors = [palette[question_group(int(item["question_no"]))] for item in ranked]

    bars = ax.barh(y_positions, scores, color=colors, edgecolor="white", linewidth=0.9, height=0.72)
    ax.set_yticks(y_positions, labels=labels)
    ax.invert_yaxis()
    ax.set_xlim(0, 7.25)
    ax.set_xlabel("Mean score (1-7 Likert scale)")
    ax.set_ylabel("Question number")
    ax.set_title(f"MAUQ item-wise mean scores (n={sample_count})", fontsize=15, weight="bold")
    ax.xaxis.grid(True, color="#d4d4d8", linewidth=0.8)
    ax.yaxis.grid(False)
    ax.set_axisbelow(True)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    for bar, score in zip(bars, scores):
        ax.text(score + 0.05, bar.get_y() + bar.get_height() / 2, f"{score:.2f}", va="center", fontsize=9, color="#111827")

    legend_handles = [
        plt.Rectangle((0, 0), 1, 1, color=color) for color in palette.values()
    ]
    ax.legend(
        legend_handles,
        list(palette.keys()),
        loc="lower right",
        frameon=False,
        title="MAUQ section",
    )

    ax.text(
        0.0,
        -0.08,
        "Full question wording is listed in MAUQ_anonymized_question_means.csv and MAUQ_report_summary.md.",
        transform=ax.transAxes,
        ha="left",
        va="top",
        fontsize=9,
        color="#4b5563",
    )

    fig.tight_layout()
    fig.savefig(path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def response_buckets(values: list[float]) -> tuple[list[int], list[str], list[str]]:
    negative = sum(1 for value in values if value <= 3)
    neutral = sum(1 for value in values if 4 <= value <= 5)
    positive = sum(1 for value in values if value >= 6)
    return (
        [positive, neutral, negative],
        ["Positive (6-7)", "Neutral (4-5)", "Negative (1-3)"],
        ["#16a34a", "#f59e0b", "#dc2626"],
    )


def create_pie_charts(
    summary: list[dict[str, str | float | int | list[float]]], sample_count: int, basename: str
) -> list[Path]:
    ordered = sorted(summary, key=lambda item: int(item["question_no"]))
    output_paths: list[Path] = []

    for page_index, start in enumerate(range(0, len(ordered), PIE_QUESTIONS_PER_PAGE), start=1):
        selected = ordered[start : start + PIE_QUESTIONS_PER_PAGE]
        path = Path(f"{basename}_{page_index}.png")
        fig, axes = plt.subplots(2, 3, figsize=(18, 10), facecolor="white")
        axes_list = axes.flatten()

        for ax, item in zip(axes_list, selected):
            counts, labels, colors = response_buckets(item["values"])  # type: ignore[arg-type]
            total = sum(counts)
            filtered = [(c, l, col) for c, l, col in zip(counts, labels, colors) if c > 0]
            pie_counts = [c for c, _, _ in filtered]
            pie_labels = [l for _, l, _ in filtered]
            pie_colors = [col for _, _, col in filtered]
            ax.pie(
                pie_counts,
                labels=pie_labels,
                colors=pie_colors,
                startangle=90,
                counterclock=False,
                wedgeprops={"width": 0.42, "edgecolor": "white"},
                autopct=lambda pct: f"{pct:.0f}%" if pct >= 8 else "",
                textprops={"fontsize": 9},
                labeldistance=1.08,
                pctdistance=0.70,
            )
            wrapped_question = fill(str(item["question"]), width=38)
            ax.set_title(
                f"Q{item['question_no']}\n{wrapped_question}",
                fontsize=10.5,
                weight="bold",
                pad=10,
            )
            ax.text(0, 0, f"n={total}", ha="center", va="center", fontsize=10, color="#374151")

        for ax in axes_list[len(selected):]:
            ax.axis("off")

        question_range = f"Q{selected[0]['question_no']}-Q{selected[-1]['question_no']}"
        fig.suptitle(
            f"Feedback distribution for MAUQ questions {question_range}",
            fontsize=16,
            weight="bold",
            y=0.98,
        )
        fig.text(
            0.5,
            0.02,
            f"Grouped as Positive (6-7), Neutral (4-5), and Negative (1-3) from {sample_count} anonymized responses.",
            ha="center",
            fontsize=10,
            color="#4b5563",
        )
        fig.tight_layout(rect=[0, 0.05, 1, 0.95])
        fig.savefig(path, dpi=220, bbox_inches="tight")
        plt.close(fig)
        output_paths.append(path)

    return output_paths


def create_vertical_bar_chart(summary: list[dict[str, str | float | int | list[float]]], sample_count: int, path: Path) -> None:
    selected = [item for item in summary if int(item["question_no"]) in TOP10_BAR_QUESTIONS]
    selected.sort(key=lambda item: TOP10_BAR_QUESTIONS.index(int(item["question_no"])))

    labels = [f"Q{item['question_no']}" for item in selected]
    scores = [float(item["mean_score"]) for item in selected]
    colors = ["#2563eb", "#2563eb", "#2563eb", "#0f766e", "#dc2626", "#dc2626", "#dc2626", "#dc2626", "#dc2626", "#dc2626"]

    fig, ax = plt.subplots(figsize=(14, 8))
    bars = ax.bar(labels, scores, color=colors, width=0.62)
    ax.set_ylim(0, 7)
    ax.set_ylabel("Mean score (1-7)")
    ax.set_title(f"Ten key MAUQ questions: mean scores (n={sample_count})", fontsize=16, weight="bold")
    ax.yaxis.grid(True, color="#d4d4d8", linewidth=0.8)
    ax.set_axisbelow(True)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    for bar, score in zip(bars, scores):
        ax.text(bar.get_x() + bar.get_width() / 2, score + 0.08, f"{score:.2f}", ha="center", va="bottom", fontsize=10)

    mapping_text = " | ".join(f"Q{item['question_no']}: {item['question']}" for item in selected)
    fig.text(0.5, 0.02, mapping_text, ha="center", fontsize=9, color="#4b5563")
    fig.tight_layout(rect=[0.02, 0.06, 0.98, 0.96])
    fig.savefig(path, dpi=220, bbox_inches="tight")
    plt.close(fig)


def add_pdf_title_page(pdf: PdfPages, sample_count: int, overall_mean: float) -> None:
    fig = plt.figure(figsize=(8.27, 11.69), facecolor="white")
    fig.text(0.5, 0.88, DOCUMENT_TITLE, ha="center", va="top", fontsize=20, weight="bold", wrap=True)
    fig.text(0.5, 0.77, "MAUQ Questionnaire Report", ha="center", fontsize=16, color="#1f2937")
    fig.text(0.5, 0.69, f"Responses analyzed: {sample_count}", ha="center", fontsize=13, color="#374151")
    fig.text(0.5, 0.64, f"Overall mean MAUQ score: {overall_mean:.2f}/7", ha="center", fontsize=13, color="#374151")
    fig.text(
        0.5,
        0.50,
        "This document contains the full questionnaire wording and response-distribution charts for all 22 MAUQ items.",
        ha="center",
        fontsize=12,
        color="#4b5563",
        wrap=True,
    )
    fig.text(
        0.5,
        0.08,
        "Generated from anonymized VitaLink questionnaire responses.",
        ha="center",
        fontsize=10,
        color="#6b7280",
    )
    pdf.savefig(fig, bbox_inches="tight")
    plt.close(fig)


def add_pdf_questionnaire_pages(pdf: PdfPages, summary: list[dict[str, str | float | int | list[float]]]) -> None:
    questions_per_page = 11
    ordered = sorted(summary, key=lambda item: int(item["question_no"]))
    for start in range(0, len(ordered), questions_per_page):
        chunk = ordered[start : start + questions_per_page]
        fig = plt.figure(figsize=(8.27, 11.69), facecolor="white")
        fig.text(0.5, 0.965, "Full MAUQ Questionnaire", ha="center", va="top", fontsize=17, weight="bold")
        y = 0.91
        for item in chunk:
            question_text = fill(f"Q{item['question_no']}. {item['question']}", width=82)
            fig.text(0.08, y, question_text, ha="left", va="top", fontsize=11, color="#111827")
            y -= 0.07 + (question_text.count("\n") * 0.022)
        fig.text(
            0.08,
            0.05,
            "Response groups used in charts: Positive (6-7), Neutral (4-5), Negative (1-3).",
            ha="left",
            fontsize=10,
            color="#6b7280",
        )
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)


def add_pdf_image_page(pdf: PdfPages, image_path: Path, heading: str) -> None:
    image = plt.imread(image_path)
    fig = plt.figure(figsize=(8.27, 11.69), facecolor="white")
    fig.text(0.5, 0.97, heading, ha="center", va="top", fontsize=15, weight="bold")
    ax = fig.add_axes([0.06, 0.07, 0.88, 0.86])
    ax.imshow(image)
    ax.axis("off")
    pdf.savefig(fig, bbox_inches="tight")
    plt.close(fig)


def create_pdf_report(
    summary: list[dict[str, str | float | int | list[float]]],
    sample_count: int,
    pie_chart_paths: list[Path],
    pdf_path: Path,
) -> None:
    overall_mean = round(mean(float(item["mean_score"]) for item in summary), 2)
    with PdfPages(pdf_path) as pdf:
        add_pdf_title_page(pdf, sample_count, overall_mean)
        add_pdf_questionnaire_pages(pdf, summary)
        for index, pie_chart_path in enumerate(pie_chart_paths, start=1):
            add_pdf_image_page(pdf, pie_chart_path, f"MAUQ Feedback Distribution Charts ({index}/{len(pie_chart_paths)})")
        add_pdf_image_page(pdf, BAR_CHART_PATH, "Ten Key MAUQ Questions: Mean Scores")
        add_pdf_image_page(pdf, RANKED_CHART_PATH, "All MAUQ Questions: Ranked Mean Scores")


def write_report(summary: list[dict[str, str | float | int | list[float]]], sample_count: int, path: Path) -> None:
    overall_mean = round(mean(float(item["mean_score"]) for item in summary), 2)
    highest = max(summary, key=lambda item: float(item["mean_score"]))
    lowest = min(summary, key=lambda item: float(item["mean_score"]))
    all_question_pie_lines = "\n".join(
        f"- [`{PIE_CHART_BASENAME}_{page_index}.png`](./{PIE_CHART_BASENAME}_{page_index}.png)"
        for page_index in range(1, ((len(summary) - 1) // PIE_QUESTIONS_PER_PAGE) + 2)
    )
    top10_lines = "\n".join(
        f"- Q{item['question_no']}: {item['question']}" for item in summary if int(item["question_no"]) in TOP10_BAR_QUESTIONS
    )

    report = f"""# MAUQ Questionnaire Summary

This summary was generated from `{WORKBOOK_PATH.name}` after excluding personal identifiers from the outputs. The current workbook contains **{sample_count} completed responses**.

## Figures for report

- The following pie-chart pages show response distribution for all 22 questions, with up to {PIE_QUESTIONS_PER_PAGE} questions per image:
{all_question_pie_lines}
- [`{BAR_CHART_PATH.name}`](./{BAR_CHART_PATH.name}) shows mean scores for ten key questions as a vertical bar chart.
- [`{RANKED_CHART_PATH.name}`](./{RANKED_CHART_PATH.name}) remains available as the full item-wise ranked chart.

## Key points

- Overall mean MAUQ score across all questionnaire items: **{overall_mean}/7**
- Highest-scoring item: **Q{highest["question_no"]}** ({highest["mean_score"]}/7) - {highest["question"]}
- Lowest-scoring item: **Q{lowest["question_no"]}** ({lowest["mean_score"]}/7) - {lowest["question"]}
- Detailed anonymized item means are available in [`{SUMMARY_CSV_PATH.name}`](./{SUMMARY_CSV_PATH.name})

## All MAUQ questions used for pie charts

{"\n".join(f"- Q{item['question_no']}: {item['question']}" for item in summary)}

## Ten key questions used for vertical bar chart

{top10_lines}

## Suggested figure caption

*Figure X. Key MAUQ findings for the VitaLink app based on {sample_count} questionnaire responses. Personal identifiers were excluded, and scores are shown on a 1-7 Likert scale.*
"""
    path.write_text(report, encoding="utf-8")


def main() -> None:
    _, rows = parse_workbook(WORKBOOK_PATH)
    sample_count, summary = build_question_summary(rows)
    if not summary:
        raise SystemExit("No questionnaire responses found in the workbook.")
    write_summary_csv(summary, SUMMARY_CSV_PATH)
    create_chart(summary, sample_count, RANKED_CHART_PATH)
    pie_chart_paths = create_pie_charts(summary, sample_count, PIE_CHART_BASENAME)
    create_vertical_bar_chart(summary, sample_count, BAR_CHART_PATH)
    create_pdf_report(summary, sample_count, pie_chart_paths, PDF_REPORT_PATH)
    write_report(summary, sample_count, REPORT_PATH)
    print(f"Wrote {SUMMARY_CSV_PATH}")
    print(f"Wrote {RANKED_CHART_PATH}")
    for pie_chart_path in pie_chart_paths:
        print(f"Wrote {pie_chart_path}")
    print(f"Wrote {BAR_CHART_PATH}")
    print(f"Wrote {PDF_REPORT_PATH}")
    print(f"Wrote {REPORT_PATH}")


if __name__ == "__main__":
    main()
