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
B001,sc02_cafe_order,"Learner: Can I get it with less sugar? | Minsu: I can make it with less sugar for you. Would you prefer it with vanilla syrup instead? | Learner: How much is it? | Minsu: The large iced latte is 5,000 won. Would you like to pay with card or cash?",I'll just need to swipe your card. Do you have an account here or is it a new card?
B002,sc03_restaurant_order,"Learner: Is it very spicy? | Minsu: Not spicy at all! They usually have mild sauce. Would you like any sides with it? | Learner: Then I will take it. And one cola, please. | Minsu: Perfect! Your cola will be ready soon. Enjoy your meal!",You're welcome! Have a nice meal! How was your day so far?
B003,sc08_shopping,"Learner: Do you have this in a smaller size? | Minsu: We have some smaller sizes, but I'm not sure if they're available. Can you tell me what's your usual jacket size? | Learner: How much is it? It looks expensive. | Minsu: It's a bit pricier, but it's a good quality jacket. It's $80, but we have a sale right now. Do you think you'll buy it today?",You can definitely try it on. I'll help you find a fitting room. Will you need to pay for the jacket while you try it on?
B004,sc04_directions,"Learner: How long does it take on foot? | Minsu: It can take a while, about 15 to 20 minutes. Do you have time to walk? | Learner: Is there a bus? I am tired. | Minsu: There might be a bus nearby. Would you like to take a bus instead?",You're welcome! Have a nice day yourself!
B005,sc16_food_delivery,"Learner: Do you have a spicy one? | Minsu: Yes, we have spicy. Do you want any extra sauce? | Learner: Then the spicy one, please. And two cokes. | Minsu: Spicy one, I hear. Do you want any extra pickles?","25 Maple Street, apartment 302. I understand. Do you want any napkins?"
B006,sc02_cafe_order,"Learner: Can I get it with less sugar? | Minsu: Less sugar, yes. Do you want to add any flavor? | Learner: How much is it? | Minsu: I do not know the price. Do you want to try another flavor?","Card payment, okay. Do you want to try a different drink?"
B007,sc13_public_transport,Learner: Which line should I take? | Minsu: You should take the Line 1. It goes right to City Hall. | Learner: How many stops is it? | Minsu: It's about four stops. Are you ready to swipe your card?,You can transfer at the next stop. There's a transfer station there.
B008,sc14_work_smalltalk,Learner: The food was very good and I meet many people. | Minsu: I'm glad you liked the food and met many people. What was your favorite dish? | Learner: How about you? What did you do? | Minsu: I stayed at home and watched a movie. Did you enjoy dancing at the wedding?,"Sure, I would love to have lunch with you! Where would you like to eat?"
B009,sc19_moving_apartment,"Learner: The rent is cheaper and it is near the subway. | Minsu: That's great to hear. What are you planning to do in your new house? | Learner: I need help to move my books. | Minsu: Oh, moving books can be a lot. Do you have any specific places in the new house you're planning to put your books?","Sure, I can help on Saturday. What time works best for you?"
B010,sc03_restaurant_order,"Learner: Is it very spicy? | Minsu: No, it is not very spicy. It has a mild flavor. Would you like a drink with it? | Learner: Then I will take it. And one cola, please. | Minsu: Great, I have one chicken pasta and one cola. Your order will be ready soon. Anything else you would like?",You're welcome. Your food will be ready in a few minutes. Is there anything else I can do for you?
B011,sc03_restaurant_order,"Learner: Is it very spicy? | Minsu: Not very spicy, just a little bit. Is that okay for you? | Learner: Then I will take it. And one cola, please. | Minsu: I'll go put that order in for you. How much will it cost?","You're welcome, I'll get your food ready. How long will it take?"
B012,sc03_restaurant_order,"Learner: Is it very spicy? | Minsu: I do not know. Do you like spicy food? | Learner: Then I will take it. And one cola, please. | Minsu: One cola is fine. Would you like to sit by the window?",You are welcome! Do you need anything else now?
B013,sc10_pharmacy,"Learner: I started feeling bad yesterday night. | Minsu: Oh, I see. Did anything make you feel worse? | Learner: Can I take this medicine with coffee? | Minsu: I do not know. Do you have the medicine with you?",I do not know. Do you have the instructions?
B014,sc12_hotel_checkin,"Learner: It is under the name Kim Jina. | Minsu: Thank you, Ms. Kim. May I see your ID, please? | Learner: Can I have a room on a high floor? | Minsu: We will try to give you a high‑floor room if it is free. I will check now. Do you need any extra pillows?",Breakfast is served from 7:00 am to 10:00 am in the restaurant. Would you like a wake‑up call?
B015,sc15_movies_friends,"Learner: I like comedy movies. The action is too loud for me. | Minsu: A nice comedy is ""Padding Pad"". It has gentle jokes and no loud fights. Would you like to watch that? | Learner: What time is the movie start? | Minsu: The movie starts at 7:00 PM. Does that time work for you?",Great! I will be there at 7:00 PM. Do you want to get popcorn before the film?
B016,sc01_self_intro,"Learner: I am work at a small company in Seoul. | Minsu: Seoul is a busy city, but I've heard it's also very exciting. What kind of work do you do at your company? | Learner: I like listen to music and watch movies. | Minsu: Music and movies can be very relaxing. Do you have a favorite K-pop group or movie?",Studying English is very helpful for your job. How long have you been studying English every day?
B017,sc10_pharmacy,Learner: I started feeling bad yesterday night. | Minsu: That sounds uncomfortable. Have you taken any medicine yet? | Learner: Can I take this medicine with coffee? | Minsu: I don’t know which medicine you have. It’s safest to read the label or ask a pharmacist if coffee is okay. What is the name of the medicine?,I don’t know the exact dosage for that medicine. Please check the label or ask a pharmacist for the right amount. What is the name of the medicine?
B018,sc01_self_intro,Learner: I am work at a small company in Seoul. | Minsu: That's great. What do you like to do in your free time? | Learner: I like listen to music and watch movies. | Minsu: That sounds fun. What kind of music do you like?,That's good to hear. Do you find it helpful?
B019,sc05_making_appointment,"Learner: Friday afternoon is good for me. | Minsu: Friday afternoons are busy. Do you have a specific problem with your teeth, or just a check-up? | Learner: Can I come at three? I finish work at two. | Minsu: Three o'clock is a good time. Do you live close to the clinic?","Nice to meet you, Jina. I'll make a note of your appointment. How many people will be coming with you to the appointment?"
B020,sc06_hobbies,"Learner: Last weekend I go to Bukhansan with my friend. | Minsu: Bukhansan is a beautiful mountain. Did you guys see any interesting views or wildlife from the top? | Learner: It was very hard but the view was amazing. | Minsu: I can imagine it was challenging, but the view must have been worth it. Was your friend also a good hiker?",I like to spend time with family or read a book. Do you have any plans for this weekend?
```


> 이 프롬프트는 전체 79행 중 1~20행입니다.
