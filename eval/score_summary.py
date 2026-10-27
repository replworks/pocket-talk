#!/usr/bin/env python3
"""Aggregates the human scores from eval/blind_sheet.csv into eval/summary.md (TASKS.md §2).

Run only after scoring is finished; reading eval/blind_key.csv here unblinds the sheet,
which is fine at aggregation time but not before.

Usage:
    python3 eval/score_summary.py
    python3 eval/score_summary.py --sheet eval/blind_sheet.csv --key eval/blind_key.csv
"""

from __future__ import annotations

import argparse
import csv
import statistics
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCORE_COLUMNS = ("naturalness_1_5", "accuracy_1_5", "level_1_5")


def read_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def number(value: str) -> float | None:
    value = (value or "").strip()
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def yes(value: str) -> bool:
    return (value or "").strip().lower() in {"y", "yes", "ㅇ", "true", "1"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, default=REPO_ROOT / "eval" / "blind_sheet.csv")
    parser.add_argument("--key", type=Path, default=REPO_ROOT / "eval" / "blind_key.csv")
    parser.add_argument("--out", type=Path, default=REPO_ROOT / "eval" / "summary.md")
    parser.add_argument("--judge", default=None, help="who scored the sheet (default: human blind)")
    args = parser.parse_args()

    key = {row["blind_id"]: row for row in read_rows(args.key)}
    rows = read_rows(args.sheet)

    # A row counts once the accept decision exists (quick mode); 1–5 scores are optional.
    scored = []
    for row in rows:
        values = [number(row.get(column, "")) for column in SCORE_COLUMNS]
        if all(value is None for value in values) and not (row.get("acceptable_y_n") or "").strip():
            continue
        scored.append((row, values))

    if not scored:
        print("no scored rows yet — run python3 eval/score_sheet.py")
        return 1

    def mean_or_dash(values: list[float | None]) -> str:
        present = [value for value in values if value is not None]
        return f"{statistics.mean(present):.2f}" if present else "-"

    per_model: dict[str, list[tuple[dict, list[float]]]] = defaultdict(list)
    for row, values in scored:
        model = key.get(row["blind_id"], {}).get("model", "unknown")
        per_model[model].append((row, values))

    lines = [
        "# 블라인드 평가 집계 (TASKS.md §2)",
        "",
        f"- 채점된 행: {len(scored)} / {len(rows)}",
        f"- 채점자: {args.judge or '사람 (블라인드)'}",
        f"- 모델 수: {len(per_model)}",
        "",
        "## 모델별 평균 (1~5)",
        "",
        "| 모델 | 문장 수 | 자연스러움 | 영어 정확성 | 레벨 적합성 | 사실 지어냄 비율 | 받아들일 만함 비율 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]

    for model, items in sorted(per_model.items()):
        hallucination = statistics.mean(1 if yes(row.get("hallucination_y_n", "")) else 0 for row, _ in items)
        acceptable = statistics.mean(1 if yes(row.get("acceptable_y_n", "")) else 0 for row, _ in items)
        lines.append(
            f"| {model} | {len(items)} | {mean_or_dash([values[0] for _, values in items])} | "
            f"{mean_or_dash([values[1] for _, values in items])} | "
            f"{mean_or_dash([values[2] for _, values in items])} | "
            f"{hallucination:.0%} | {acceptable:.0%} |"
        )

    lines += ["", "## 클라우드 기준선 대비 '받아들일 만함' 비율", ""]
    lines += [
        "> 기준선 모델 이름은 `--baseline` 없이 실행했으므로 표의 비율을 직접 비교한다.",
        "",
        "| 모델 | 받아들일 만함 비율 |",
        "| --- | --- |",
    ]
    for model, items in sorted(per_model.items()):
        acceptable = statistics.mean(1 if yes(row.get("acceptable_y_n", "")) else 0 for row, _ in items)
        lines.append(f"| {model} | {acceptable:.0%} |")

    failures = []
    for model, items in per_model.items():
        for row, values in items:
            score = sum(value for value in values if value is not None)
            if not any(value is not None for value in values):
                score = 0 if not yes(row.get("acceptable_y_n", "")) else 100
            failures.append((score, model, row, values))
    failures.sort(key=lambda item: item[0])

    lines += ["", "## 실패 사례 상위 10", "", "| blind_id | 모델 | 시나리오 | 점수 합 | 응답 |", "| --- | --- | --- | --- | --- |"]
    for score, model, row, _ in failures[:10]:
        response = (row.get("response") or "").replace("|", "/").strip()
        lines.append(
            f"| {row['blind_id']} | {model} | {row.get('scenario_id', '')} | {score:.0f} | {response[:120]} |"
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
