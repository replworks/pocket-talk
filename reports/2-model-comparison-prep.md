# §2 모델 품질 비교 — 준비 완료 기록

- 실행일: 2026-10-27 (Asia/Seoul)
- 범위: 후보 모델 응답 수집 스크립트, 블라인드 시트, 집계 스크립트
- 결과: **에이전트 준비 완료**. 사람 채점만 남았다. 클라우드 기준선은 API 키 대기.

## 1. 후보 모델과 실행 결과

| 모델 | 백엔드 | 완료 | 턴 수 | 턴 지연 중앙값 | 최대 | 평균 입력 토큰 | 평균 출력 토큰 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `llama3.2:3b` | Ollama (로컬) | **20/20** | 80 | 479ms | 844ms | 284 | 22 |
| `qwen2.5:3b` | Ollama (로컬) | **20/20** | 80 | 393ms | 14,583ms* | 264 | 17 |
| `apple_ondevice` | **실기기 iPhone 16** (iOS 27.0.1) | **19/20** | 77 | 1,433ms | 5,602ms | 319 | 17 |
| `gpt-oss:120b` (Ollama Cloud) | 클라우드 | **20/20** | 80 | 1,113ms | 8,486ms | 330 | 102 |

\* qwen 최대값은 모델 첫 로드(콜드) 1턴. 두 번째 이후는 400ms대.

- 모두 `eval/system_prompt.md`의 동일한 시스템 프롬프트, 동일한 20개 시나리오를 사용했다.
- Apple 응답은 **실기기**(iPhone 16, iOS 27.0.1, 컨텍스트 4096) 결과다. 시뮬레이터 결과는
  `eval/results/simulator/`로 옮겨 아카이브했다(비교 대상에서 제외).
- Apple은 `sc18_bank`에서 가드레일 거부(`May contain unsafe content`)로 1개 미완료.
- 클라우드 기준선은 **Ollama Cloud**(`https://ollama.com/api/chat`, `Authorization: Bearer`)로 수집했다.
  키는 `OLLAMA_API_KEY` 환경변수로만 넘겼고 **어떤 파일에도 저장하지 않았다.**
- 클라우드 모델의 출력이 턴당 평균 102토큰으로 로컬(17~22)보다 4~6배 길다. 시스템 프롬프트의
  "1~3문장" 규칙을 얼마나 지키는지는 블라인드 채점에서 드러난다.

## 2. 만든 스크립트

```
eval/run_compare.py        # 후보 모델 실행 → eval/results/<name>.jsonl
eval/build_blind_sheet.py  # 결과 병합·섞기 → blind_sheet.csv + blind_key.csv
eval/score_summary.py      # 사람 점수 집계 → eval/summary.md
```

- **JSONL 스키마를 앱과 동일하게** 맞췄다(`kind: scenario`, `turns[]`, `inputTokens`…). 그래서 앱이 만든 Apple 결과와 스크립트가 만든 로컬/클라우드 결과를 한 파이프라인에서 섞을 수 있다.
- `run_compare.py` 백엔드: `ollama:`, `ollamacloud:`, `openai:`, `anthropic:`.
- 토큰 수는 Ollama의 `prompt_eval_count`/`eval_count`, Apple의 `Response.usage`에서 온 **실측값**이다.

사용법:

```sh
python3 eval/run_compare.py --model ollama:llama3.2:3b --name llama3.2-3b
python3 eval/build_blind_sheet.py
python3 eval/score_summary.py     # 채점 후
```

## 3. 블라인드 시트

```
eval/blind_sheet.csv   79행 (모델명 숨김, 점수 열 비어 있음)
eval/blind_key.csv     79행 (blind_id → model). 채점 끝나기 전엔 열지 않는다
```

모델별 행 수: `gpt-oss-120b-cloud` 20, `llama3.2-3b` 20, `qwen2.5-3b` 20, `apple_ondevice` 19(실기기).
(클라우드 기준선 추가 전 59행 시트는 채점 전이어서 그대로 재생성했다 — 손실 없음)

