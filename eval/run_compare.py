#!/usr/bin/env python3
"""Runs eval/scenarios.json against a candidate model and writes eval/results/<name>.jsonl.

The output schema mirrors the app's JSONL (PocketTalkCore.ScenarioResultRecord) so the
blind sheet builder can treat Apple on-device results and local/cloud results identically.

Supported backends:
  ollama:<model>      local Ollama server (http://127.0.0.1:11434)
  ollamacloud:<model> Ollama Cloud (needs OLLAMA_API_KEY)
  openai:<model>      OpenAI chat completions (needs OPENAI_API_KEY)
  anthropic:<model>   Anthropic messages API (needs ANTHROPIC_API_KEY)

Examples:
  python3 eval/run_compare.py --model ollama:llama3.2:3b --name llama3.2-3b
  python3 eval/run_compare.py --model ollama:qwen2.5:3b --name qwen2.5-3b
  python3 eval/run_compare.py --model ollama:llama3.2:3b --limit 2   # smoke test
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCENARIOS_PATH = REPO_ROOT / "eval" / "scenarios.json"
SYSTEM_PROMPT_PATH = REPO_ROOT / "eval" / "system_prompt.md"
RESULTS_DIR = REPO_ROOT / "eval" / "results"

OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
OLLAMA_CLOUD_URL = "https://ollama.com/api/chat"
NUM_CTX = 8192


def load_system_prompt() -> str:
    text = SYSTEM_PROMPT_PATH.read_text(encoding="utf-8")
    collecting = False
    buffer: list[str] = []
    for line in text.splitlines():
        if line.startswith("```"):
            if collecting:
                return "\n".join(buffer).strip()
            collecting = True
            continue
        if collecting:
            buffer.append(line)
    raise SystemExit("system prompt fenced block not found in eval/system_prompt.md")


def load_scenarios(limit: int | None) -> list[dict]:
    scenarios = json.loads(SCENARIOS_PATH.read_text(encoding="utf-8"))
    if limit is not None:
        scenarios = scenarios[:limit]
    return scenarios


def post_json(url: str, payload: dict, headers: dict[str, str], timeout: int = 180) -> dict:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", **headers},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def ollama_reply(model: str, messages: list[dict], temperature: float) -> tuple[str, int, int]:
    payload = post_json(
        OLLAMA_URL,
        {
            "model": model,
            "messages": messages,
            "stream": False,
            "options": {"temperature": temperature, "num_ctx": NUM_CTX},
        },
        headers={},
    )
    text = (payload.get("message") or {}).get("content", "").strip()
    return text, int(payload.get("prompt_eval_count") or 0), int(payload.get("eval_count") or 0)


def ollama_cloud_reply(model: str, messages: list[dict], temperature: float) -> tuple[str, int, int]:
    """Ollama Cloud (https://ollama.com). Key comes from OLLAMA_API_KEY; never stored."""
    api_key = os.environ.get("OLLAMA_API_KEY")
    if not api_key:
        raise SystemExit("OLLAMA_API_KEY is not set")

    payload = post_json(
        OLLAMA_CLOUD_URL,
        {
            "model": model,
            "messages": messages,
            "stream": False,
            "options": {"temperature": temperature},
        },
        headers={"Authorization": f"Bearer {api_key}"},
    )
    text = (payload.get("message") or {}).get("content", "").strip()
    return text, int(payload.get("prompt_eval_count") or 0), int(payload.get("eval_count") or 0)


def openai_reply(model: str, messages: list[dict], temperature: float) -> tuple[str, int, int]:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is not set")
    payload = post_json(
        "https://api.openai.com/v1/chat/completions",
        {"model": model, "messages": messages, "temperature": temperature},
        headers={"Authorization": f"Bearer {api_key}"},
    )
    text = payload["choices"][0]["message"]["content"].strip()
    usage = payload.get("usage", {})
    return text, int(usage.get("prompt_tokens") or 0), int(usage.get("completion_tokens") or 0)


def anthropic_reply(model: str, messages: list[dict], temperature: float) -> tuple[str, int, int]:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise SystemExit("ANTHROPIC_API_KEY is not set")

    system = "".join(message["content"] for message in messages if message["role"] == "system")
    turns = [message for message in messages if message["role"] != "system"]
    payload = post_json(
        "https://api.anthropic.com/v1/messages",
        {
            "model": model,
            "max_tokens": 512,
            "temperature": temperature,
            "system": system,
            "messages": turns,
        },
        headers={"x-api-key": api_key, "anthropic-version": "2023-06-01"},
    )
    text = "".join(block.get("text", "") for block in payload.get("content", [])).strip()
    usage = payload.get("usage", {})
    return text, int(usage.get("input_tokens") or 0), int(usage.get("output_tokens") or 0)


BACKENDS = {
    "ollama": ollama_reply,
    "ollamacloud": ollama_cloud_reply,
    "openai": openai_reply,
    "anthropic": anthropic_reply,
}


def run_scenario(
    scenario: dict,
    backend: str,
    model: str,
    system_prompt: str,
    temperature: float,
) -> dict:
    started_at = datetime.now(timezone.utc)
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "assistant", "content": scenario["opening_prompt"]},
    ]

    turns: list[dict] = []
    completed = True
    error_message = None
    began = time.perf_counter()

    for index, user_text in enumerate(scenario["user_turns"]):
        messages.append({"role": "user", "content": user_text})
        turn_started = time.perf_counter()
        try:
            reply, prompt_tokens, output_tokens = BACKENDS[backend](model, messages, temperature)
        except (urllib.error.URLError, KeyError, TimeoutError) as error:
            completed = False
            error_message = f"{type(error).__name__}: {error}"
            break

        elapsed_ms = (time.perf_counter() - turn_started) * 1_000
        if not reply:
            completed = False
            error_message = "empty reply"
            break

        messages.append({"role": "assistant", "content": reply})
        turns.append(
            {
                "index": index,
                "userText": user_text,
                "reply": reply,
                "modelMilliseconds": round(elapsed_ms, 1),
                "estimatedPromptTokens": prompt_tokens,
                "promptTurnCount": len(messages),
                "foldedTurnCount": 0,
                "droppedTurnCount": 0,
                "didDropSummary": False,
                "didTruncateUserText": False,
                "inputTokens": prompt_tokens,
                "outputTokens": output_tokens,
            }
        )

    return {
        "kind": "scenario",
        "runID": uuid.uuid4().hex[:12],
        "scenarioID": scenario["id"],
        "topic": scenario["topic"],
        "client": model,
        "startedAt": started_at.isoformat(),
        "durationMilliseconds": round((time.perf_counter() - began) * 1_000, 1),
        "completed": completed,
        "errorMessage": error_message,
        "foldedTurnCount": 0,
        "droppedTurnCount": 0,
        "turns": turns,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, help="backend:model, e.g. ollama:llama3.2:3b")
    parser.add_argument("--name", default=None, help="output name (default: slug of the model)")
    parser.add_argument("--limit", type=int, default=None, help="only the first N scenarios")
    parser.add_argument("--temperature", type=float, default=0.7)
    parser.add_argument("--out-dir", type=Path, default=RESULTS_DIR)
    args = parser.parse_args()

    if ":" not in args.model:
        parser.error("--model must look like backend:model")
    backend, model = args.model.split(":", 1)
    if backend not in BACKENDS:
        parser.error(f"unknown backend {backend!r}; expected one of {sorted(BACKENDS)}")

    name = args.name or model.replace("/", "-").replace(":", "-")
    scenarios = load_scenarios(args.limit)
    system_prompt = load_system_prompt()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    output_path = args.out_dir / f"{name}.jsonl"
    if output_path.exists():
        output_path.unlink()

    print(f"model={backend}:{model} scenarios={len(scenarios)} out={output_path}")
    with output_path.open("w", encoding="utf-8") as handle:
        for ordinal, scenario in enumerate(scenarios, start=1):
            record = run_scenario(scenario, backend, model, system_prompt, args.temperature)
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
            handle.flush()
            status = "ok" if record["completed"] else f"FAILED ({record['errorMessage']})"
            print(f"[{ordinal}/{len(scenarios)}] {scenario['id']} {status}")

    completed = sum(1 for line in output_path.read_text(encoding="utf-8").splitlines() if json.loads(line)["completed"])
    print(f"done: {completed}/{len(scenarios)} completed -> {output_path}")
    return 0 if completed == len(scenarios) else 1


if __name__ == "__main__":
    raise SystemExit(main())
