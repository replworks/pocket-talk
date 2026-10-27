# M2 앱 골격 — 실행 기록

- 실행일: 2026-10-26 (Asia/Seoul)
- 범위: `project.yml`(XcodeGen)로 앱 프로젝트 생성, 3탭 화면 골격, 파일 내보내기 설정
- 결과: **통과** — `xcodegen generate` → `xcodebuild build` → 시뮬레이터 설치·실행 → UI 테스트 2개 통과

## 1. 만든 것

```
App/PocketTalkSpike/
  project.yml                        # 원본. .xcodeproj는 생성물
  Info.plist                         # xcodegen이 project.yml에서 생성
  Sources/
    PocketTalkSpikeApp.swift
    RootView.swift                   # 3탭
    ScenarioRunnerView.swift         # 탭1: 시나리오 20개 로드 + mock 실행 + JSONL 저장
    ASRTestView.swift                # 탭2: 골격 (M3에서 SpeechAnalyzer)
    LiveSessionView.swift            # 탭3: 골격 (M3에서 마이크→ASR→모델→TTS)
    MeasurementStore.swift           # Documents/results 경로, 번들 system_prompt.md 로더
  UITests/ScenarioRunnerUITests.swift # 검증 도구: mock 20개 완주를 실제로 탭해서 확인
  PocketTalkSpike.xcodeproj          # 생성물 (직접 편집 금지)
```

`eval/scenarios.json`과 `eval/system_prompt.md`를 **번들 리소스로 직접 참조**한다. 파일을 복사하지 않아 앱·테스트·스크립트가 같은 원본을 본다.

`project.yml` 주요 설정:

| 항목 | 값 | 근거 |
| --- | --- | --- |
| target / scheme | `PocketTalkSpike` | TASKS.md M2 명령어 |
| deployment target | iOS 27.0 | 테스트 기기 iPhone 16 / iOS 27.0.2 |
| Swift | 6.0, strict concurrency `complete` | 새 코드 기준 |
| 패키지 | `../../Package/PocketTalkCore` 로컬 패키지 | 코어 로직 분리 |
| 번들 리소스 | `../../eval/scenarios.json`, `../../eval/system_prompt.md` | 단일 원본 |
| `UIFileSharingEnabled` | true | TASKS.md §0 파일 내보내기 |
| `LSSupportsOpeningDocumentsInPlace` | true | 동일 |
| UI 테스트 타깃 | `PocketTalkSpikeUITests` | 에이전트가 탭 동작까지 검증하기 위함 |

## 2. 실행한 명령과 실제 출력

### `cd App/PocketTalkSpike && xcodegen generate`

```
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/cable8mm/Swifts/pocket-talk/App/PocketTalkSpike/PocketTalkSpike.xcodeproj
```

### `xcodebuild -scheme PocketTalkSpike -destination "platform=iOS Simulator,name=iPhone 16 (iOS 27),OS=27.0" build`

```
** BUILD SUCCEEDED **
```

- 서명: `Sign to Run Locally` (시뮬레이터 전용, 개발팀 설정 불필요)
- 산출물: `.../Debug-iphonesimulator/PocketTalkSpike.app`
- 번들 내용 확인: `scenarios.json`, `system_prompt.md`, `Info.plist` 포함
- `PlistBuddy` 확인: `UIFileSharingEnabled=true`, `LSSupportsOpeningDocumentsInPlace=true`, `CFBundleIdentifier=dev.pockettalk.spike`

### 시뮬레이터 설치·실행

```
$ xcrun simctl boot F4E1A84F-...            # iPhone 16 (iOS 27)
$ xcrun simctl install F4E1A84F-... PocketTalkSpike.app
$ xcrun simctl launch F4E1A84F-... dev.pockettalk.spike
dev.pockettalk.spike: 98686
```

실행 화면 (증거: `reports/assets/m2-scenario-runner.png`):

