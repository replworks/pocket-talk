#!/usr/bin/env python3
"""Merges scores produced elsewhere (another AI, a spreadsheet) into eval/blind_sheet.csv.

Input: a CSV with header
    blind_id,naturalness_1_5,accuracy_1_5,level_1_5,hallucination_y_n,acceptable_y_n,notes

Tolerates code fences and prose around the CSV (only `Bxxx,...` lines are read).

    python3 eval/merge_scores.py eval/ai_scores.csv
    python3 eval/merge_scores.py eval/ai_scores.csv --overwrite
"""

from __future__ import annotations

import argparse
import csv
import io
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SHEET_PATH = REPO_ROOT / "eval" / "blind_sheet.csv"
SCORE_FIELDS = ("naturalness_1_5", "accuracy_1_5", "level_1_5")
YES_NO_FIELDS = ("hallucination_y_n", "acceptable_y_n")
ROW_PATTERN = re.compile(r"^B\d{3}\s*,")


def normalize_yes_no(value: str) -> str | None:
    value = value.strip().lower()
    if value in {"y", "yes", "ㅇ", "true", "1"}:
        return "y"
    if value in {"n", "no", "ㄴ", "false", "0"}:
        return "n"
    return None


def normalize_score(value: str) -> str | None:
    value = value.strip()
    if not value:
        return None
    try:
        number = float(value)
    except ValueError:
        return None
    if number < 1 or number > 5:
        return None
    return str(int(round(number)))


def clean_note(note: str) -> str:
    return note.strip().strip('"”).“”\'')


def average(values: list[int]) -> int:
    return int(sum(values) / len(values) + 0.5)


def majority(values: list[str]) -> str:
    return "y" if sum(1 for value in values if value == "y") * 2 > len(values) else "n"


def parse_scores(path: Path) -> tuple[dict[str, dict[str, str]], list[str]]:
    text = path.read_text(encoding="utf-8")
    lines = [line for line in text.splitlines() if ROW_PATTERN.match(line.strip())]
    if not lines:
        raise SystemExit(f"no Bxxx rows found in {path}")

    reader = csv.reader(io.StringIO("\n".join(lines)))
    grouped: dict[str, list[dict[str, str]]] = {}
    for cells in reader:
        if len(cells) < 6:
            continue
        blind_id = cells[0].strip()
        naturalness, accuracy, level = (normalize_score(cells[i]) for i in (1, 2, 3))
        hallucination = normalize_yes_no(cells[4])
        acceptable = normalize_yes_no(cells[5])
        if None in (naturalness, accuracy, level, hallucination, acceptable):
            print(f"  skip {blind_id}: invalid values {cells[1:6]}")
            continue
        grouped.setdefault(blind_id, []).append(
            {
                "naturalness_1_5": naturalness,
                "accuracy_1_5": accuracy,
                "level_1_5": level,
                "hallucination_y_n": hallucination,
                "acceptable_y_n": acceptable,
                "notes": clean_note(cells[6]) if len(cells) > 6 else "",
            }
        )

    # The same blind_id can appear twice when several prompt batches overlap. Keep one row:
    # average the 1–5 scores, take the majority for y/n, and report where the decisions differ.
    scores: dict[str, dict[str, str]] = {}
    conflicts: list[str] = []
    for blind_id, items in grouped.items():
        if len(items) == 1:
            scores[blind_id] = items[0]
            continue

        decisions = {item["acceptable_y_n"] for item in items}
        if len(decisions) > 1:
            conflicts.append(f"{blind_id}: acceptable {sorted(decisions)}")

        notes = " / ".join(dict.fromkeys(item["notes"] for item in items if item["notes"]))
        scores[blind_id] = {
            "naturalness_1_5": str(average([int(item["naturalness_1_5"]) for item in items])),
            "accuracy_1_5": str(average([int(item["accuracy_1_5"]) for item in items])),
            "level_1_5": str(average([int(item["level_1_5"]) for item in items])),
            "hallucination_y_n": majority([item["hallucination_y_n"] for item in items]),
            "acceptable_y_n": majority([item["acceptable_y_n"] for item in items]),
            "notes": notes[:200],
        }
    return scores, conflicts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("scores", type=Path)
    parser.add_argument("--sheet", type=Path, default=SHEET_PATH)
    parser.add_argument("--overwrite", action="store_true", help="replace scores that already exist")
    args = parser.parse_args()

    with args.sheet.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    fieldnames = list(rows[0].keys())
    by_id = {row["blind_id"]: row for row in rows}

    scores, conflicts = parse_scores(args.scores)
    unknown = sorted(set(scores) - set(by_id))
    if unknown:
        print(f"unknown blind ids (ignored): {', '.join(unknown[:10])}")

    applied = 0
    skipped = 0
    for blind_id, values in scores.items():
        row = by_id.get(blind_id)
        if row is None:
            continue
        if not args.overwrite and (row.get("naturalness_1_5") or "").strip():
            skipped += 1
            continue
        row.update(values)
        applied += 1

    temp = args.sheet.with_suffix(".csv.tmp")
    with temp.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    temp.replace(args.sheet)

    scored = sum(1 for row in rows if (row.get("acceptable_y_n") or "").strip())
    print(f"applied {applied} rows, skipped {skipped} already-scored, total scored {scored}/{len(rows)}")
    if conflicts:
        print("decision conflicts between duplicate passes:")
        for conflict in conflicts:
            print(f"  {conflict}")
    if scored < len(rows):
        print("next: collect the remaining rows, then python3 eval/score_summary.py")
    else:
        print("next: python3 eval/score_summary.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