- 행 구성: `blind_id, scenario_id, topic, context, response, naturalness_1_5, accuracy_1_5, level_1_5, hallucination_y_n, acceptable_y_n, notes`
- `context`는 마지막 2턴의 대화(학습자/AI)이고, `response`는 마지막 AI 응답이다.
- 셔플 시드 고정(20261027)으로 재생성해도 같은 순서가 나온다.
- 채점 후 `python3 eval/score_summary.py`가 모델별 평균·"받아들일 만함" 비율·실패 상위 10개를 `eval/summary.md`로 만든다.

## 4. 통과 / 미실행

| 항목 | 결과 |
| --- | --- |
| Ollama 모델 2종 다운로드 | **통과** (`llama3.2:3b`, `qwen2.5:3b`) |
| 20개 시나리오 × 로컬 모델 2종 실행 | **통과** (각 20/20) |
| Apple 결과 병합 | **통과** (19건) |
| 블라인드 시트/키 생성 | **통과** (59행, 모델별 19~20행) |
| 클라우드 기준선 수집 | **통과** — `gpt-oss:120b` 20/20 |
| 사람 채점 | **미실행** — 사람 범위 |
| `eval/summary.md` 집계 | **미실행** — 채점 후 실행 |

## 5. UNVERIFIED

- 블라인드 시트의 `context`가 2턴만 담는다. 4턴 전체 맥락 없이 채점하면 후반 대화의 문맥 유지 실패를 놓칠 수 있다.
- Apple 결과는 시뮬레이터에서 수집했다. 실기기 응답 품질과 같다고 가정할 수 없다.
- qwen 최대 지연 14.6초는 콜드 스타트 1건이라 대표값이 아니다.

## 6. 사람이 할 다음 단계

1. `eval/blind_sheet.csv` 59행 채점 (자연스러움/정확성/레벨/지어냄/받아들일 만함). **`blind_key.csv`는 열지 않는다.**
2. 채점 끝나면 알려주세요 → `python3 eval/score_summary.py` 실행해서 `eval/summary.md` 생성.
3. 보안: Ollama Cloud 키가 채팅에 노출됐다. 공유/커밋 전에 재발급을 권장한다(코드·리포트에는 저장하지 않았다).

## 7. 채점 방법 (HUMAN)

터미널에서 한 행씩 보면서 채점하는 스크립트를 만들었다. 점수는 `eval/blind_sheet.csv`에 바로 저장되고,
중간에 멈춰도 이어서 할 수 있다.

```sh
python3 eval/score_sheet.py           # 첫 미채점 행부터
python3 eval/score_sheet.py --status  # 진행률만 확인
python3 eval/score_sheet.py --blind-id B007   # 한 행 다시 채점
```

- 각 행에서 `자연스러움 / 영어 정확성 / 레벨 적합성`(1~5), `사실 지어냄(y/n)`, `받아들일 만함(y/n)`, 메모를 입력한다.
- 기준은 스크립트 실행 시 화면에 출력된다.
- 빈칸으로 넘기면 그 행은 미채점으로 남는다.
- 79행 모두 채점한 뒤 `python3 eval/score_summary.py` → `eval/summary.md` 생성.

`blind_key.csv`는 채점이 끝날 때까지 열지 않는다(스크립트는 키를 읽지 않는다).

> 주의: `build_blind_sheet.py`는 시트를 새로 만든다. 채점이 시작된 뒤에 실행하면 점수가 사라진다.
> 그래서 지금은 채점된 행이 1개라도 있으면 **거부**하고, 정말 다시 만들려면 `--force`를 요구한다.
> (이 가드가 없던 시점에 재생성해서 4행의 채점이 한 번 유실됐다.)

## 8. 다른 AI에게 채점을 맡기는 경우 (2026-10-27 추가)

사람 대신 상위 모델에게 채점을 맡길 수 있도록 프롬프트 생성기를 추가했다.

```sh
python3 eval/make_scoring_prompt.py
#   eval/scoring_prompt.md          79행 한 번에 (약 32KB)
#   eval/scoring_prompts/batch-01..04.md  20행씩 4묶음 (묶음당 약 10KB)

# 다른 AI의 CSV 응답을 eval/ai_scores.csv 로 저장한 뒤
python3 eval/merge_scores.py eval/ai_scores.csv
python3 eval/score_summary.py
```

- 프롬프트에는 모델명이 없고, 채점 rubric·판정 규칙·출력 CSV 형식이 고정되어 있다.
- `merge_scores.py`는 코드펜스/설명문이 섞여 있어도 `Bxxx,`로 시작하는 줄만 읽는다.
  잘못된 값(범위 밖 숫자, 이상한 y/n)은 건너뛰고 보고한다.
