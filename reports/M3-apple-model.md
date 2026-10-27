# M3 (1/2) Apple 온디바이스 모델 연결 — 실행 기록

- 실행일: 2026-10-26 (Asia/Seoul)
- 범위: `AppleOnDeviceClient`(FoundationModels) 작성 + 탭1 클라이언트 선택 연결 + 실측 토큰/지연 로깅
- 결과: **빌드·유닛테스트·시뮬레이터 실행 통과**. 이 Mac의 시뮬레이터에서 Apple Intelligence가 **사용 가능**해서 20개 시나리오를 실제 모델로 돌렸다(19/20 완료, 1건 가드레일 거부).
- 남은 M3: SpeechAnalyzer(ASR), 음성 합성, 라이브 세션 루프 → 아직 미실행.

## 1. SDK에서 확인한 시그니처 (규칙 3: 기억으로 쓰지 않음)

확인 파일:
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator27.1.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64-apple-ios-simulator.swiftinterface`

| 용도 | 확인한 선언 | 비고 |
| --- | --- | --- |
| 모델 | `SystemLanguageModel.default` (static var), `.availability`, `.isAvailable`, `.contextSize` | `contextSize`는 iOS 26.0+ (미지원 시 4096 반환), iOS 27에서 실값 |
| 가용성 | `Availability { .available, .unavailable(UnavailableReason) }`, `UnavailableReason { deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady }` | UI에 이유 표시 |
| 세션 | `LanguageModelSession(model:tools:transcript:)`, `(model:tools:instructions:)` | 대화 이력은 transcript로 주입 |
| 응답 | `respond(to: String, options:) async throws -> Response<String>` | `Response.content` |
| 실측 토큰 | `Response.usage.input.totalTokenCount`, `.cachedTokenCount`, `.output.totalTokenCount` | **iOS 27.0+** |
| 토크나이저 | `SystemLanguageModel.tokenCount(for:) async throws -> Int` | async라 동기 `TokenCounting`에 못 끼움 → 실측은 `Response.usage`로 기록 |
| transcript | `Transcript(entries:)`, `Entry { .instructions, .prompt, .response, ... }`, `Transcript.Instructions(segments:toolDefinitions:)`, `Transcript.Prompt(segments:)`, `Transcript.Response(assetIDs:segments:)` | 시스템 턴은 instructions로 병합 |
| 스트리밍 | `streamResponse(to:) -> ResponseStream<String>` (AsyncSequence, `Snapshot.content`) | 첫 토큰 지연 측정용. **M3(2/2)에서 사용 예정, 아직 미사용** |

## 2. 구현

- `Package/PocketTalkCore/Sources/PocketTalkCore/AppleOnDeviceClient.swift`
  - `actor AppleOnDeviceClient: UsageReportingLanguageModelClient`
  - `respond(history:userText:)`: 가용성 확인 → `Transcript` 재구성 → 새 세션 → `respond(to:)` → `Response.usage`를 `ModelUsage`로 저장 → 텍스트 반환
  - 시스템 턴(페르소나 + 접힌 요약)은 Foundation Models의 단일 instructions 엔트리로 병합
  - `availability()`, `contextSize()` 정적 접근자 → 앱이 "사용 가능/사용 불가: 이유"를 표시
  - `// UNVERIFIED`: 실기기에서 실행해보지 않았다(아래 §5)
- `ModelUsage.swift`: 입력/출력/캐시 토큰 + 컨텍스트 크기. `UsageReportingLanguageModelClient`는 **선택 프로토콜**이라 `LanguageModelClient` 시그니처(TASKS.md 고정)를 건드리지 않았다.
- `ScenarioRunner`: 턴마다 usage를 읽어 `ScenarioTurnResult.usage`와 JSONL(`inputTokens`/`outputTokens`/`cachedInputTokens`/`contextSize`)에 남긴다.
- 탭1: mock/apple 세그먼트 선택. apple이면 실제 `contextSize`에서 출력 예약 512를 뺀 값을 예산으로 쓰고 화면에 표시.
- `Package.swift` 플랫폼을 macOS 27.0 / iOS 27.0으로 올림 (`Response.usage`가 macOS 27 요구).

## 3. 실행한 명령과 실제 출력

### 코어 테스트

```
$ cd Package/PocketTalkCore && swift test
Executed 32 tests, with 0 failures (0 unexpected)
```

### 앱 빌드

```
$ cd App/PocketTalkSpike && xcodebuild -scheme PocketTalkSpike -destination "$DESTINATION" build
** BUILD SUCCEEDED **
```

### 시뮬레이터 UI 테스트 (Apple Intelligence 실제 호출 포함)

