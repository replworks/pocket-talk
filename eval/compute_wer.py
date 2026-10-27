#!/usr/bin/env python3
"""Word error rate aggregation for the ASR log.

Reads the CSV that the app exports (or the hand-filled eval/asr_log.csv) and prints
per-row plus aggregate numbers.

Normalization matches PocketTalkCore.WordErrorRate.normalize:
lowercase, drop apostrophes, turn every other non-alphanumeric character into a
space, collapse whitespace.

Usage:
    python3 eval/compute_wer.py
    python3 eval/compute_wer.py --input eval/results/asr-20261026-231500.csv
    python3 eval/compute_wer.py --input eval/asr_log.csv --out eval/asr_summary.md
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def normalize(text: str) -> str:
    out = []
    for ch in text.lower():
        if ch in ("'", "\u2019"):
            continue
        if ch.isalnum():
            out.append(ch)
        else:
            out.append(" ")
    return " ".join("".join(out).split())


def words(text: str) -> list[str]:
    normalized = normalize(text)
    return normalized.split(" ") if normalized else []


def edit_distance(reference: list[str], hypothesis: list[str]) -> int:
    """Levenshtein distance over words (S + D + I)."""
    previous = list(range(len(hypothesis) + 1))
    for i, ref_word in enumerate(reference, start=1):
        current = [i] + [0] * len(hypothesis)
        for j, hyp_word in enumerate(hypothesis, start=1):
            if ref_word == hyp_word:
                current[j] = previous[j - 1]
            else:
                current[j] = 1 + min(previous[j - 1], previous[j], current[j - 1])
        previous = current
    return previous[-1]


NUMBER_WORDS = {
    "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
    "eighteen": 18, "nineteen": 19, "twenty": 20, "thirty": 30, "forty": 40,
    "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    "hundred": 100,
}
ORDINAL_WORDS = {
    "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6,
    "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10, "eleventh": 11,
    "twelfth": 12, "thirteenth": 13, "fourteenth": 14, "fifteenth": 15,
    "sixteenth": 16, "seventeenth": 17, "eighteenth": 18, "nineteenth": 19,
    "twentieth": 20, "thirtieth": 30,
}


def number_value(token: str) -> int | None:
    """Maps '7', '7th', '3rd', 'seven', 'third' to an integer."""
    token = token.strip().lower()
    if token.isdigit():
        return int(token)
    if len(token) > 2 and token[:-2].isdigit() and token[-2:] in {"st", "nd", "rd", "th"}:
        return int(token[:-2])
    return NUMBER_WORDS.get(token) or ORDINAL_WORDS.get(token)


def classify_edits(reference: list[str], hypothesis: list[str]) -> tuple[int, int]:
    """Returns (formatting_errors, lexical_errors).

    Formatting = the recognizer wrote the same number differently ('seven' -> '7',
    'third' -> '3rd', 'eight thirty' -> '8 30'). Those are not recognition failures.
    """
    rows, cols = len(reference), len(hypothesis)
    matrix = [[0] * (cols + 1) for _ in range(rows + 1)]
    for r in range(rows + 1):
        matrix[r][0] = r
    for c in range(cols + 1):
        matrix[0][c] = c
    for r in range(1, rows + 1):
        for c in range(1, cols + 1):
            if reference[r - 1] == hypothesis[c - 1]:
                matrix[r][c] = matrix[r - 1][c - 1]
            else:
                matrix[r][c] = 1 + min(matrix[r - 1][c - 1], matrix[r - 1][c], matrix[r][c - 1])

    r, c = rows, cols
    formatting = lexical = 0
    while r > 0 or c > 0:
        if r > 0 and c > 0 and reference[r - 1] == hypothesis[c - 1]:
            r -= 1
            c -= 1
        elif r > 0 and c > 0 and matrix[r][c] == matrix[r - 1][c - 1] + 1:
            ref_value = number_value(reference[r - 1])
            hyp_value = number_value(hypothesis[c - 1])
            if ref_value is not None and ref_value == hyp_value:
                formatting += 1
            else:
                lexical += 1
            r -= 1
            c -= 1
        elif r > 0 and matrix[r][c] == matrix[r - 1][c] + 1:
            if number_value(reference[r - 1]) is not None:
                formatting += 1
            else:
                lexical += 1
            r -= 1
        else:
            if number_value(hypothesis[c - 1]) is not None:
                formatting += 1
            else:
                lexical += 1
            c -= 1
    return formatting, lexical


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return [row for row in csv.DictReader(handle) if (row.get("hypothesis") or "").strip()]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=REPO_ROOT / "eval" / "asr_log.csv")
    parser.add_argument("--out", type=Path, default=None, help="write a markdown summary here")
    args = parser.parse_args()

    if not args.input.exists():
        print(f"input not found: {args.input}", file=sys.stderr)
        return 1

    rows = load_rows(args.input)
    if not rows:
        print(f"no filled-in hypotheses in {args.input}", file=sys.stderr)
        return 1

    results = []
    for row in rows:
        ref = words(row.get("reference", ""))
        hyp = words(row.get("hypothesis", ""))
        errors = edit_distance(ref, hyp)
        formatting, lexical = classify_edits(ref, hyp)
        results.append(
            {
                "id": row.get("sentence_id", ""),
                "condition": (row.get("condition") or "unspecified").strip() or "unspecified",
                "reference_words": len(ref),
                "hypothesis_words": len(hyp),
                "errors": errors,
                "formatting": formatting,
                "lexical": lexical,
                "wer": errors / len(ref) if ref else (0.0 if not hyp else 1.0),
                "lexical_wer": lexical / len(ref) if ref else (0.0 if not hyp else 1.0),
            }
        )

    total_ref = sum(r["reference_words"] for r in results)
    total_errors = sum(r["errors"] for r in results)
    overall = total_errors / total_ref if total_ref else 0.0
    mean_row = sum(r["wer"] for r in results) / len(results)

    by_condition: dict[str, list[dict]] = {}
    for result in results:
        by_condition.setdefault(result["condition"], []).append(result)

    total_formatting = sum(r["formatting"] for r in results)
    total_lexical = sum(r["lexical"] for r in results)
    lexical_overall = total_lexical / total_ref if total_ref else 0.0

    lines = [
        "# ASR 결과 집계",
        "",
        "> 숫자 표기 차이(seven→7, third→3rd, eight thirty→8 30)는 인식 실패가 아니므로 따로 분류했다.",
        "",
        f"- 입력: `{args.input.relative_to(REPO_ROOT) if args.input.is_relative_to(REPO_ROOT) else args.input}`",
        f"- 측정 문장: {len(results)}",
        f"- 전체 WER (총 오류 단어 / 총 정답 단어): **{overall:.3f}** ({total_errors}/{total_ref})",
        f"- 문장별 WER 평균: {mean_row:.3f}",
        f"- 오류 분류: 숫자 표기 {total_formatting}건 / 실제 어휘 오류 {total_lexical}건",
        f"- **어휘 WER (숫자 표기 제외): {lexical_overall:.3f}** ({total_lexical}/{total_ref})",
        "",
        "## 조건별",
        "",
        "| 조건 | 문장 | 오류/정답 단어 | WER |",
        "| --- | --- | --- | --- |",
    ]
    for condition, items in sorted(by_condition.items()):
        ref_words = sum(i["reference_words"] for i in items)
        errors = sum(i["errors"] for i in items)
        lines.append(f"| {condition} | {len(items)} | {errors}/{ref_words} | {errors / ref_words if ref_words else 0:.3f} |")

    lines += ["", "## 오류가 큰 문장", "", "| id | 조건 | 오류 단어(숫자 표기) | WER |", "| --- | --- | --- | --- |"]
    for result in sorted(results, key=lambda r: r["lexical"], reverse=True)[:10]:
        lines.append(
            f"| {result['id']} | {result['condition']} | {result['errors']} "
            f"(숫자 {result['formatting']}) | {result['wer']:.3f} |"
        )

    # Words the recognizer systematically missed or added are more actionable than raw WER.
    missed: Counter[str] = Counter()
    added: Counter[str] = Counter()
    for row in rows:
        ref = words(row.get("reference", ""))
        hyp = words(row.get("hypothesis", ""))
        ref_counts, hyp_counts = Counter(ref), Counter(hyp)
        missed.update((ref_counts - hyp_counts).elements())
        added.update((hyp_counts - ref_counts).elements())

    lines += ["", "## 자주 빠진 단어", ""]
    lines += [f"- {word} ({count})" for word, count in missed.most_common(10)] or ["- 없음"]
    lines += ["", "## 자주 추가된 단어", ""]
    lines += [f"- {word} ({count})" for word, count in added.most_common(10)] or ["- 없음"]

    output = "\n".join(lines) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output, encoding="utf-8")
        print(f"wrote {args.out}")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
