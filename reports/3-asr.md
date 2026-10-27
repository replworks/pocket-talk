# §3 음성 인식 실측 — 실행 기록

- 실행일: 2026-10-27 01:22 (Asia/Seoul)
- 측정자: 사용자(사람) — 실기기에서 문장을 직접 읽음
- 기기: iPhone 16, iOS 27.0.1, SpeechAnalyzer + SpeechTranscriber
- 결과: **조용한 곳 29문장, WER 4.8%** (14/294). 숫자 표기 차이를 제외하면 **2.7%** (8/294).

## 1. 방법

- 앱의 ASR 탭에서 30문장 중 29문장을 읽고 문장별 인식 결과를 CSV로 저장
  (`eval/results/asr-20261027-012204.csv`)
- 조건: **조용한 곳만**. 걷기/이어폰 조건은 미실행.
- 정규화: 소문자, 아포스트로피 제거, 구두점 → 공백 (코어 `WordErrorRate`와 동일)
- 집계: `python3 eval/compute_wer.py --input <csv> --out eval/asr_summary.md`

## 2. 결과

| 항목 | 값 |
| --- | --- |
| 측정 문장 | 29 / 30 (s05 누락) |
| 전체 WER | **0.048** (14 / 294 단어) |
| 문장별 WER 평균 | 0.053 |
| 숫자 표기 차이 | 6건 |
| **실제 어휘 오류** | **8건** |
| **어휘 WER** | **0.027** (8 / 294) |
| WER 0인 문장 | 20 / 29 |

## 3. 오류의 성격

### 3.1 숫자 표기 (인식 실패 아님, 6건)

| 정답 | 인식 |
| --- | --- |
| wake up at **seven** | wake up at **7** |
| starts at **eight thirty** | starts at **8 30** |
| learning English for **three** years | for **3** years |
| rest for **two** days | rest for **2** days |
| on the **third** floor | on the **3rd** floor |

같은 숫자를 다르게 쓴 것이라 대화에는 지장이 없다. 다만 WER을 그대로 인용하면 4.8%로 과대평가된다.
`compute_wer.py`가 이제 숫자 표기와 어휘 오류를 분리해서 둘 다 보고한다.

### 3.2 실제 어휘 오류 (4문장, 8단어)

| id | 정답 | 인식 | 오류 |
| --- | --- | --- | --- |
| s03 | very **crowded** today | very **clouded** today | 1 |
| s12 | **Let's meet** in front of the station | **That's meat** in front of the station | 2 |
| s16 | **order a large** iced americano | **auto a lousy** iced Americano | 2 |
| s18 | the **nearest** pharmacy | the **main list** pharmacy | 2 |

패턴: **연속 발화에서 단어 경계가 붙는 경우**(Let's meet → That's meat, order a large → auto a lousy)와
**비슷한 소리의 형용사**(crowded → clouded, nearest → main list). 문장 속 기능어가 아니라
의미를 담당하는 단어에서 틀렸지만, 문장 이해에는 영향이 작다.

## 4. 해석

- 30문장 중 20문장이 완전히 일치했다. **짧은 문장과 긴 문장 모두** 큰 문제는 없었다.
  (긴 문장 s16·s18·s20·s27·s29 중 완전 일치는 s20·s27·s29)
- 남은 오류는 고유명사·숫자·연속 발화 경계다. 대화 지속성 관점에서는 지장이 작다.
- **다만 이 결과는 조용한 환경 1회, 1명의 목소리**다. TASKS.md가 요구한 걷기/이어폰 조건은 아직 없다.

## 5. 통과 / 미실행

| 항목 | 결과 |
| --- | --- |
| 조용한 곳 29문장 | **통과** (WER 4.8%, 어휘 2.7%) |
| 걷기 조건 | **미실행** |
| 이어폰 마이크 | **미실행** |
| 다중 화자/억양 다양성 | **미실행** (범위 밖) |

## 6. UNVERIFIED

- "이 정도 인식률로 대화가 이어지는가"는 **사람 판정**이다. WER이 낮다는 것과 대화가 매끄럽다는 것은 다르다.
- 앱의 문장별 WER 표시는 숫자 표기 차이를 그대로 포함한다(코어 `WordErrorRate` 정의).
  집계 스크립트만 분리 보고하므로, 두 수치가 다를 수 있다.

## 7. 재현

```sh
# 기기에서 결과 가져오기
xcrun devicectl device copy from --device 00008140-001243C93A3A801C \
  --domain-type appDataContainer --domain-identifier dev.pockettalk.spike \
  --source Documents/results --destination /tmp/device-results

python3 eval/compute_wer.py --input "/tmp/device-results/asr-*.csv" --out eval/asr_summary.md
```
