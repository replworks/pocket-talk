# M1 Core 패키지 — 실행 기록

- 실행일: 2026-10-26 (Asia/Seoul)
- 범위: `Package/PocketTalkCore` (순수 로직) + `eval/scenarios.json`(20개) + `eval/system_prompt.md`
- 결과: **통과** (`swift test` 32개 전부 통과)

## 1. 만든 것

```
Package/PocketTalkCore/
  Package.swift                    # iOS 27.0 / macOS 26.0, tools 6.0
  Sources/PocketTalkCore/
    ConversationTurn.swift         # role/text, Codable
    LanguageModelClient.swift      # respond(history:userText:) async throws -> String
    MockLanguageModelClient.swift  # 순환 응답, {user} 치환, 실패 주입
    TokenCounting.swift            # 주입식 토큰 카운터 (Character / Word)
    ContextManager.swift           # 요약 접기 + 최근 N턴 유지 + 예산 보장
    WordErrorRate.swift            # 정규화 + 단어 단위 편집거리 (S/D/I 분해)
    ResultLogger.swift             # JSONL append (actor), 시나리오/턴 지연/라이브 지연 레코드
    Scenario.swift                 # scenarios.json 모델 + 20개 검증 규칙
    ScenarioRunner.swift           # 시나리오 실행 루프, 턴별 측정, JSONL 기록
  Tests/PocketTalkCoreTests/       # 32 tests
eval/
  scenarios.json                   # 초중급 일상회화 20개 (각 4턴)
  system_prompt.md                 # 페르소나 + 난이도/턴 수/질문 규칙
```

## 2. 설계 판단 (TASKS.md 근거)

- **`LanguageModelClient` 프로토콜**: TASKS.md §0의 시그니처 그대로. 코어는 FoundationModels를 모른다. Apple 구현은 M3에서 SDK 시그니처 확인 후 추가한다.
- **`ContextManager` 압축 순서**: (1) 최근 N턴보다 오래된 턴은 **예산과 무관하게 항상 요약으로 접는다** — 예산이 남아도 그냥 버리면 30턴 대화에서 정보가 조용히 사라지기 때문. (2) 그래도 초과하면 오래된 유지 턴부터 버리고, (3) 요약을 버리고, (4) 마지막에 사용자 발화를 자른다.
  - 반환값 `PreparedContext`에 `foldedTurnCount`/`droppedTurnCount`/`didDropSummary`/`didTruncateUserText`를 남겨, 나중에 "언제 컨텍스트가 망가졌는지" 로그로 추적할 수 있게 했다.
  - 토큰 카운터를 주입하므로 테스트는 단어 수 카운터를 쓴다(결정적).
- **요약기 주입**: `TurnSummarizing`. 기본은 추출식(`ExtractiveSummarizer`, 창작 없음, 길이 상한 400자). 나중에 모델 요약으로 교체해도 압축 로직은 그대로.
- **`ScenarioRunner`는 실패를 삼킨다**: 한 턴이 실패하면 `completed=false` + `errorMessage`로 기록하고 다음 시나리오로 넘어간다. 20개 중 몇 개가 끝까지 갔는지가 측정값이라 첫 에러에서 멈추면 안 된다.
- **JSONL 선택 이유**: 30분 세션이 중간에 죽어도 이미 쓴 줄은 읽을 수 있다. `kind` 필드로 시나리오/턴 지연 레코드를 구분.
- **시나리오 20개**: 주제 10개는 TASKS.md 예시 그대로, 10개는 일상 확장(카페, 호텔, 대중교통, 직장, 영화, 배달, 헬스장, 은행, 이사, 생일). 사용자 발화에 의도적 문법 실수 포함(`I am work at...`, `I call to ask...`, `What time is the movie start?` 등) — 초중급 학습자 수준 재현.

## 3. 실행한 명령과 실제 출력

### `cd Package/PocketTalkCore && swift test`

```
Test Suite 'All tests' passed at 2026-10-26 22:54:18.633.
	 Executed 32 tests, with 0 failures (0 unexpected) in 0.023 (0.026) seconds
```

테스트 구성과 실제 통과 여부:

| 스위트 | 개수 | 커버하는 완료 조건 |
| --- | --- | --- |
| `ContextManagerTests` | 9 | 예산 초과 없음(20/50/100/250/600 토큰), 요약 후 최근 N턴 유지, 이전 요약 승계, 사용자 발화 잘림, 요약 폐기 순서 |
| `WordErrorRateTests` | 9 | 치환/삽입/삭제, 대소문자·구두점·아포스트로피 정규화, 빈 정답/빈 인식 (5개 이상 요구 충족) |
| `ScenarioRunnerTests` | 5 | **20개 시나리오 전체 완주(Mock)**, 실패 기록, 컨텍스트 접힘, scenarios.json 유효성 |
| `ResultLoggerTests` | 3 | JSONL 1줄 1레코드, 날짜 ISO8601 왕복, 재오픈 시 append |
| `MockLanguageModelClientTests` | 2 | 응답 순환, `{user}` 치환, 빈 스크립트 오류 |
| `ScenarioSetValidationTests` | 4 | 중복 id, 3~5턴 규칙, 빈 세트, snake_case 디코딩 |

### 첫 실행에서의 실패 (수정 내역)

1차 `swift test`는 컴파일 실패:

```
error: instance method 'lock' is unavailable from asynchronous contexts;
Use async-safe scoped locking instead
```

`MockLanguageModelClient.respond`가 async 안에서 `NSLock.lock()`을 직접 호출해서 발생. 잠금을 동기 헬퍼(`nextReply`)로 옮겨 해결하고 재실행 → 위 32개 통과.

## 4. 통과 / 실패 / 미실행

| 항목 | 결과 |
| --- | --- |
| `swift test` (32 tests) | **통과** (실행 로그 위) |
| ContextManager 예산 보장 | 통과 (테스트 5개 예산 구간) |
| 요약 후 최근 N턴 유지 | 통과 |
| WER 5케이스 이상 | 통과 (9개) |
| Mock으로 20 시나리오 완주 | 통과 |
| `eval/scenarios.json` 20개 | 통과 (테스트에서 로드·검증) |
| `eval/system_prompt.md` | 작성 완료 (내용 검수는 사람 몫) |
| iOS 시뮬레이터 빌드 | **미실행** — xcodegen 미설치로 앱 프로젝트 생성 불가(M2) |
| Apple 온디바이스 호출 | **미실행** — M3, 실기기 필요 |

## 5. UNVERIFIED

- 없음 (M1 범위 코드는 전부 실행해서 통과 확인). Apple API를 쓰지 않았으므로 UNVERIFIED 표시 대상 없음.

## 6. 사람이 할 다음 단계

1. `eval/scenarios.json`의 20개 시나리오를 훑고 어색한 것 교체 (TASKS.md §1 [HUMAN]).
2. `eval/system_prompt.md`의 페르소나/난이도가 의도와 맞는지 확인.
3. xcodegen 설치 여부 결정 → 설치되면 M2(앱 골격) 진행.

## 7. 추기 — 시나리오 20개 사람 검수 (TASKS.md §1 [HUMAN])

- 2026-10-26, 사용자 확인: "어색하지 않아. 통과!"
- 교체 없이 `eval/scenarios.json` 20개 그대로 사용한다.
