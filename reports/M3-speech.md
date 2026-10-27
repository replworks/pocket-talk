# M3 (2/2) SpeechAnalyzer · 음성 합성 · 라이브 루프 — 실행 기록

- 실행일: 2026-10-26 (Asia/Seoul)
- 범위: ASR 탭(30문장 + WER CSV), 음성 합성, 라이브 세션 턴 루프·지연 로깅, eval 기록 양식
- 결과: **빌드/유닛/UI 테스트 통과**, TTS는 시뮬레이터에서 실제로 소리 시작까지 측정됨(122~204ms).
  **ASR은 시뮬레이터에서 `SpeechTranscriber.isAvailable == false`** 로 실행 불가 → 실기기 필요.
  라이브 루프 전체(마이크→인식→모델→TTS)는 실기기에서만 검증 가능.

## 1. SDK에서 확인한 시그니처 (규칙 3)

### Speech
`.../iPhoneSimulator27.1.sdk/System/Library/Frameworks/Speech.framework/Modules/Speech.swiftmodule/arm64-apple-ios-simulator.swiftinterface`

| 용도 | 확인한 선언 |
| --- | --- |
| 인식기 | `SpeechTranscriber(locale:preset:)`, `(locale:transcriptionOptions:reportingOptions:attributeOptions:)` |
| 지원 여부 | `static var isAvailable: Bool`, `static var supportedLocales: [Locale] { get async }`, `static func supportedLocale(equivalentTo:) async -> Locale?` |
| 결과 | `var results: some AsyncSequence<Result, Error>` — `Result.text: AttributedString`, `isFinal` (`SpeechModuleResult` 확장) |
| 분석기 | `SpeechAnalyzer(modules:)`, `start(inputSequence:)`, `finalizeAndFinishThroughEndOfInput()`, `static bestAvailableAudioFormat(compatibleWith:) async -> AVAudioFormat?` |
| 모델 자산 | `AssetInventory.status(forModules:)`, `reserve(locale:)`, `assetInstallationRequest(supporting:)` → `AssetInstallationRequest.downloadAndInstall()` |
| 오디오 변환 | iOS 27 `AnalyzerInputConverter(analyzerFormat:)`, `convert(_:at:) -> [AnalyzerInput]` |

### 음성 합성
`.../iPhoneSimulator27.1.sdk/System/Library/Frameworks/AVFAudio.framework/Headers/AVSpeechSynthesis.h`

| 용도 | 확인한 선언 |
| --- | --- |
| 합성기 | `AVSpeechSynthesizer.speakUtterance:`, `.isSpeaking`, `.stopSpeakingAtBoundary:` |
| 발화 | `AVSpeechUtterance(string:)`, `.voice`, `.rate` |
| 시작 시점 | delegate `speechSynthesizer:didStartSpeechUtterance:` |

**실제 함정**: 헤더 주석의 `didStartSpeechUtterance:`는 Swift 6.4에서 `speechSynthesizer(_:didStart:)`로 import된다(컴파일러 진단으로 확인). 헤더만 보고 작성한 1차 빌드는 실패했고, 진단 메시지에 맞춰 수정했다.

## 2. 만든 것

```
App/PocketTalkSpike/Sources/
  SpeechRecognizer.swift    # SpeechAnalyzer 1회 인식 (시작/종료, 자산 확인, 포맷 변환)
  SpeechSynthesis.swift     # AVSpeechSynthesizer + "음성 시작" 시각 측정
  DeviceMetrics.swift       # 배터리 %, thermalState (시뮬레이터는 배터리 nil)
  ASRSentences.swift        # eval/asr_sentences.json 로드 + WER CSV 작성
  ASRTestView.swift         # 탭2: 30문장, 조건 선택, 녹음, WER, CSV 저장
  LiveSessionView.swift     # 탭3: 마이크→모델→TTS 루프, 지연/토큰/배터리 JSONL
eval/
  asr_sentences.json        # 짧은 15 + 긴 15 (총 30)
  asr_log.csv               # 30행 기록 양식 (정답까지 채움, 인식 결과는 사람이 기록)
  compute_wer.py            # WER 집계 스크립트 (정규화 규칙은 Swift와 동일)
  device_log.md             # 30분 세션 기록 양식
Package/PocketTalkCore/Sources/PocketTalkCore/
  AppleOnDeviceClient.swift # + generate(): streamResponse로 첫 토큰 시각 측정, Usage 기록
  ResultLogger.swift        # + SessionRecord, LiveTurnLatencyRecord에 컨텍스트/토큰 필드
```

