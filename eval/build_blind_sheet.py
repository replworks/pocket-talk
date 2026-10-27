#!/usr/bin/env python3
"""Builds a blind evaluation sheet from eval/results/*.jsonl and a separate answer key.

Each row is (scenario, model, final assistant reply) with the model hidden. The evaluator
fills the score columns without seeing the key; eval/blind_key.csv maps blind_id -> model
and must not be opened until scoring is finished.

Usage:
    python3 eval/build_blind_sheet.py
    python3 eval/build_blind_sheet.py --seed 7 --sheet eval/blind_sheet.csv
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = REPO_ROOT / "eval" / "results"
SCENARIOS_PATH = REPO_ROOT / "eval" / "scenarios.json"

# Files produced by the mock client are plumbing tests, not candidates.
EXCLUDED_MARKERS = ("mock",)


def model_label(path: Path) -> str:
    stem = path.stem
    if stem.startswith("apple_ondevice"):
        return "apple_ondevice"
    return stem


def load_results() -> dict[str, dict[str, dict]]:
    """model -> scenarioID -> result record."""
    by_model: dict[str, dict[str, dict]] = defaultdict(dict)
    for path in sorted(RESULTS_DIR.glob("*.jsonl")):
        label = model_label(path)
        if any(marker in label.lower() for marker in EXCLUDED_MARKERS):
            continue
        # long-conversation runs and their context dumps are not candidates
        if label.startswith(("long-", "context-")):
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            if record.get("kind") != "scenario" or not record.get("completed"):
                continue
            if not record.get("turns"):
                continue
            by_model[label][record["scenarioID"]] = record
    return by_model


def format_context(record: dict, keep_turns: int = 2) -> str:
    """The exchange(s) *before* the reply being scored, so the sheet does not repeat it."""
    turns = record["turns"]
    window = turns[:-1][-keep_turns:]
    parts: list[str] = []
    for turn in window:
        parts.append(f"Learner: {turn['userText']}")
        parts.append(f"Minsu: {turn['reply']}")
    return " | ".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261027)
    parser.add_argument("--sheet", type=Path, default=REPO_ROOT / "eval" / "blind_sheet.csv")
    parser.add_argument("--key", type=Path, default=REPO_ROOT / "eval" / "blind_key.csv")
    parser.add_argument("--force", action="store_true", help="rebuild even if scoring has started")
    args = parser.parse_args()

    # Never destroy human scoring again: a rebuild changes blind ids and row content.
    if args.sheet.exists() and not args.force:
        with args.sheet.open(newline="", encoding="utf-8") as handle:
            existing = list(csv.DictReader(handle))
        scored = sum(1 for row in existing if (row.get("naturalness_1_5") or "").strip())
        if scored:
            print(
                f"refusing to rebuild: {scored} row(s) already scored in {args.sheet}.\n"
                "move the sheet aside or pass --force (scores will be lost)."
            )
            return 2

    by_model = load_results()
    if len(by_model) < 2:
        print(f"need at least 2 models with results, found {sorted(by_model)}")
        return 1

    scenarios = {row["id"]: row for row in json.loads(SCENARIOS_PATH.read_text(encoding="utf-8"))}

    rows: list[dict] = []
    coverage: dict[str, int] = {}
    for model, records in sorted(by_model.items()):
        coverage[model] = len(records)
        for scenario_id, record in records.items():
            final_turn = record["turns"][-1]
            rows.append(
                {
                    "model": model,
                    "scenario_id": scenario_id,
                    "topic": scenarios.get(scenario_id, {}).get("topic", record.get("topic", "")),
                    "context": format_context(record),
                    "response": final_turn["reply"],
                }
            )

    rng = random.Random(args.seed)
    rng.shuffle(rows)

    args.sheet.parent.mkdir(parents=True, exist_ok=True)
    with args.sheet.open("w", newline="", encoding="utf-8") as sheet_handle, args.key.open(
        "w", newline="", encoding="utf-8"
    ) as key_handle:
        sheet = csv.writer(sheet_handle)
        key = csv.writer(key_handle)
        sheet.writerow(
            [
                "blind_id",
                "scenario_id",
                "topic",
                "context",
                "response",
                "naturalness_1_5",
                "accuracy_1_5",
                "level_1_5",
                "hallucination_y_n",
                "acceptable_y_n",
                "notes",
            ]
        )
        key.writerow(["blind_id", "model", "scenario_id"])

        for index, row in enumerate(rows, start=1):
            blind_id = f"B{index:03d}"
            sheet.writerow(
                [
                    blind_id,
                    row["scenario_id"],
                    row["topic"],
                    row["context"],
                    row["response"],
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                ]
            )
            key.writerow([blind_id, row["model"], row["scenario_id"]])

    print(f"wrote {args.sheet} ({len(rows)} rows)")
    print(f"wrote {args.key} (do not open until scoring is done)")
    print("\ncoverage (completed scenarios per model):")
    for model, count in sorted(coverage.items()):
        print(f"  {model:<28} {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
