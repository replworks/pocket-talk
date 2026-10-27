# Pocket Talk — 온디바이스 타당성 스파이크

> **이 저장소는 제품이 아니라 측정 도구입니다.**
> "아이폰에서 소형 모델로 초중급 일상회화 말하기/듣기 연습이 되는가?"를 숫자로 판정하기 위한 스파이크입니다.
> 작업 목록과 완료 조건은 [`.replworks/TASKS.md`](.replworks/TASKS.md)가 기준입니다.

- 측정 기기: **iPhone 16 (iPhone17,3), iOS 27.0.1**, Apple Intelligence + Siri 영어
- 온디바이스 모델 컨텍스트: **4,096 토큰** (시뮬레이터는 8,192)
- 비교 모델: 클라우드 `gpt-oss:120b`, 로컬 `llama3.2:3b` / `qwen2.5:3b`

---

## 결과 요약 (2026-10-27 기준)

| 항목 | 기준 | 측정 | 판정 |
| --- | --- | --- | --- |
| 대화 품질 | 클라우드 대비 "받아들일 만함" 70% | **63%** (12/19) vs 클라우드 95% | **미달** (95% CI 41–81%) |
| 문법·사실성 | 문법 오류 거의 없음 | 정확성 **4.58/5**, 지어냄 **0%** | 충족 |
| 컨텍스트 | 30턴에서 앞 내용 유지 | 34턴 사실 **8/8** (정책 64) | 충족 (정책 의존) |
| 음성 인식 | 대화에 지장 없는 WER | **4.8%** (숫자 표기 제외 **2.7%**) | 충족 (1조건) |
| 지연 | 발화 종료 → 음성 시작 1.5초 | **p50 2,545ms**, 48/48 초과 | **미달 (구조적)** |
| 지속성 | 30분 세션 무중단 | 13분/48턴, 배터리 100→100, thermal nominal | 부분 |

핵심 해석 3가지:

1. **문법은 문제가 아니다.** 애플 모델의 실패는 "I don't know" 회피와 자리표시자 응답(`Station A`)에서 나왔다.
2. **지연은 최적화로 해결되지 않는다.** 세션 재사용(캐시 0)·프롬프트 22% 축소(80ms) 모두 효과가 작았고,
   첫 토큰까지 약 1.3초의 고정 오버헤드가 있다. 하한 추정 1.74초.
3. **가드레일이 은행 시나리오를 거부한다**(`May contain unsafe content`, 시뮬레이터·실기기 2/2 재현).

전체 수치와 근거: **[reports/REPORT.md](reports/REPORT.md)** · 판정 초안: **[eval/verdict.md](eval/verdict.md)**

---

## 무엇을 측정하는가

앱은 3개 탭으로 구성된 측정 도구입니다.

| 탭 | 측정 | 산출물 |
| --- | --- | --- |
| **시나리오** | 20개 일상회화 × 4턴을 모델별로 실행. 턴별 지연·실측 토큰·컨텍스트 접힘 | `Documents/results/scenarios-*.jsonl` |
| **ASR** | 30문장을 읽고 인식 결과 vs 정답, 문장별 WER, 조건(조용/걷기/이어폰) | `Documents/results/asr-*.csv` |
| **라이브** | 마이크 → 인식 → 모델 → 음성 합성 한 턴 루프. 발화 종료→첫 토큰→음성 시작, 세션 배터리/발열 | `Documents/results/live-*.jsonl` |

추가로 두 가지 비교 실험을 앱에서 실행할 수 있습니다.

- **장기 대화(34턴)**: 같은 스크립트를 컨텍스트 정책만 바꿔 실행 (`요약 없음` / `기본 64` / `요약 8턴` / `요약 700`)
- **캐시 실험**: 턴마다 새 세션 vs 세션 재사용, 정식 프롬프트 vs 축약 프롬프트

---

## 빠른 시작

### 요구사항

