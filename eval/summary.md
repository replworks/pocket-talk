# 블라인드 평가 집계 (TASKS.md §2)

- 채점된 행: 79 / 79
- 채점자: AI 채점 (단일 모델, 20행은 프롬프트 2회 실행으로 중복 채점)
- 모델 수: 4

## 모델별 평균 (1~5)

| 모델 | 문장 수 | 자연스러움 | 영어 정확성 | 레벨 적합성 | 사실 지어냄 비율 | 받아들일 만함 비율 |
| --- | --- | --- | --- | --- | --- | --- |
| apple_ondevice | 19 | 2.79 | 4.58 | 4.89 | 0% | 63% |
| gpt-oss-120b-cloud | 20 | 3.65 | 4.85 | 4.50 | 0% | 95% |
| llama3.2-3b | 20 | 2.90 | 4.50 | 4.45 | 0% | 55% |
| qwen2.5-3b | 20 | 3.15 | 4.75 | 4.85 | 5% | 65% |

## 클라우드 기준선 대비 '받아들일 만함' 비율

> 기준선 모델 이름은 `--baseline` 없이 실행했으므로 표의 비율을 직접 비교한다.

| 모델 | 받아들일 만함 비율 |
| --- | --- |
| apple_ondevice | 63% |
| gpt-oss-120b-cloud | 95% |
| llama3.2-3b | 55% |
| qwen2.5-3b | 65% |

## 실패 사례 상위 10

| blind_id | 모델 | 시나리오 | 점수 합 | 응답 |
| --- | --- | --- | --- | --- |
| B001 | llama3.2-3b | sc02_cafe_order | 9 | I'll just need to swipe your card. Do you have an account here or is it a new card? |
| B037 | gpt-oss-120b-cloud | sc18_bank | 9 | You need a photo ID (like a passport or driver’s license), a recent utility bill or lease for your address, and your emp |
| B003 | llama3.2-3b | sc08_shopping | 10 | You can definitely try it on. I'll help you find a fitting room. Will you need to pay for the jacket while you try it on |
| B019 | llama3.2-3b | sc05_making_appointment | 10 | Nice to meet you, Jina. I'll make a note of your appointment. How many people will be coming with you to the appointment |
| B058 | llama3.2-3b | sc18_bank | 10 | You'll need your ID, proof of address, and sometimes your social insurance card. Do you have all those documents with yo |
| B068 | llama3.2-3b | sc15_movies_friends | 10 | I'll meet you at the theater at 7. What time should we grab dinner before the movie? |
| B011 | llama3.2-3b | sc03_restaurant_order | 11 | You're welcome, I'll get your food ready. How long will it take? |
| B016 | llama3.2-3b | sc01_self_intro | 11 | Studying English is very helpful for your job. How long have you been studying English every day? |
| B059 | llama3.2-3b | sc19_moving_apartment | 11 | I'd love to help! Can we move all your books at the same time? |
| B062 | llama3.2-3b | sc11_phone_call | 11 | Sounds good. I'll see you then. Do you need me to remind you anything else? |
