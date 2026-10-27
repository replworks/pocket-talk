# Pocket Talk — 온디바이스 스파이크

> 아이폰 온디바이스 모델로 초중급 영어 회화 연습이 되는지 **숫자로 확인하는 측정 도구**입니다.
> 제품이 아닙니다. 기준은 [`.replworks/TASKS.md`](.replworks/TASKS.md).

## 한눈에

| 측정 | 결과 |
| --- | --- |
| 대화 품질 | 클라우드 대비 **63%** (12/19) — 기준 70%에 미달 |
| 문법·사실성 | 정확성 4.58/5, 지어냄 0% — **양호** |
| 음성 인식 | WER **4.8%** (어휘 기준 2.7%) — 양호 |
| 지연 | 발화 종료 → 음성 시작 **2,545ms** — 1.5초 기준 초과 |
| 컨텍스트 | 34턴에서 사실 8/8 유지 |

한 줄 결론: **문법은 되고, 지연이 안 됩니다.** 캐시·프롬프트 최적화로도 1.7초 아래로 내려가지 않았습니다.

## 구성

- `Package/PocketTalkCore` — 모델 호출을 `LanguageModelClient` 뒤에 둔 순수 로직 (테스트 32개)
- `App/PocketTalkSpike` — 시나리오 / ASR / 라이브 3탭 측정 앱 (SwiftUI + XcodeGen)
- `eval/` — 시나리오 20개, 블라인드 평가 시트, WER·집계 스크립트, 원본 결과
- `reports/` — 마일스톤별 기록과 통합 리포트

## 실행

```sh
cd Package/PocketTalkCore && swift test          # 코어 테스트

cd App/PocketTalkSpike && xcodegen generate      # 앱 빌드 (시뮬레이터)
xcodebuild -scheme PocketTalkSpike \
  -destination "platform=iOS Simulator,name=iPhone 16 (iOS 27),OS=27.0" build
```

실기기 측정은 `--autorun-apple` 인자로 원격 실행하고 JSONL을 회수합니다.
자세한 명령은 [AGENTS.md](AGENTS.md), 결과는 [reports/REPORT.md](reports/REPORT.md).

## 더 보기

- [reports/REPORT.md](reports/REPORT.md) — 전체 수치·근거·한계
- [eval/verdict.md](eval/verdict.md) — 판정 초안 (결론은 사람 몫)
- [AGENTS.md](AGENTS.md) — 작업 규칙과 실기기 실행법