## 3. 실행한 명령과 실제 출력

### 코어 테스트

```
$ cd Package/PocketTalkCore && swift test
Executed 32 tests, with 0 failures
```

### 앱 빌드

```
$ cd App/PocketTalkSpike && xcodebuild -scheme PocketTalkSpike -destination "$DESTINATION" build
** BUILD SUCCEEDED **
```

### UI 테스트 (전체, 6개)

```
$ xcodebuild test -scheme PocketTalkSpike -destination "$DESTINATION" -collect-test-diagnostics never
Test Case '... testAllThreeTabsExist' passed (6.851 seconds).
APPLE_AVAILABILITY_LABEL: 사용 가능
APPLE_RUN_STATUS: 완료 19/20 — 첫 오류: May contain unsafe content
Test Case '... testAppleClientAvailabilityIsReported' passed (81.959 seconds).
ASR_RECORDING: false ASR_PROBLEM: 이 기기에서 SpeechTranscriber를 쓸 수 없다
Test Case '... testASRScreenStartsOrExplainsWhyNot' passed (11.091 seconds).
LIVE_SESSION_END: 세션 종료 — 0턴 기록
Test Case '... testLiveSessionStartsAndEnds' passed (12.554 seconds).
Test Case '... testMockRunCompletesEveryScenario' passed (7.773 seconds).
TTS_OUTCOME: TTS 시작까지 204ms
Test Case '... testSpeechSynthesisStartsOrExplainsWhyNot' passed (9.482 seconds).
Executed 6 tests, with 0 failures (0 unexpected) in 129.710 seconds
** TEST SUCCEEDED **
```

### 라이브 세션 JSONL (시작/종료 기록)

```
{"client":"apple_ondevice","endedAt":"2026-10-26T14:46:42Z","kind":"session","sessionID":"7680152B",
 "startedAt":"2026-10-26T14:46:40Z","thermalStateEnd":"nominal","thermalStateStart":"nominal","turnCount":0}
```

`batteryStart/End`가 없는 것은 **시뮬레이터가 `batteryLevel == -1`을 반환**하기 때문이다(값을 지어내지 않고 nil로 남김).

### WER 스크립트 스모크 테스트

```
$ python3 eval/compute_wer.py --input /tmp/wer_test.csv
- 전체 WER (총 오류 단어 / 총 정답 단어): 0.115 (3/26)
| quiet | 2 | 1/12 | 0.083 |
| walking | 1 | 2/14 | 0.143 |
## 자주 빠진 단어
- a (2)
- iced (1)
```

## 4. 통과 / 실패 / 미실행

| 항목 | 결과 |
| --- | --- |
| Speech/AVFAudio 시그니처 확인 + 근거 기록 | **통과** (§1) |
| ASR 탭 빌드 + 30문장 로드 | **통과** (버튼 활성 조건 = 문장 로드) |
| SpeechAnalyzer 시작/종료 경로 | **미실행** — 시뮬레이터에서 `SpeechTranscriber.isAvailable == false` |
| 음성 인식 정확도(WER) | **미실행** — 실기기 + 사람 목소리 필요 |
| TTS 음성 시작 | **통과** — 204ms (이전 실행 122ms) |
| 라이브 루프 1턴 (마이크→모델→TTS) | **미실행** — ASR이 시뮬레이터에서 불가 |
| 세션 시작/종료 기록 | **통과** — JSONL `session` 레코드 생성 |
| 턴별 지연 3종 로깅 코드 | 작성됨, **턴 실행은 미실행** (ASR 의존) |
| WER 집계 스크립트 | **통과** (합성 입력으로 실행) |

## 5. UNVERIFIED

- **음성 인식**: 실기기에서 한 번도 돌리지 않았다. 시뮬레이터 미지원.
- **`AnalyzerInputConverter` 경로**: 컴파일만 확인. 실제 마이크 버퍼 변환이 되는지 미확인.
- **라이브 루프 전체**: ASR이 없어 1턴도 완주하지 못했다. 코드 경로만 존재한다.
- **TTS 시작 시각**: 시뮬레이터 기준. 실기기 블루투스/스피커 경로는 미확인.
- **배터리/발열**: 시뮬레이터는 배터리 nil, thermalState만 nominal.

## 6. 사람이 할 다음 단계 (M3 HUMAN → M4)

