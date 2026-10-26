# AGENTS.md

이 저장소는 Pocket Talk의 **온디바이스 타당성 스파이크**다. 제품이 아니라 측정 도구를 만든다.
작업 목록과 완료 조건은 `TASKS.md`가 기준이다. 작업 전에 `TASKS.md`를 먼저 읽는다.

## 절대 규칙

1. **실행하지 않은 것은 쓰지 않는다.** 직접 돌려서 출력을 본 것만 "통과"라고 보고한다. 못 돌린 건 "미실행"이라고 적는다.
2. **사람에게 테스트 방법을 물으면 지어내지 않는다.** 절차를 모르면 "모름, 확인 필요"라고 답하고 근거 문서나 명령을 먼저 찾는다.
3. **API를 기억으로 쓰지 않는다.** FoundationModels, Speech(SpeechAnalyzer 계열), AVFoundation은 iOS 27 SDK에서 바뀐 부분이 있을 수 있다. 쓰기 전에 설치된 SDK의 `.swiftinterface`나 헤더에서 시그니처를 확인하고, 확인 못 한 코드는 `// UNVERIFIED`로 표시한다.
4. **스코프를 넓히지 않는다.** TASKS.md에 없는 기능(아바타, 스트릭, 배지, 온보딩, 설정 화면 등)을 만들지 않는다.
5. **철학 문장은 구현 지시가 아니다.** 문서의 비전/방향성 문장을 근거로 기능을 상상해서 추가하지 않는다. 불명확하면 질문하거나 TODO로 남긴다.

## 에이전트 범위와 사람 범위

- **에이전트가 검증 가능**: 순수 로직(Swift Package), 유닛테스트, 시뮬레이터 빌드, 평가 스크립트, 집계, 문서
- **사람만 검증 가능**: 실기기 설치/서명, 음성 인식 정확도, 실제 음성 지연, 발열/배터리, 블루투스/이어폰, 응답 품질 체감, 블라인드 평가
- 사람 범위 작업은 코드와 **체크리스트/기록 양식**까지만 만든다. 결과를 추정해서 채우지 않는다.
- Foundation Models는 시뮬레이터에서 동작하지 않을 수 있다(Mac의 Apple Intelligence 지원 여부에 따름). 시뮬레이터에서 안 돌면 실패로 숨기지 말고 "시뮬레이터 미지원/미실행"으로 보고한다.

## 프로젝트 구조

- `Package/PocketTalkCore`: 순수 로직. 모델 호출은 `LanguageModelClient` 프로토콜 뒤에 둔다.
- `App/PocketTalkSpike`: 얇은 SwiftUI 앱. `project.yml`(XcodeGen)이 원본이다.
- `.xcodeproj`는 생성물이다. 직접 편집하지 않고 `xcodegen generate`로 만든다.
- `eval/`: 시나리오, 스크립트, 결과, 평가 시트.

## 명령어

M0에서 확정해 아래에 기록한다.

```sh
# 환경 확인
xcodebuild -version
xcrun simctl list devices available

# 시뮬레이터 이름 (M0에서 채움)
DESTINATION="platform=iOS Simulator,name=<M0에서 확인한 iPhone 시뮬레이터>"

# 코어 로직 테스트
cd Package/PocketTalkCore && swift test

# 앱 프로젝트 생성 및 빌드
xcodegen generate
xcodebuild -scheme PocketTalkSpike -destination "$DESTINATION" build
```

`swift test`가 iOS 전용 코드 때문에 안 되면 `xcodebuild test -scheme PocketTalkCore -destination "$DESTINATION"`으로 대체하고 그 사실을 이 파일에 기록한다.

## 보고 형식

작업을 마칠 때마다 다음을 남긴다.

- 실행한 명령과 실제 출력 요약
- 통과/실패/미실행 구분
- `UNVERIFIED` 항목 목록
- 사람이 해야 할 다음 단계
