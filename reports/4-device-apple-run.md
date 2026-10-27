# §4 아이폰 온디바이스 실측 — 실행 기록

- 실행일: 2026-10-27 00:48 (Asia/Seoul)
- 기기: iPhone 16 (iPhone17,3), **iOS 27.0.1 (24A446)**, Developer Mode 활성
- 모델: Apple 온디바이스 (Foundation Models), Apple Intelligence + Siri 영어 설정 후 **사용 가능**
- 결과: **20개 시나리오 중 19개 완료**(1건 가드레일 거부). 모델 지연 중앙값 **1,433ms**.

## 1. 이전에 0 토큰이던 이유

Apple Intelligence가 꺼져 있을 때는 `SystemLanguageModel.default.availability`가
`unavailable(...)`이고 `contextSize`가 **0**으로 표시됐다. 사용자가 Siri를 영어로 바꾸고
Apple Intelligence를 켠 뒤에는:

| 항목 | 시뮬레이터 | **실기기(iPhone 16, iOS 27.0.1)** |
| --- | --- | --- |
| 가용성 | 사용 가능 | **사용 가능** |
| 모델 컨텍스트 | 8,192 | **4,096** |
| 앱 예산 (context − 512) | 7,000 | **3,584** |

즉 기기의 컨텍스트는 4096이다. 시뮬레이터(8192)보다 작으므로, **기기에서 30턴을 그대로 유지하는 것은 불가능**하다
(34턴 = 약 3,000토큰 + 출력 → 예산 3,584에서 아슬아슬). §5의 `recentTurns 64` 정책은 기기에서 일부 접기가 필요하다.

## 2. 실행 방법 (UI 테스트 러너 대신)

이 기기는 무료 개발자 프로파일 앱 슬롯이 3개로 가득 차서(`KeyVault`, `KeyVaultUITests-Runner`, `PocketTalkSpike`)
UI 테스트 러너를 추가 설치할 수 없었다(`MIFreeProfileValidatedAppTracker`:

> This device has reached the maximum number of installed apps using a free developer profile

그래서 앱에 `--autorun-apple` 실행 인자를 추가하고, Mac에서 원격 실행했다.

```sh
xcrun devicectl device install app --device 00008140-001243C93A3A801C <PocketTalkSpike.app>
xcrun devicectl device process launch --device 00008140-001243C93A3A801C --terminate-existing \
  dev.pockettalk.spike -- --autorun-apple
xcrun devicectl device capture screenshot --device 00008140-001243C93A3A801C --destination /tmp/device-run.png
xcrun devicectl device copy from --device 00008140-001243C93A3A801C \
  --domain-type appDataContainer --domain-identifier dev.pockettalk.spike \
  --source Documents/results --destination /tmp/device-results
```

이 방식은 M4의 반복 실행에도 그대로 쓸 수 있다(사람이 화면을 탭할 필요 없음).

## 3. 결과 (`eval/results/apple_ondevice-device.jsonl`)

| 항목 | 값 |
| --- | --- |
| 완료 | **19 / 20** |
| 실패 | `sc18_bank` — `May contain unsafe content` (시뮬레이터와 **동일 재현**) |
| 턴 수 | 77 |
| 지연 p50 / p90 / p95 / max | **1,433ms** / 1,646ms / 1,692ms / 5,602ms |
| 1,500ms 초과 턴 | **23 / 77 (30%)** |
| 실측 입력 토큰 | 중앙값 316, 최대 386 |
| 실측 출력 토큰 | 평균 17 |
| 캐시 입력 토큰 | **0** (매 턴 새 세션) |
| contextSize | **4,096** |

## 4. 판정에 미치는 영향

- **지연 기준("발화 종료 → AI 음성 시작 1.5초")이 빠듯하다.** 지금 수치는 모델 단독 지연이고
  중앙값이 이미 1,433ms다. 여기에 ASR 마무리 + TTS 시작이 더해진다. §6 라이브 세션에서
  `utteranceEndToAudioStartMilliseconds`로 실제 값을 재야 한다.
- **가드레일이 기기에서도 재현됐다**(2회 관측). `sc18_bank`는 "은행/돈" 맥락에서 거부된다.
  학습 시나리오로 쓰려면 문구를 바꾸거나(예: "계좌를 만들고 싶어요" 대신 다른 주제) 실패 사례로 남긴다.
- **캐시 입력이 0**이라 매 턴 프리필을 다시 한다. 첫 턴 5.6초가 그 증거다.

## 5. 통과 / 미실행

| 항목 | 결과 |
| --- | --- |
| 실기기 설치·실행 | **통과** |
| Apple Intelligence 사용 가능 확인 | **통과** (4096 토큰) |
| 시나리오 20개 실행 | **통과** (19/20, 가드레일 1건) |
| 실측 토큰/지연 로깅 | **통과** |
| 라이브 1턴(마이크→모델→TTS) | **미실행** — 사람이 기기에서 |
| ASR 30문장 | **미실행** — 사람이 기기에서 |
| 30분 세션 | **미실행** — 사람이 기기에서 |

## 6. UNVERIFIED

- TASKS.md는 기기를 iOS 27.0.2로 적었지만 실제는 **27.0.1**이다.
- 기기에서 `contextSize`는 4096으로 나왔지만, Apple Intelligence 설정 변경 전에는 0이었다.
  모델 준비 상태에 따라 값이 달라지는지 추가 확인하지 않았다.
- UI 테스트를 기기에서 돌리지 못했으므로(무료 프로파일 슬롯 제한) 화면 탭 경로는 시뮬레이터에서만 검증됐다.