| 항목 | 버전 |
| --- | --- |
| Xcode / iOS SDK | 27.1 (Swift 6.4) |
| macOS | 27.0 이상 |
| XcodeGen | 2.46 (`brew install xcodegen`) |
| 기기 | iOS 27 + Apple Intelligence, 개발자 모드 |
| 서명 | `App/PocketTalkSpike/project.yml`의 `DEVELOPMENT_TEAM` 수정 |

### 코어 테스트

```sh
cd Package/PocketTalkCore && swift test        # 32 tests
```

### 앱 빌드 (시뮬레이터)

```sh
cd App/PocketTalkSpike
xcodegen generate
xcodebuild -scheme PocketTalkSpike \
  -destination "platform=iOS Simulator,name=iPhone 16 (iOS 27),OS=27.0" build
```

> 시뮬레이터에서는 ASR(`SpeechTranscriber`)을 쓸 수 없고, 온디바이스 모델은 Mac의 Apple Intelligence 지원 여부에 달립니다.

### 실기기 실행

무료 개발자 프로파일은 앱 슬롯이 3개라 UI 테스트 러너를 함께 설치할 수 없습니다.
그래서 앱에 `--autorun-*` 인자를 두고 Mac에서 원격 실행합니다.

```sh
DEVICE=<기기 UDID>   # xcrun devicectl list devices

cd App/PocketTalkSpike
xcodebuild -scheme PocketTalkSpike -destination "platform=iOS,id=$DEVICE" \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device $DEVICE \
  ~/Library/Developer/Xcode/DerivedData/PocketTalkSpike-*/Build/Products/Debug-iphoneos/PocketTalkSpike.app
xcrun devicectl device process launch --device $DEVICE --terminate-existing \
  dev.pockettalk.spike -- --autorun-apple   # 또는 --autorun-cache
```

### 결과 회수 · 집계

```sh
xcrun devicectl device copy from --device $DEVICE \
  --domain-type appDataContainer --domain-identifier dev.pockettalk.spike \
  --source Documents/results --destination /tmp/device-results

python3 eval/compute_wer.py --input "/tmp/device-results/asr-*.csv" --out eval/asr_summary.md
python3 eval/score_summary.py            # 블라인드 채점 집계
python3 eval/analyze_long_conversation.py
```

---

## 저장소 구조

```
Package/PocketTalkCore/          # 순수 로직 (UI·프레임워크 의존 최소)
  Sources/PocketTalkCore/
    LanguageModelClient.swift    # respond(history:userText:) — 유일한 모델 seam
    AppleOnDeviceClient.swift    # Foundation Models (스트리밍, 실측 usage)
    ContextManager.swift         # 요약 접기 + 최근 N 유지 + 예산 보장
    WordErrorRate.swift          # 정규화 + 단어 편집거리
    ResultLogger.swift           # JSONL append
    ScenarioRunner.swift         # 시나리오 실행 루프
  Sources/EvalRunner/            # 모델 없이 컨텍스트/요약을 재현하는 CLI
  Tests/                         # 32 tests

App/PocketTalkSpike/             # 얇은 SwiftUI 측정 앱
  project.yml                    # 원본 (.xcodeproj는 xcodegen 생성물)
  Sources/                       # 3탭 + SpeechAnalyzer/AVSpeechSynthesizer 래퍼
  UITests/                       # 시뮬레이터용 UI 테스트

eval/                            # 시나리오·프롬프트·평가 스크립트·원본 결과
  scenarios.json                 # 20개 시나리오 (사람 검수 완료)
  system_prompt.md               # 유일한 시스템 프롬프트
  run_compare.py                 # ollama / ollamacloud / openai / anthropic
  build_blind_sheet.py           # 결과 병합·셔플 (채점 후 재생성 거부)
  score_sheet.py                 # 터미널 채점 (--quick: y/n만)
  compute_wer.py                 # WER 집계 (숫자 표기 vs 어휘 분리)
  results/                       # 실제 측정 JSONL/CSV

reports/                         # 마일스톤별 실행 기록 + 통합 리포트
  REPORT.md                      # ← 전체 결과
```

