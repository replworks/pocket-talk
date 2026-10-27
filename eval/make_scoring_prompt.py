#!/usr/bin/env python3
"""Generates ready-to-paste evaluation prompts from eval/blind_sheet.csv.

The sheet hides model names; the prompt asks another AI (or a human) to fill the same
columns. Output:

    eval/scoring_prompt.md          one shot, all rows
    eval/scoring_prompts/batch-NN.md  batches of 20 rows (safer for long sheets)

After the other AI answers, save its CSV as eval/ai_scores.csv and run
eval/merge_scores.py. The key (eval/blind_key.csv) is never read here.
"""

from __future__ import annotations

import csv
import io
import math
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SHEET_PATH = REPO_ROOT / "eval" / "blind_sheet.csv"
PROMPT_PATH = REPO_ROOT / "eval" / "scoring_prompt.md"
BATCH_DIR = REPO_ROOT / "eval" / "scoring_prompts"
BATCH_SIZE = 20

HEADER = "blind_id,naturalness_1_5,accuracy_1_5,level_1_5,hallucination_y_n,acceptable_y_n,notes"

TEMPLATE = """\
# 역할

당신은 한국인 학습자용 **초중급(CEFR A2–B1) 영어 회화 연습 앱**의 응답 품질을 채점하는 엄격한 평가자입니다.
아래 표의 각 행은 짧은 역할극 대화의 마지막 AI 튜터 응답입니다. 모델 이름은 숨겨져 있으며, 추측하지 마세요.

# 튜터에게 주어진 지시 (평가 기준의 전제)

- 쉬운 영어(A2–B1), 짧고 흔한 단어
- 매 턴 1~3문장
- 항상 간단한 질문 하나로 끝내기
- 학습자 문법을 고쳐주지 말고, 의도에 반응하기
- 시나리오를 벗어나 새 인물/사실을 만들지 않기
- AI라거나 테스트라거나 언급하지 않기

# 채점 항목

| 열 | 의미 | 1 | 3 | 5 |
| --- | --- | --- | --- | --- |
| `naturalness_1_5` | 자연스러움 | 무슨 말인지 모르겠다 | 조금 어색 | 원어민 같다 |
| `accuracy_1_5` | 영어 정확성 | 문장이 무너짐 | 눈에 띄는 오류 1~2개 | 오류 없음 |
| `level_1_5` | 레벨 적합성 | 초중급에 전혀 안 맞음 | 조금 어렵거나 쉬움 | 초중급에 딱 맞음 |
| `hallucination_y_n` | 사실 지어냄 | — | — | — |
| `acceptable_y_n` | 받아들일 만함 | — | — | — |

## `hallucination_y_n` 판정 (중요)

- **y**: 학습자에 대해 틀린 정보를 단정하거나, 대화에 없던 학습자 정보를 만들어냄
  (예: 학습자가 "여동생 이름은 Mina"라고 했는데 "Your sister's name is Minsoo")
- **y**: 틀린 일반 사실을 사실인 양 단정 (예: "Busan is the capital of Korea")
- **n**: 역할극 소품을 자연스럽게 만듦 (상점 재고, 메뉴, 날씨 등) — 단, 대화 맥락과 모순되면 y
- **n**: "I don't know", 되묻기, 맞장구만 함

## `acceptable_y_n` 판정

이 앱의 대화 상대로 **계속 쓸 수 있는가**.
- y: 초중급 학습자와의 짧은 대화로 문제없다
- n: 문장이 깨졌거나, 질문이 없거나, 대화가 끊기거나, 사실을 틀리게 가르친다

# 판정 규칙

1. 주어진 `context`와 `response`만 보고 판단한다. 모델 추측, 추측에 기반한 가점/감점 금지.
2. 길이가 길수록 좋은 점수를 주지 않는다. 1~3문장 규칙을 어기면 `level`을 4 이하로.
3. 학습자의 마지막 말에 반응하지 않으면 `naturalness`를 2 이하로.
4. 문법 오류가 대화 이해를 막으면 `accuracy`를 2 이하로.
5. `hallucination_y_n`이 y이면 `acceptable_y_n`도 n으로 한다.
6. 애매하면 y가 아니라 n으로 두고 `notes`에 이유를 적는다.
7. 모든 행에 점수를 매긴다. 빈칸 금지.

# 출력 형식

아래 헤더를 가진 **CSV만** 출력하세요. 설명, 인사말, 마크다운 코드펜스 금지.

```
blind_id,naturalness_1_5,accuracy_1_5,level_1_5,hallucination_y_n,acceptable_y_n,notes
```

- 입력 행 수와 **정확히 같은 수**의 줄을 출력하고 `blind_id`를 그대로 유지
- 숫자는 1~5 정수, 판정은 `y` 또는 `n`
- `notes`는 한 문장(한국어 가능). 쉼표가 들어가면 큰따옴표로 감싸기
- CSV 뒤에 `## 반복 실패 패턴` 섹션을 붙여도 됩니다(선택). 그 앞까지가 채점 결과로 읽힙니다

# 평가 대상 데이터

다음 CSV의 각 행을 채점하세요.

```csv
{data}
```
"""


def data_block(rows: list[dict]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(["blind_id", "scenario_id", "context", "response"])
    for row in rows:
        writer.writerow([row["blind_id"], row["scenario_id"], row["context"], row["response"]])
    return buffer.getvalue().rstrip("\n")


def main() -> int:
    with SHEET_PATH.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    PROMPT_PATH.write_text(TEMPLATE.format(data=data_block(rows)), encoding="utf-8")
    print(f"wrote {PROMPT_PATH} ({len(rows)} rows)")

    BATCH_DIR.mkdir(parents=True, exist_ok=True)
    for old in BATCH_DIR.glob("batch-*.md"):
        old.unlink()

    batches = math.ceil(len(rows) / BATCH_SIZE)
    for index in range(batches):
        chunk = rows[index * BATCH_SIZE : (index + 1) * BATCH_SIZE]
        path = BATCH_DIR / f"batch-{index + 1:02d}.md"
        prompt = TEMPLATE.format(data=data_block(chunk))
        prompt += f"\n\n> 이 프롬프트는 전체 {len(rows)}행 중 {index * BATCH_SIZE + 1}~{index * BATCH_SIZE + len(chunk)}행입니다.\n"
        path.write_text(prompt, encoding="utf-8")
        print(f"wrote {path} ({len(chunk)} rows)")

    print("\nnext: 다른 AI의 CSV 응답을 eval/ai_scores.csv 로 저장 -> python3 eval/merge_scores.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