1. Xcode에서 서명 팀 설정 후 iPhone 16(iOS 27.0.2)에 설치.
2. **ASR 탭**: 조건(조용한 곳/걷으며/이어폰)마다 30문장을 읽고 CSV 저장 → 파일 앱으로 `Documents/results/asr-*.csv` 추출.
3. 추출한 CSV로 집계:
   ```sh
   python3 eval/compute_wer.py --input <추출한 csv> --out eval/asr_summary.md
   ```
4. **라이브 탭**: 30분 세션(§6) 실행, `eval/device_log.md` 작성, `live-*.jsonl` 추출.
5. 시나리오 탭에서 apple 선택 → 20개 실행(실기기) → `eval/results/apple_ondevice.jsonl` 확보.

## 7. 남은 [AGENT] 작업

- §2 블라인드 평가 시트/비교 스크립트, §5 30턴 요약 리포트, §7 verdict 초안.

## 8. 추기 — "소리가 안 들린다" 진단 (2026-10-26)

사용자 질문: "아무런 소리도 안 들리는데 기다리면 되?" → **아니오. 기다려도 안 들린다.**

측정으로 확인한 사실:

| 확인 | 결과 |
| --- | --- |
| TTS가 오디오를 만드는가 | **예** — `writeUtterance:toBufferCallback:`으로 렌더한 버퍼 피크 **0.724** (무음 아님) |
| TTS 시작까지 | **108ms** (`didStartSpeechUtterance`) |
| 호스트에 Simulator.app이 떠 있는가 | **아니오** — `pgrep -fl Simulator.app` 결과 없음. CoreSimulator 서비스만 headless로 실행 중 |
| Mac 출력 | 음소거 아님, 볼륨 38, MacBook Pro Speakers |

결론: 앱은 소리를 만들지만 **이 환경에는 그 소리가 나갈 오디오 경로(Simulator.app GUI)가 없다.** 시뮬레이터 화면도 `simctl` 프레임버퍼로 캡처한 것이라 창이 없다.
소리를 들으려면 macOS에서 Simulator.app을 열거나(`open -a Simulator`), 실기기에서 실행해야 한다. 어느 쪽이든 "기다리는" 문제가 아니다.

### 이 김에 고친 것

- `AudioSessionController` 추가: TTS 전에 `.playback` 카테고리 활성화. 이전에는 세션 설정이 없어
  **실기기에서 무음 스위치가 켜져 있으면 TTS가 안 들릴 수 있었다.**
- `TTS만 확인` 버튼이 이제 "시작 지연 + 렌더 피크"를 함께 표시한다 → 출력 경로와 합성 여부를 분리해서 볼 수 있다.

### 남긴 경고 (TODO)

- `AVAudioNode.installTap(onBus:bufferSize:format:block:)`은 **iOS 27에서 deprecated**.
  대체는 `installTapOnBus:bufferSize:format:error:block:`이고 `NS_REFINED_FOR_SWIFT`라 Swift 이름을
  아직 확인하지 못했다 → `// UNVERIFIED` 성격의 TODO. 마이크 경로를 실기기에서 처음 돌릴 때 함께 정리한다.
- `AVAudioSession.CategoryOptions.allowBluetooth`는 `allowBluetoothHFP`로 이름이 바뀌었다(경고만, 동작 동일).

### 사용자 확인 (2026-10-27)

- 사용자가 Simulator.app에서 **TTS 소리가 나는 것을 직접 확인**했다("시뮬레이터에서 소리나는거 확인했어").
  → 음성 합성 경로(문자열 → AVSpeechSynthesizer → 스피커)는 사람 확인까지 완료.
- 여전히 미확인: 음성 **인식**(시뮬레이터 미지원), 라이브 루프 1턴, 실기기 TTS/블루투스.

## 9. 추기 — 실기기 설치·실행 (2026-10-27)

- `xcodegen`에 `DEVELOPMENT_TEAM: M9N98B9A3K`(Apple Development: cable8mm@gmail.com)를 기록하고
  `xcodebuild -destination "platform=iOS,id=..." -allowProvisioningUpdates`로 빌드 → `devicectl device install` 성공.
- 첫 실행은 "profile has not been explicitly trusted"로 거부됐고, 사용자가 기기에서 프로파일을 신뢰한 뒤
  `devicectl device process launch` **성공**. `devicectl device capture screenshot`으로 화면 확인
  (`reports/assets/m3-device-first-run.png`).