```
$ xcodebuild test -scheme PocketTalkSpike -destination "$DESTINATION"
APPLE_AVAILABILITY_LABEL: 사용 가능
APPLE_RUN_STATUS: 완료 19/20 — 첫 오류: May contain unsafe content
Test Case '-[... testAllThreeTabsExist]' passed (8.362 seconds).
Test Case '-[... testAppleClientAvailabilityIsReported]' passed (68.790 seconds).
Test Case '-[... testMockRunCompletesEveryScenario]' passed (10.452 seconds).
** TEST SUCCEEDED **
```

증거 화면: `reports/assets/m3-apple-available.png` (사용 가능 / 모델 컨텍스트 8192 토큰 / apple 실행 버튼)

### Apple 모델 실행 결과 (`eval/results/apple_ondevice-simulator.jsonl`)

20 시나리오 × 4턴 = 80턴 요청, 77턴 응답:

| 항목 | 값 |
| --- | --- |
| 완료 시나리오 | **19 / 20** |
| 실패 | `sc18_bank` — turn 2에서 `May contain unsafe content` (가드레일 거부) |
| 실측 컨텍스트 크기 | **8192 토큰** (TASKS.md 메모의 4096 가정과 다름) |
| 실측 입력 토큰 | 267 ~ 392 (대화가 길어질수록 증가) |
| 실측 출력 토큰 | 21 ~ 29 |
| 캐시 입력 토큰 | 항상 0 (매 턴 새 세션 → 프리픽스 재사용 없음) |
| 턴 지연 | min 551ms / median 749ms / max 2998ms (첫 호출이 콜드 스타트) |

실제 응답 예시 (`sc01_self_intro`, 가공 없음):

```
L: Hello. My name is Jina. I am from Korea.
A: Hello, Jina! Nice to meet you. Where are you from?
L: I am work at a small company in Seoul.
A: Oh, Jina! That is nice. What do you do at work?
```

## 4. 통과 / 실패 / 미실행

| 항목 | 결과 |
| --- | --- |
| SDK 시그니처 확인 + 근거 경로 기록 | **통과** (§1, 코드 주석에도 경로 기재) |
| `AppleOnDeviceClient` 빌드 | **통과** (iOS/macOS 공통 컴파일) |
| 코어 32 테스트 | **통과** |
| 앱 빌드 + UI 테스트 3개 | **통과** |
| 시뮬레이터에서 온디바이스 모델 실제 호출 | **통과** — 19/20 시나리오, 77턴 |
| 실측 토큰 사용량 로깅 | **통과** — JSONL에 input/output/contextSize 기록 |
| 실기기(iPhone 16)에서 호출 | **미실행** — 사람 범위(M4) |
| SpeechAnalyzer(ASR) | **미실행** — M3(2/2) |
| 음성 합성(TTS) | **미실행** — M3(2/2) |
| 스트리밍 첫 토큰 지연 | **미실행** — `streamResponse` 사용 예정 |

## 5. UNVERIFIED

- `AppleOnDeviceClient`는 **실기기에서 검증되지 않았다.** 아래 수치는 Mac 시뮬레이터(iPhone 16 런타임) 값이며, 실기기 성능/발열/지연과 같다고 볼 수 없다.
- `Transcript` 재구성 방식은 SDK 시그니처로만 확인했다. 대화 이력이 모델 쪽에서 어떻게 처리되는지(턴 경계, 지시 우선순위)는 계측하지 않았다.
- 가드레일 실패(`sc18_bank`)의 재현성: 1회 관측. 같은 시나리오를 반복 실행해 재현율을 확인하지 않았다.

## 6. 관찰 (판정에 영향)

1. **가드레일이 시나리오 1개를 거부했다.** 은행 시나리오에서 "Do you have a lot of money to start with?" 류 응답 뒤 `May contain unsafe content`. 학습 앱에서 금융/건강 주제가 막히면 대화가 끊긴다 → §4/§2 평가에서 실패 사례로 다뤄야 한다.
2. **매 턴 새 세션이라 캐시 입력 토큰이 0이다.** 30턴 대화에서 프리픽스 재사용이 없으면 지연/비용이 커진다. 세션을 재사용하는 방식(transcript 누적)은 M3(2/2) 또는 §5에서 비교할 후보.
3. **컨텍스트는 8192토큰**이고 예산 3000은 보수적이다. 실측 입력이 최대 392토큰이므로 20개 시나리오(4턴)에서는 여유가 크다. 30턴에서 다시 측정해야 한다.

## 7. 사람이 할 다음 단계

- 없음(아직). M3(2/2)에서 SpeechAnalyzer/TTS를 붙인 뒤 실기기 설치가 필요하다.