- 탭 3개(시나리오 / ASR / 라이브) 표시
- 설정: 클라이언트 `mock (실제 모델 아님)`, 시나리오 `20개`, 예산 `3000 토큰`, 시스템 프롬프트 `eval/system_prompt.md`
- 상태: `준비 완료 — 20개` → 번들에서 시나리오 20개 로드 + `system_prompt.md` 첫 코드블록 파싱이 **실제 앱에서** 동작함을 확인

### `xcodebuild test -scheme PocketTalkSpike -destination "$DESTINATION"`

```
Test Case '-[PocketTalkSpikeUITests.ScenarioRunnerUITests testAllThreeTabsExist]' passed (5.999 seconds).
Test Case '-[PocketTalkSpikeUITests.ScenarioRunnerUITests testMockRunCompletesEveryScenario]' passed (7.285 seconds).
** TEST SUCCEEDED **
```

UI 테스트는 실행 버튼을 실제로 탭하고 `완료 20/20`이 뜰 때까지 기다린다. 즉 **탭1의 mock 실행 경로가 시뮬레이터에서 실제로 완주**했다.

### 저장된 JSONL 확인 (앱 컨테이너)

```
$ xcrun simctl get_app_container <udid> dev.pockettalk.spike data
.../Documents/results/scenarios-mock-20261026-230104.jsonl

$ wc -l <파일>
20
```

파이썬으로 레코드 검증:

```
records: 20
kinds: ['scenario']
completed: 20 / 20
turns: [4]
max folded: 0
max est prompt tokens: 269
first id/topic/client: sc01_self_intro / 자기소개 / mock
sample reply: (mock) That sounds nice! What happened next?
```

- JSONL 1줄 = 시나리오 1개, 20줄 전부 파싱됨
- 20개 모두 `completed: true`
- `estimatedPromptTokens` 최대 269 (예산 3000 대비 여유)
- `foldedTurnCount` 0 — 시나리오가 4턴이라 최근 8턴 창을 넘지 않았다(의도된 결과). 접힘 동작은 M1 유닛테스트와 §5의 30턴 리포트에서 검증한다.
- 표본 파일을 `eval/results/scenarios-mock-simulator.jsonl`로 보관했다.

## 3. 통과 / 실패 / 미실행

| 항목 | 결과 |
| --- | --- |
| `xcodegen generate` (project.yml → .xcodeproj) | **통과** |
| `xcodebuild build` (iPhone 16 / iOS 27.0) | **통과** — `** BUILD SUCCEEDED **` |
| 시뮬레이터 설치·실행 | **통과** — 앱 실행, 3탭 표시 |
| 번들 리소스 로드 (20 시나리오 + 프롬프트) | **통과** — 화면에 `20개`, `eval/system_prompt.md` 표시 |
| mock 20개 실행 + JSONL 저장 | **통과** — UI 테스트 + 컨테이너 파일 20줄 |
| 파일 앱/AirDrop 내보내기 | **미실행** — plist 키는 확인했지만 실제 Files 앱에서 꺼내보는 것은 실기기/사람 확인 필요 |
| Apple 온디바이스 모델 호출 | **미실행** — M3. 탭1은 mock 전용이며 화면에도 그렇게 표시 |
| ASR / TTS | **미실행** — M3. 두 탭은 "지금은 화면 골격만 있다"고만 표시 |

## 4. UNVERIFIED

- `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`로 **실제 파일 앱에서 Documents가 보이는지**: plist 값만 확인했다. 시뮬레이터 파일 앱에서 육안 확인하지 않았다.
- 실기기(iPhone 16) 설치/서명: 미실행 (M3 HUMAN).

## 5. 사람이 할 다음 단계

1. 시뮬레이터 화면이 의도한 골격인지 확인 (`reports/assets/m2-scenario-runner.png`).
2. `eval/scenarios.json` 20개 문장 검수 (TASKS.md §1 [HUMAN]).
3. M3 진행 승인 — FoundationModels / SpeechAnalyzer / AVSpeechSynthesizer 시그니처를 SDK에서 확인한 뒤 연결한다.