- 실기기: iPhone 16 (iPhone17,3), **iOS 27.0.1 (24A446)** — TASKS.md의 27.0.2와 다름.
- **관찰**: 실기기 화면에서 `모델 컨텍스트`가 **0 토큰**으로 표시됐다. 시뮬레이터에서는 8192였다.
  `SystemLanguageModel.default.contextSize`가 기기에서 0을 돌려주는 경우인데, 모델 준비 전인지
  API 동작 차이인지 확인하지 못했다 → **UNVERIFIED**. apple 실행 시 예산 계산이 512로 떨어질 수 있으므로
  M4 첫 실행에서 반드시 확인한다.

## 10. 추기 — 실기기에서 ASR 크래시 발견·수정 (2026-10-27)

기기에서 ASR 탭을 자동 조작했을 때 **앱이 크래시**했다.

```
EXC_BREAKPOINT / SIGTRAP
libdispatch: _dispatch_assert_queue_fail
libswift_Concurrency: swift_task_checkIsolatedSwift
PocketTalkSpike: closure #1 in SpeechRecognizer.startAudio(analyzerFormat:)
AVFAudio: AVAudioNodeTap::TapMessage::RealtimeMessenger_Perform()
```

원인: `installTap`에 넘긴 클로저가 `@MainActor` 메서드 안에서 만들어져 **MainActor 격리를 상속**했고,
오디오 실시간 스레드에서 호출되면서 런타임 격리 검사에 걸려 트랩했다. 시뮬레이터에서는
`SpeechTranscriber.isAvailable == false`라 탭이 한 번도 돌지 않아 드러나지 않았던 버그다.

수정: 탭 클로저를 `@Sendable` 타입으로 명시해 nonisolated로 만들고, 캡처는 Sendable한
`AnalyzerInputConverterBox`와 `AsyncStream.Continuation`만 남겼다.

```
ASR_RECORDING: true ASR_PROBLEM: -
ASR_AFTER_STOP: 인식 완료 — 오류 6단어
Test Case '...testASRScreenStartsOrExplainsWhyNot' passed (9.821 seconds)
```

→ 실기기에서 **녹음 시작 → 종료 → 인식 결과 생성**까지 실제로 동작함을 확인했다.
(무음 환경이라 인식된 문장은 틀렸고, 오류 6단어로 기록됐다. 인식 품질 측정은 사람이 문장을 읽어야 한다.)

같은 실행에서 확인한 기기 값:

| 항목 | 값 |
| --- | --- |
| Apple Intelligence | 사용 가능 |
| 모델 컨텍스트 / 예산 | 4,096 / 3,584 토큰 |
| TTS 시작까지 | **8ms** (렌더 피크 0.724) |
| 라이브 세션 시작/종료 | 정상 (`세션 종료 — 0턴 기록`) |

## 11. 추기 — 두 번째 녹음에서 앱 종료 (2026-10-27 01:12)

사용자가 실기기에서 ASR을 하다가 **두 번째 문장에서 앱이 꺼진다**고 보고했다. 크래시 로그:

```
EXC_BREAKPOINT / SIGTRAP
Speech: TranscriberCommon.worker.setter
Speech: closure #11 in SpeechAnalyzer.setWorkers(for:reusingFrom:preservingFunctionOf:)
Speech: SpeechAnalyzer.prepareModulesIfNeeded() -> processInput -> analyzeSequence
```

원인: 한 `SpeechTranscriber` 인스턴스를 첫 세션에서 쓰고, 두 번째 세션에서 **새 `SpeechAnalyzer`에 재사용**했다.
Speech 프레임워크가 같은 모듈 인스턴스를 다른 분석기에 다시 붙이는 것을 허용하지 않아 내부 assertion으로 트랩한다.

수정: `prepare()`는 자산 확인용 임시 인스턴스만 쓰고, **`start()`마다 새 `SpeechTranscriber` + 새 `SpeechAnalyzer`**를 만든다.

검증(실기기 UI 테스트, `testASRTwoConsecutiveRecordings`):

```
ASR_ROUND[1]: 인식 완료 — 오류 6단어
ASR_ROUND[2]: 인식 완료 — 오류 6단어      ← 두 번째 세션 정상
Test Case '...testASRTwoConsecutiveRecordings' passed (19.382 seconds)
```

문장 1 녹음 → `다음 문장` → 문장 2 녹음까지 실제로 통과했다.
