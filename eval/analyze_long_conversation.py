#!/usr/bin/env python3
"""Analyzes the 34-turn long conversation runs (TASKS.md §5).

Input: eval/results/long-<policy>-*.jsonl (same schema as the app's scenario records)
      eval/long_conversation.json (probe definition: which turn asks about which fact)
Output: eval/long_conversation_report.md

A probe passes when the reply to that turn mentions the expected fact. A probe that passes
without folding but fails with folding is a concrete "summary lost information" point.

Usage:
    python3 eval/analyze_long_conversation.py
    python3 eval/analyze_long_conversation.py --results eval/results
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "eval" / "long_conversation.json"


POLICY_LABELS = {
    "noFold": "요약 없음",
    "defaultFold": "요약 8턴",
    "recommended": "기본 64",
    "tight": "요약 700",
}


def policy_name(path: Path) -> str:
    # long-<policy>-<timestamp>.jsonl
    match = re.match(r"long-(.+?)-\d{8}-\d{6}", path.stem)
    raw = match.group(1) if match else path.stem
    return POLICY_LABELS.get(raw, raw)


def load_contexts(results_dir: Path) -> dict[str, dict[int, dict]]:
    """policy -> turn -> context dump (summary facts) produced by EvalRunner --replay."""
    contexts: dict[str, dict[int, dict]] = {}
    for path in sorted(results_dir.glob("context-*.json")):
        raw = path.stem.replace("context-", "")
        policy = POLICY_LABELS.get(raw, raw)
        rows = json.loads(path.read_text(encoding="utf-8"))
        contexts[policy] = {row["turn"]: row for row in rows}
    return contexts


def load_runs(results_dir: Path) -> dict[str, dict]:
    runs: dict[str, dict] = {}
    for path in sorted(results_dir.glob("long-*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            record = json.loads(line)
            if record.get("kind") != "scenario":
                continue
            runs[policy_name(path)] = record
    return runs


def probe_passes(reply: str, expected: list[str]) -> bool:
    lowered = reply.lower()
    return any(token.lower() in lowered for token in expected)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results", type=Path, default=REPO_ROOT / "eval" / "results")
    parser.add_argument("--script", type=Path, default=SCRIPT_PATH)
    parser.add_argument("--out", type=Path, default=REPO_ROOT / "eval" / "long_conversation_report.md")
    args = parser.parse_args()

    script = json.loads(args.script.read_text(encoding="utf-8"))
    if isinstance(script, list):
        script = script[0]
    probes = script.get("probes", [])
    runs = load_runs(args.results)
    contexts = load_contexts(args.results)
    if not runs:
        print(f"no long-*.jsonl under {args.results}")
        return 1

    policies = list(runs)
    lines = [
        "# 34턴 장기 대화 — 컨텍스트 정책별 기억력 (TASKS.md §5)",
        "",
        f"- 스크립트: `eval/long_conversation.json` ({len(script['user_turns'])}턴, 사실 {len(probes)}개)",
        "- 같은 스크립트를 네 가지 정책으로 실행: `요약 없음` / `기본 64`(recentTurns 64, budget 7000) / `요약 8턴` / `요약 700`",
        "",
        "## 실행 요약",
        "",
        "| 정책 | 완료 | 턴 | 요약 시작 턴 | 최대 추정 토큰 | 최대 실측 입력 | 평균 턴 지연 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]

    for policy in policies:
        record = runs[policy]
        turns = record["turns"]
        folded_start = next((t["index"] for t in turns if t.get("foldedTurnCount", 0) > 0), None)
        max_estimated = max((t.get("estimatedPromptTokens") or 0) for t in turns) if turns else 0
        inputs = [t["inputTokens"] for t in turns if t.get("inputTokens")]
        latencies = [t["modelMilliseconds"] for t in turns]
        lines.append(
            f"| {policy} | {'예' if record['completed'] else '아니오'} | {len(turns)} | "
            f"{folded_start if folded_start is not None else '없음'} | {max_estimated} | "
            f"{max(inputs) if inputs else '-'} | "
            f"{round(sum(latencies) / len(latencies)) if latencies else '-'}ms |"
        )

    lines += [
        "",
        "## 기억 프로브 결과",
        "",
        "`O` 응답에 사실 포함 · `X` 요약에서 사라짐 · `?` 요약에는 있으나 모델이 쓰지 않음",
        "",
        "| 턴 | 사실 | 기대 단어 | " + " | ".join(policies) + " |",
        "| --- | --- | --- | " + " | ".join("---" for _ in policies) + " |",
    ]

    probe_results: dict[str, dict[int, bool]] = {policy: {} for policy in policies}
    for probe in probes:
        row = [str(probe["turn"]), probe["fact"], ", ".join(probe["expect"])]
        for policy in policies:
            turns = runs[policy]["turns"]
            turn = next((t for t in turns if t["index"] == probe["turn"]), None)
            if turn is None:
                row.append("-")
                continue
            passed = probe_passes(turn["reply"], probe["expect"])
            probe_results[policy][probe["turn"]] = passed
            if passed:
                row.append("O")
                continue
            dump = contexts.get(policy, {}).get(probe["turn"])
            if dump is None:
                row.append("X")
                continue
            expected_in_summary = any(
                token.lower() in " ".join(dump.get("factsInSummary", [])).lower()
                for token in probe["expect"]
            )
            row.append("?" if expected_in_summary else "X")
        lines.append("| " + " | ".join(row) + " |")

    lines += ["", "## 요약으로 인해 새로 잃은 사실", ""]
    losses: list[str] = []
    baseline_key = "요약 없음"
    if baseline_key in probe_results:
        baseline = probe_results[baseline_key]
        for policy in policies:
            if policy == baseline_key:
                continue
            lost = [turn for turn, passed in baseline.items() if passed and not probe_results[policy].get(turn, True)]
            if lost:
                detail = ", ".join(
                    next(p["fact"] for p in probes if p["turn"] == turn) for turn in lost
                )
                losses.append(f"- `{policy}`: {detail}")
            else:
                losses.append(f"- `{policy}`: 없음")
    if not losses:
        losses.append("- 기준선(`noFold`) 결과가 없어 비교할 수 없다")
    lines += losses

    lines += [
        "",
        "## 요약이 400자에서 어떻게 미끄러지는가",
        "",
        "`ExtractiveSummarizer`는 400자를 넘으면 **뒤쪽(최신)을 남기고 앞을 버린다.**",
        "그래서 대화가 진행될수록 요약에는 최근 사실만 남고, 초반에 심은 사실은 사라진다.",
        "",
        "| 정책 | 턴 | 요약에 남은 사실 |",
        "| --- | --- | --- |",
    ]
    for policy in policies:
        for turn in (9, 11, 15, 19, 22, 24, 27, 29):
            dump = contexts.get(policy, {}).get(turn)
            if not dump:
                continue
            facts = ", ".join(dump.get("factsInSummary", [])) or "-"
            lines.append(f"| {policy} | {turn} | {facts} |")

    args.out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"\nwrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