- **주의**: 이것은 TASKS.md가 요구한 "사람 블라인드 평가"가 아니라 **AI 채점**이다.
  결과를 인용할 때는 `summary.md`에 "AI-judged"라고 명시하고, 가능하면 서로 다른 두 모델의
  채점을 비교해 일치율을 함께 남긴다. (사람 채점과 AI 채점의 일치율 자체가 좋은 검증 지표가 된다.)

## 9. 채점 결과 (2026-10-27)

79행 전부 채점됐다. 채점은 사람이 아니라 **단일 AI**에게 맡겼고(사용자 선택), 첫 20행은 프롬프트를
두 번 돌린 결과가 함께 들어와 평균했다. 결과 파일: `eval/summary.md`, 원점수: `eval/ai_scores.csv`.

| 모델 | n | 자연스러움 | 정확성 | 레벨 적합성 | 지어냄 | **받아들일 만함** |
| --- | --- | --- | --- | --- | --- | --- |
| `gpt-oss-120b-cloud` (기준선) | 20 | 3.65 | 4.85 | 4.50 | 0% | **95%** (19/20) |
| `qwen2.5-3b` | 20 | 3.15 | 4.75 | 4.85 | 5% | 65% (13/20) |
| `apple_ondevice` (실기기) | 19 | 2.79 | 4.58 | 4.89 | 0% | **63%** (12/19) |
| `llama3.2-3b` | 20 | 2.90 | 4.50 | 4.45 | 0% | 55% (11/20) |

### 통과 기준 대조

TASKS.md: "블라인드 평가에서 클라우드 모델 대비 '받아들일 만함' 비율 70% 이상"

| 해석 | 계산 | 결과 |
| --- | --- | --- |
| 절대 비율 | 63% ≥ 70%? | **미달** |
| 클라우드 대비 상대 비율 | 63% / 95% = 66% ≥ 70%? | **미달** |
| 가드레일 거부(§4, sc18)를 실패로 포함 | 12/20 = 60% | 더 미달 |

단, n=19라 95% 신뢰구간은 **41%~81%**다. "70% 미달"은 점추정 기준이고, 표본을 늘리기 전에는
70%와 통계적으로 구분되지 않는다. 클라우드(19/20)의 구간은 76~99%다.

### 애플 실패 7건의 성격 (원인 분석)

| blind_id | 시나리오 | 관찰 |
| --- | --- | --- |
| B013 | 약국 | 약사가 "I don't know"만 반복 |
| B041 | 쇼핑 | 점원이 모른다고만 함 |
| B066 | 취미 | 맥락에 안 맞게 "I don't know" |
| B077 | 헬스장 | 모른다고 하고 되묻기만 함 |
| B073 | 대중교통 | `Station A` 같은 자리표시자 답변 |
| B006 | 카페 | 결제 확인 후 다른 음료를 물음 |
| B071 | 길 묻기 | "Is today busy?" 뜬금없는 질문 |

**문법 문제가 아니다.** 정확성 4.58, 레벨 적합성 4.89, 지어냄 0%로 오히려 높다.
실패는 **모른다고 회피하거나 자리표시자를 뱉는 "대화 도움성" 문제**다. 자연스러움 2.79가 여기서 깎였다.
클라우드 모델은 20건 중 1건(역할극 흐름 깨짐)만 실패했다.

### 채점 신뢰도 (프롬프트 2회 실행, 20행 중복)

- `acceptable` 판정 일치: **20/20 (100%)**
- 5개 항목 전부 동일: 14/20
- 나머지 6건은 **자연스러움만 1점 차이** (3↔4)
→ 결정 지표(받아들일 만함)는 흔들리지 않았다. 점수 스케일은 ±1 정도 변동.

### 한계

- **AI 채점**이다. TASKS.md가 요구한 사람 블라인드 평가가 아니므로, §7 판정에 쓸 때 이 사실을 명시해야 한다.
- 단일 모델 채점이다. 두 번째 모델로 교차 확인하면 일치율을 얻을 수 있다(`eval/scoring_prompt.md` 재사용).
- Apple n=19(가드레일로 1건 제외). 신뢰구간이 넓다.