---

## 측정 방법 요약

| 실험 | 설계 |
| --- | --- |
| 대화 품질 | 20개 시나리오 × 4턴, 동일 시스템 프롬프트. 마지막 응답을 모델명 없이 섞어(79행) 블라인드 채점 |
| 음성 인식 | 30문장(짧은 15 + 긴 15), 조건별 반복. 정규화 후 단어 편집거리 |
| 지연 | 라이브 루프에서 발화 종료→인식→첫 토큰→음성 시작 3구간 기록 |
| 컨텍스트 | 34턴 스크립트에 사실 8개를 심고, 요약 정책별로 기억 여부를 프로브 |
| 지속성 | 세션 시작/종료 배터리 %, `ProcessInfo.thermalState` |

**채점 주체 주의**: 블라인드 점수는 **사람이 아니라 AI 1개 모델**이 매겼습니다. TASKS.md가 요구한 사람 블라인드 평가가 아니며,
같은 시트를 20행 중복 채점했을 때 `받아들일 만함`은 20/20 일치했습니다.

---

## 알려진 한계 (UNVERIFIED)

- Apple n=19 (가드레일 1건 제외), 신뢰구간 41–81%로 넓음
- ASR은 **조용한 곳 1조건, 화자 1명**. 걷기/이어폰 미측정
- 지속성은 30분이 아니라 **13분**
- 기기 `contextSize`는 Apple Intelligence 설정 전 0, 후 4,096 — 준비 상태 의존성 미확인
- 두 번째 AI/사람 채점과의 교차 검증 없음

## 남은 작업

1. **애플 클라우드(`PrivateCloudComputeLanguageModel`)** 가용성·할당량 확인 → 가용 시 같은 20개 시나리오로 비교
   (서드파티 API는 요청당 과금 때문에 사용하지 않음)
2. **30분 세션 + 이어폰/스피커** 실측 → 지속성 칸 확정
3. **문장 단위 TTS 스트리밍** (선택, 0.3~0.5초 절감 여지)
4. **최종 판정** — [eval/verdict.md](eval/verdict.md) §4의 세 선택지 중 하나

## 문서 지도

| 문서 | 내용 |
| --- | --- |
| [reports/REPORT.md](reports/REPORT.md) | 통합 결과 리포트 (수치·판정·한계·재현) |
| [eval/verdict.md](eval/verdict.md) | 판정 초안 (결론란 비움) + 방향 결정 |
| [reports/M0-environment.md](reports/M0-environment.md) | 환경 확인, 시뮬레이터 확정 |
| [reports/M1-core.md](reports/M1-core.md) | 코어 패키지와 32 테스트 |
| [reports/M2-app-skeleton.md](reports/M2-app-skeleton.md) | 앱 골격, 시뮬레이터 실행 |
| [reports/M3-apple-model.md](reports/M3-apple-model.md) | Foundation Models 연결, 실측 토큰 |
| [reports/M3-speech.md](reports/M3-speech.md) | ASR·TTS, 실기기 크래시 2건 수정 |
| [reports/2-model-comparison-prep.md](reports/2-model-comparison-prep.md) | 블라인드 평가 79행 |
| [reports/3-asr.md](reports/3-asr.md) | WER 4.8% |
| [reports/4-device-apple-run.md](reports/4-device-apple-run.md) | 실기기 시나리오 20개 |
| [reports/5-long-conversation.md](reports/5-long-conversation.md) | 34턴 컨텍스트 정책 비교 |
| [reports/6-live-session.md](reports/6-live-session.md) | 라이브 48턴 지연 |
| [reports/6b-cache-experiment.md](reports/6b-cache-experiment.md) | 캐시·프롬프트 실험 (가설 기각) |
| [AGENTS.md](AGENTS.md) | 작업 규칙, 실행 명령, 보고 형식 |
