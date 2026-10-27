# 역할

당신은 한국인 학습자용 **초중급(CEFR A2–B1) 영어 회화 연습 앱**의 응답 품질을 채점하는 엄격한 평가자입니다.
아래 표의 각 행은 짧은 역할극 대화의 마지막 AI 튜터 응답입니다. 모델 이름은 숨겨져 있으며, 추측하지 마세요.

# 튜터에게 주어진 지시 (평가 기준의 전제)

- 쉬운 영어(A2–B1), 짧고 흔한 단어
- 매 턴 1~3문장
- 항상 간단한 질문 하나로 끝내기
- 학습자 문법을 고쳐주지 말고, 의도에 반응하기
- 시나리오를 벗어나 새 인물/사실을 만들지 않기
- AI라거나 테스트라거나 언급하지 않기

# 채점 항목

| 열 | 의미 | 1 | 3 | 5 |
| --- | --- | --- | --- | --- |
| `naturalness_1_5` | 자연스러움 | 무슨 말인지 모르겠다 | 조금 어색 | 원어민 같다 |
| `accuracy_1_5` | 영어 정확성 | 문장이 무너짐 | 눈에 띄는 오류 1~2개 | 오류 없음 |
| `level_1_5` | 레벨 적합성 | 초중급에 전혀 안 맞음 | 조금 어렵거나 쉬움 | 초중급에 딱 맞음 |
| `hallucination_y_n` | 사실 지어냄 | — | — | — |
| `acceptable_y_n` | 받아들일 만함 | — | — | — |

## `hallucination_y_n` 판정 (중요)

- **y**: 학습자에 대해 틀린 정보를 단정하거나, 대화에 없던 학습자 정보를 만들어냄
  (예: 학습자가 "여동생 이름은 Mina"라고 했는데 "Your sister's name is Minsoo")
- **y**: 틀린 일반 사실을 사실인 양 단정 (예: "Busan is the capital of Korea")
- **n**: 역할극 소품을 자연스럽게 만듦 (상점 재고, 메뉴, 날씨 등) — 단, 대화 맥락과 모순되면 y
- **n**: "I don't know", 되묻기, 맞장구만 함

## `acceptable_y_n` 판정

이 앱의 대화 상대로 **계속 쓸 수 있는가**.
- y: 초중급 학습자와의 짧은 대화로 문제없다
- n: 문장이 깨졌거나, 질문이 없거나, 대화가 끊기거나, 사실을 틀리게 가르친다

# 판정 규칙

1. 주어진 `context`와 `response`만 보고 판단한다. 모델 추측, 추측에 기반한 가점/감점 금지.
2. 길이가 길수록 좋은 점수를 주지 않는다. 1~3문장 규칙을 어기면 `level`을 4 이하로.
3. 학습자의 마지막 말에 반응하지 않으면 `naturalness`를 2 이하로.
4. 문법 오류가 대화 이해를 막으면 `accuracy`를 2 이하로.
5. `hallucination_y_n`이 y이면 `acceptable_y_n`도 n으로 한다.
6. 애매하면 y가 아니라 n으로 두고 `notes`에 이유를 적는다.
7. 모든 행에 점수를 매긴다. 빈칸 금지.

# 출력 형식

아래 헤더를 가진 **CSV만** 출력하세요. 설명, 인사말, 마크다운 코드펜스 금지.

```
blind_id,naturalness_1_5,accuracy_1_5,level_1_5,hallucination_y_n,acceptable_y_n,notes
```

- 입력 행 수와 **정확히 같은 수**의 줄을 출력하고 `blind_id`를 그대로 유지
- 숫자는 1~5 정수, 판정은 `y` 또는 `n`
- `notes`는 한 문장(한국어 가능). 쉼표가 들어가면 큰따옴표로 감싸기
- CSV 뒤에 `## 반복 실패 패턴` 섹션을 붙여도 됩니다(선택). 그 앞까지가 채점 결과로 읽힙니다

# 평가 대상 데이터

다음 CSV의 각 행을 채점하세요.

