#!/usr/bin/env python3
"""Interactive blind scoring for eval/blind_sheet.csv (TASKS.md §2, HUMAN).

Walks the sheet row by row, shows the context and the (model-hidden) reply, and saves
after every row. Stops and resumes anywhere: rows that already have all three 1–5 scores
are skipped on the next run.

    python3 eval/score_sheet.py
    python3 eval/score_sheet.py --blind-id B007     # re-score one row
    python3 eval/score_sheet.py --status            # show progress only

Do not open eval/blind_key.csv until every row is scored.
"""

from __future__ import annotations

import argparse
import csv
import sys
import textwrap
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SHEET_PATH = REPO_ROOT / "eval" / "blind_sheet.csv"
SCORE_FIELDS = ("naturalness_1_5", "accuracy_1_5", "level_1_5")

RUBRIC = """\
채점 기준
  자연스러움  5 원어민 같다 / 4 자연스럽다 / 3 조금 어색 / 2 많이 어색 / 1 무슨 말인지 모르겠다
  영어 정확성 5 오류 없음 / 4 사소한 오류 / 3 눈에 띄는 오류 1~2개 / 2 오류 많음 / 1 문장이 무너짐
  레벨 적합성 5 초중급에 딱 맞다 / 3 조금 어렵거나 쉽다 / 1 전혀 안 맞는다
  사실 지어냄 대화에 없던 사실을 만들어냈으면 y
  받아들일 만함 이 앱의 대화 상대로 계속 쓸 수 있으면 y

입력: 1~5 숫자, y/n, 빈칸=건너뜀, s=이 문항 건너뛰기, q=저장하고 종료
"""


def read_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_rows(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    temp = path.with_suffix(".csv.tmp")
    with temp.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    temp.replace(path)


def is_scored(row: dict, quick: bool = False) -> bool:
    """Full mode needs the three 1–5 scores; quick mode only needs the accept decision."""
    if quick:
        return bool((row.get("acceptable_y_n") or "").strip())
    return all((row.get(field) or "").strip() for field in SCORE_FIELDS)


def ask_number(prompt: str) -> int | None:
    while True:
        value = input(prompt).strip()
        if value == "":
            return None
        if value in {"s", "S"}:
            return None
        if value.isdigit() and 1 <= int(value) <= 5:
            return int(value)
        print("  1~5 사이 숫자로 입력하세요.")


def ask_yes_no(prompt: str, default: bool = False) -> bool:
    while True:
        value = input(prompt).strip().lower()
        if value == "":
            return default
        if value in {"y", "yes", "ㅇ"}:
            return True
        if value in {"n", "no", "ㄴ"}:
            return False
        print("  y 또는 n으로 입력하세요.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, default=SHEET_PATH)
    parser.add_argument("--blind-id", default=None)
    parser.add_argument("--status", action="store_true")
    parser.add_argument(
        "--quick",
        action="store_true",
        help="only ask '받아들일 만함' and '사실 지어냄' (약 15~20분). 1~5 점수는 나중에 채울 수 있다",
    )
    args = parser.parse_args()

    rows = read_rows(args.sheet)
    fieldnames = list(rows[0].keys()) if rows else []
    scored = sum(1 for row in rows if is_scored(row, quick=args.quick))

    if args.status:
        print(f"{scored} / {len(rows)} scored ({'quick' if args.quick else 'full'})")
        return 0

    print(RUBRIC)

    for row in rows:
        if args.blind_id:
            if row["blind_id"] != args.blind_id:
                continue
        elif is_scored(row, quick=args.quick):
            continue

        scored = sum(1 for item in rows if is_scored(item, quick=args.quick))
        print("=" * 78)
        print(f"[{row['blind_id']}]  {scored}/{len(rows)} scored   시나리오: {row['scenario_id']} ({row['topic']})")
        print("-" * 78)
        print("context :", textwrap.fill(row["context"], width=74, subsequent_indent="          "))
        print("response:", textwrap.fill(row["response"], width=74, subsequent_indent="          "))
        print("-" * 78)

        if args.quick:
            row["hallucination_y_n"] = "y" if ask_yes_no("사실 지어냄? (y/N): ") else "n"
            row["acceptable_y_n"] = "y" if ask_yes_no("받아들일 만함? (y/N): ") else "n"
            notes = input("메모 (선택): ").strip()
            if notes:
                row["notes"] = notes
            write_rows(args.sheet, rows, fieldnames)
            print("  저장했습니다.")
            continue

        scores = {}
        for field, label in zip(SCORE_FIELDS, ("자연스러움", "영어 정확성", "레벨 적합성")):
            value = ask_number(f"{label} (1-5, 빈칸=건너뜀): ")
            if value is None:
                print("  이 문항은 나중에 다시 채점합니다.")
                break
            scores[field] = str(value)
        else:
            row.update(scores)
            row["hallucination_y_n"] = "y" if ask_yes_no("사실 지어냄? (y/N): ") else "n"
            row["acceptable_y_n"] = "y" if ask_yes_no("받아들일 만함? (y/N): ") else "n"
            notes = input("메모 (선택): ").strip()
            if notes:
                row["notes"] = notes
            write_rows(args.sheet, rows, fieldnames)
            print("  저장했습니다.")
            continue

        # Skipped mid-row: offer to stop so nothing half-filled is written.
        if input("계속할까요? (Y/n): ").strip().lower() == "n":
            print("중단했습니다. 채점된 행은 그대로 저장되어 있습니다.")
            return 0

    print(f"완료: {sum(1 for row in rows if is_scored(row, quick=args.quick))} / {len(rows)}")
    print("다음: python3 eval/score_summary.py")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyboardInterrupt, EOFError):
        print("\n중단했습니다. 지금까지 채점한 행은 저장되어 있습니다.")
        sys.exit(0)
