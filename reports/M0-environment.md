# M0 환경 확인 — 실행 기록

- 실행일: 2026-10-26 (Asia/Seoul)
- 작업 디렉터리: `/Users/cable8mm/Swifts/pocket-talk`
- 실행자: 에이전트 (터미널 실행, 출력 직접 확인)

## 1. 실행한 명령과 실제 출력

### `xcodebuild -version`

```
Xcode 27.1
Build version 27A9275
```

### `swift --version`

```
swift-driver version: 1.168.6 Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
Target: arm64-apple-macosx27.0.0
```

### `sw_vers`

```
ProductName:		macOS
ProductVersion:		27.0.1
BuildVersion:		26A434
```

### `xcodebuild -showsdks` (iOS 관련만)

```
iOS SDKs:
	iOS 27.1                      	-sdk iphoneos27.1
iOS Simulator SDKs:
	Simulator - iOS 27.1          	-sdk iphonesimulator27.1
```

### `xcrun simctl list runtimes`

```
iOS 26.3 (26.3.1 - 23D8133) - com.apple.CoreSimulator.SimRuntime.iOS-26-3
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
iOS 27.0 (27.0 - 24A434) - com.apple.CoreSimulator.SimRuntime.iOS-27-0
```

### `xcrun simctl list devices available` (목적지 후보)

iOS 27.0 런타임의 iPhone 기기:

```
-- iOS 27.0 --
    iPhone 18 Pro (B4B40964-EA2A-4E65-9EF3-8D44D2DF794C) (Shutdown)
    iPhone 18 Pro Max (6BE0B681-DE9E-4E90-B399-922E4D09603C) (Shutdown)
    iPhone 17e (9D0CF6B1-7FE1-4B92-B094-CB3215B162A5) (Shutdown)
    iPhone Air (42964175-61A6-44AA-9C64-DC269DE574CD) (Shutdown)
    iPhone 17 (17A35BD4-674B-401C-B468-62A763470EDB) (Shutdown)
    iPhone 16 (iOS 27) (F4E1A84F-D4CB-47D2-871E-EE12659B2F78) (Shutdown)
```

### `xcodegen --version`

```
bash: xcodegen: command not found
xcodegen NOT FOUND
```

`which brew mint` → `/opt/homebrew/bin/brew` (Homebrew 7.0.11), `mint` 없음.
`/opt/homebrew/bin/xcodegen`, `/usr/local/bin/xcodegen` 둘 다 없음.

## 2. DESTINATION 확정

TASKS.md의 테스트 기기(iPhone 16, iOS 27)와 일치하는 시뮬레이터가 iOS 27.0 런타임에 있다.

```sh
DESTINATION="platform=iOS Simulator,name=iPhone 16 (iOS 27),OS=27.0"
```

- 선택 이유: 기기 프로파일이 iPhone 16이고 iOS 27.0 런타임이 설치되어 있다. (배포 타깃 iOS 27.0 + SDK 27.1 조합으로 빌드)
- `AGENTS.md` 명령어 섹션에 위 값을 기록했다.
- **미실행**: 이 DESTINATION으로 실제 `xcodebuild build`를 아직 돌리지 않았다. 프로젝트(XcodeGen) 생성이 M2라서, M2에서 처음 검증한다.

## 3. 통과 / 실패 / 미실행

| 항목 | 결과 |
| --- | --- |
| Xcode 설치·버전 확인 | 통과 (Xcode 27.1, iOS SDK 27.1) |
| Swift 툴체인 확인 | 통과 (Swift 6.4) |
| 시뮬레이터 목록 확인 | 통과 (iOS 26.3 / 26.5 / 27.0 런타임) |
| iPhone 16 시뮬레이터 존재 확인 | 통과 (iOS 27.0 런타임, `iPhone 16 (iOS 27)`) |
| `xcodegen --version` | 처음엔 실패(미설치) → 사용자 승인 후 설치, 2.46.0 확인 |
| M0 완료 조건(모든 출력 기록) | **통과** — 세 명령의 출력을 모두 기록하고 DESTINATION을 AGENTS.md에 넣었다. xcodegen은 아래 §7에서 설치. |

## 4. xcodegen 설치 방법 (사람이 실행하거나 승인 필요)

TASKS.md M0: "`xcodegen --version`(없으면 설치 방법만 안내하고 멈춤)". 아래 중 하나로 설치한다.

```sh
# 방법 1: Homebrew (이미 설치되어 있음)
brew install xcodegen
xcodegen --version

# 방법 2: Mint (mint가 없으므로 먼저 brew install mint)
mint install yonaskolb/XcodeGen
```

- 설치는 사용자 환경 변경이라 에이전트가 임의로 실행하지 않았다. 승인되면 `brew install xcodegen` 실행 후 M2를 진행한다.
- 설치 없이 M2를 진행할 방법은 없다. TASKS.md가 `.xcodeproj` 직접 편집을 금지하고 `project.yml`(XcodeGen)을 원본으로 지정했기 때문.

## 5. UNVERIFIED

- DESTINATION 문자열이 `xcodebuild`에서 실제로 해석되는지 (M2에서 프로젝트 생성 후 검증 예정).
- Xcode 27.1 SDK로 iOS 27.0 시뮬레이터 런타임에 설치·실행되는지.

## 6. 사람이 할 다음 단계

- 없음. xcodegen 설치는 사용자 승인으로 대행했다(§7). 다음은 M2 리포팅 참고.

## 7. 추기 — xcodegen 설치 (TASKS.md "멈춤" 지침 해소)

M0 시점에는 미설치였고, TASKS.md 지침대로 설치 방법만 안내한 뒤 사용자에게 확인했다.
사용자가 "brew install xcodegen 실행 후 M2까지 진행"을 선택해 대행 설치했다.

```
$ brew install xcodegen
✔︎ Bottle Manifest xcodegen (2.46.0)
🍺  /opt/homebrew/Cellar/xcodegen/2.46.0: 38 files, 7.5MB

$ xcodegen --version
Version: 2.46.0
```

이후 M2에서 `project.yml`로 프로젝트를 생성하고 시뮬레이터 빌드·UI 테스트까지 통과했다
(`reports/M2-app-skeleton.md`).