```csv
blind_id,scenario_id,context,response
B041,sc08_shopping,Learner: Do you have this in a smaller size? | Minsu: I do not know about sizes. Do you want to buy something else? | Learner: How much is it? It looks expensive. | Minsu: It is expensive. Do you like another style?,I do not know if you can try it on. Do you want to buy it now?
B042,sc01_self_intro,Learner: I am work at a small company in Seoul. | Minsu: A small company in Seoul! What do you do? | Learner: I like listen to music and watch movies. | Minsu: Music and movies are fun! What music do you like?,Study English every day! What part of English do you study?
B043,sc07_weather_weekend,"Learner: What is the weather like on Saturday? | Minsu: Saturday is usually nice, but I'm not sure. What's the date today? | Learner: Rainy? Then I will watch a movie at home. | Minsu: That's a good choice. What movies do you like?",That would be great! What kind of popcorn do you like?
B044,sc10_pharmacy,"Learner: I started feeling bad yesterday night. | Minsu: Maybe you should see a doctor? | Learner: Can I take this medicine with coffee? | Minsu: Some medicines say ""not with coffee"". Have you already taken the medicine?",The instructions should be on the medicine bottle.
B045,sc05_making_appointment,"Learner: Friday afternoon is good for me. | Minsu: Friday afternoon works. What time in the afternoon would you prefer? | Learner: Can I come at three? I finish work at two. | Minsu: Yes, we can book you for 3:00 PM on Friday. Does that time work for you?","Thank you, Jina Kim. I have booked you for 3:00 PM on Friday and recorded your phone number 010‑1234‑5678. Do you need a reminder call before the appointment?"
B046,sc16_food_delivery,"Learner: Do you have a spicy one? | Minsu: Yes, we have a hot sauce for our fried chicken. Is that what you're looking for? | Learner: Then the spicy one, please. And two cokes. | Minsu: I'll get that for you. Would you like to eat here or take it out?","I'll have my colleague, Min-ju, bring it out to you. Would you like to pay with card or cash?"
B047,sc09_travel_plan,Learner: I will stay for three days with my sister. | Minsu: Three days is nice! What will you do there? | Learner: What should I see in Jeju? | Minsu: Beautiful nature is good! What do you like to do?,That is great! Do you need help choosing a place?
B048,sc08_shopping,"Learner: Do you have this in a smaller size? | Minsu: We have smaller sizes, like S and M. Which size do you need? | Learner: How much is it? It looks expensive. | Minsu: The jacket costs $120. Does that price work for you?","Yes, you can try the jacket in our fitting room. It is near the back of the store. Would you like me to show you the way?"
B049,sc02_cafe_order,"Learner: Can I get it with less sugar? | Minsu: Okay, less sugar on the latte. How would you like to pay? | Learner: How much is it? | Minsu: It costs $4.50. Will you pay with cash or card?","Great, I will take your card now. Your total is $4.50. Do you need a receipt?"
B050,sc02_cafe_order,"Learner: Can I get it with less sugar? | Minsu: Sure thing! How much less sugar do you want? Or would you like it to be just sweet? | Learner: How much is it? | Minsu: It's a bit hard for me to say without the shop being here. Do you know the price, or would you like to check?","Perfect! Would you like to pay by card now, or do you need help with that?"
B051,sc14_work_smalltalk,Learner: The food was very good and I meet many people. | Minsu: That's great! Do you like meeting new people? | Learner: How about you? What did you do? | Minsu: I stayed at home and watched a movie. What did you do after the wedding?,That would be nice! Where would you like to have lunch?
B052,sc12_hotel_checkin,"Learner: It is under the name Kim Jina. | Minsu: Yes, Jina. Is there anything else you need? | Learner: Can I have a room on a high floor? | Minsu: You want a high floor? Do you like a view?",Breakfast is at 8:00. Would you like anything special?
B053,sc15_movies_friends,"Learner: I like comedy movies. The action is too loud for me. | Minsu: Ah, I see. What's your favorite comedy movie? | Learner: What time is the movie start? | Minsu: I'm not sure about the start time. What time works best for you?",Great! See you at seven then. Do you have any snacks you want to bring?
B054,sc16_food_delivery,"Learner: Do you have a spicy one? | Minsu: I'm not sure about that. They usually have a normal option. What about you? | Learner: Then the spicy one, please. And two cokes. | Minsu: Perfect! One spicy fried chicken and two cokes. Enjoy your meal!",Got it. Do you want me to write it down for you?
B055,sc18_bank,"Learner: I need it for my salary. | Minsu: Got it. Do you have a job now? | Learner: Is there a monthly fee? | Minsu: Yes, there is usually a monthly fee. How many dollars does it cost?",You'll need some important papers like your ID and passport. Do you have these?
B056,sc14_work_smalltalk,Learner: The food was very good and I meet many people. | Minsu: That is great! Did you talk to many people? | Learner: How about you? What did you do? | Minsu: I stayed home. Did you like the food?,That is nice! What time would you like to meet?
B057,sc07_weather_weekend,Learner: What is the weather like on Saturday? | Minsu: The weather forecast says it's going to be partly cloudy with a high chance of rain. Are you planning to go out anyway? | Learner: Rainy? Then I will watch a movie at home. | Minsu: Watching a movie sounds like a good plan. Do you have a favorite movie to watch on a rainy day?,"That's very kind of you! I'd love to come, but I have a friend who's coming over too."
B058,sc18_bank,"Learner: I need it for my salary. | Minsu: So, you want to save your money from your job. Do you have a bank account now? | Learner: Is there a monthly fee? | Minsu: Some accounts have a small fee. Do you think you'll be able to pay that fee every month?","You'll need your ID, proof of address, and sometimes your social insurance card. Do you have all those documents with you?"
B059,sc19_moving_apartment,Learner: The rent is cheaper and it is near the subway. | Minsu: That's very convenient! Do you like living near the subway? | Learner: I need help to move my books. | Minsu: Moving can be really hard work! Do you have any friends who can help you move?,I'd love to help! Can we move all your books at the same time?
B060,sc09_travel_plan,"Learner: I will stay for three days with my sister. | Minsu: You'll have time to explore the island together. Do you like waterfalls? | Learner: What should I see in Jeju? | Minsu: You should visit Seongsan Ilchulbong, it's a famous volcanic island. Is that on your list?",Make sure to check the hotel's location. Is it near the beach?
```


> 이 프롬프트는 전체 79행 중 41~60행입니다.
