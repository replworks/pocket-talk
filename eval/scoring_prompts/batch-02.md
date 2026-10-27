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
B021,sc09_travel_plan,"Learner: I will stay for three days with my sister. | Minsu: Three days is a good time. Will you visit the beach or the volcano? | Learner: What should I see in Jeju? | Minsu: You can see Hallasan mountain, Seongsan sunrise peak, and Jeju folk museum. The beaches like Hyeopjae and Jungmun are also nice. Do you like nature or museums more?",I hope you find a comfortable hotel. It is nice to stay near the sea or the city center. Do you prefer a beach view or a quiet place?
B022,sc11_phone_call,Learner: I call to ask about the meeting tomorrow. | Minsu: That sounds good. When is the meeting planned? | Learner: What time does it start? | Minsu: The meeting starts at 10 AM. Is that okay?,Perfect! See you then. Have a great day!
B023,sc07_weather_weekend,"Learner: What is the weather like on Saturday? | Minsu: I don’t know the exact forecast for Saturday. It could be sunny, cloudy, or rainy. Do you prefer sunny or rainy days? | Learner: Rainy? Then I will watch a movie at home. | Minsu: Rainy days are perfect for movies. What kind of movie will you watch?",That sounds fun! I would love to join and eat popcorn. Which movie do you want to watch?
B024,sc04_directions,"Learner: How long does it take on foot? | Minsu: It takes about five minutes to walk there. Is that okay for you? | Learner: Is there a bus? I am tired. | Minsu: Yes, there is a bus that stops near the station. It comes every ten minutes and the ride is only a few minutes. Would you like to know the bus number?",You are welcome. I hope you have a good day. Do you need anything else?
B025,sc13_public_transport,"Learner: Which line should I take? | Minsu: You should take Line 2, it goes to City Hall. Is that okay for you? | Learner: How many stops is it? | Minsu: It's about 5 stops from the city center. Is that a long or short ride for you?",You can transfer at the Busan Station stop. Can you find that stop easily?
B026,sc20_birthday_party,"Learner: What should I bring? Maybe a cake? | Minsu: Cake is nice, but you can bring games. What games do you like? | Learner: Okay, I will buy a small gift for her. | Minsu: That is a good idea. Do you know what kind of gift she likes?","Great, I am happy for you. What game do you want to play?"
B027,sc06_hobbies,"Learner: Last weekend I go to Bukhansan with my friend. | Minsu: That's great! Did you see any special flowers or trees? | Learner: It was very hard but the view was amazing. | Minsu: Wow, amazing! What did you see from the top?","On weekends, I like to watch TV or read a book. What about you?"
B028,sc17_gym_exercise,"Learner: I usually walk, but I want to be stronger. | Minsu: Walking is a good start. You can add some light weights or machines to build strength. Would you like to try weight machines today? | Learner: Do you have a class in the evening? | Minsu: Yes, we have a beginner strength class at 6 pm. It lasts one hour and is easy to follow. Would you like to sign up for that class?","The monthly fee is $45, which includes all classes and gym use. You can pay at the front desk or online. Would you like to join now?"
B029,sc08_shopping,Learner: Do you have this in a smaller size? | Minsu: I'm not sure about that. Do you prefer a smaller size? | Learner: How much is it? It looks expensive. | Minsu: It seems expensive. Have you checked if they have it in a smaller size?,Sure thing! Can you try it on and see if you like it?
B030,sc20_birthday_party,"Learner: What should I bring? Maybe a cake? | Minsu: That's a great idea, a cake would be perfect! What kind of cake do you think Sara likes best? | Learner: Okay, I will buy a small gift for her. | Minsu: That's a thoughtful gesture. Is Sara's birthday party a surprise for her?",I'll see you then. Are you planning on wearing something nice for the party?
B031,sc05_making_appointment,Learner: Friday afternoon is good for me. | Minsu: Friday afternoon is good. Do you have any questions? | Learner: Can I come at three? I finish work at two. | Minsu: Three is good for you. Is there anything else you need?,"Hello, Jina Kim. Your number is 010-1234-5678. Do you need help with anything else?"
B032,sc19_moving_apartment,Learner: The rent is cheaper and it is near the subway. | Minsu: Living near the subway is very convenient. It’s great that the rent is lower too. What do you like most about the new place? | Learner: I need help to move my books. | Minsu: You can pack the books in small boxes so they are not too heavy. Put a pillow or soft cloth at the bottom of each box to protect the books. Do you have any boxes ready for the books?,"I’m sorry, I can’t be there in person, but I can give you some tips for moving your books. What kind of books do you have that need packing?"
B033,sc04_directions,"Learner: How long does it take on foot? | Minsu: It should take about 5-7 minutes to walk from here to the train station on foot. Are you in a hurry? | Learner: Is there a bus? I am tired. | Minsu: Yes, there's a bus stop just around the corner, about 2 minutes walk from here. Would you rather take the bus or walk?","You're welcome, have a good day too! Do you have your ticket for the train?"
B034,sc20_birthday_party,"Learner: What should I bring? Maybe a cake? | Minsu: A small cake is a nice idea. You could also bring a card or a small present.  

What kind of cake do you like? | Learner: Okay, I will buy a small gift for her. | Minsu: That sounds great! A small gift will make her happy.  

What kind of gift are you thinking about?","Great! I’ll see you on Saturday.  

Are you ready for the party?"
B035,sc12_hotel_checkin,"Learner: It is under the name Kim Jina. | Minsu: We have a Mr. and Mrs. Kim in our system, but I think you meant to say ""Mr. Kim Jina"", right? Can I get your passport, please? | Learner: Can I have a room on a high floor? | Minsu: We have rooms on floors 10 and 15. The one on the 15th floor has a nice view of the city. Do you think that would be too high up for you?",Our breakfast is from 7 to 10 am. We serve a hot buffet with many options. Do you like pancakes or eggs for breakfast?
B036,sc16_food_delivery,"Learner: Do you have a spicy one? | Minsu: Yes, we have spicy fried chicken. Would you like any side or a drink with it? | Learner: Then the spicy one, please. And two cokes. | Minsu: Got it. One spicy fried chicken and two cokes. Will you pick up or should we deliver?","Thank you. I have your address: 25 Maple Street, apartment 302.  
Your order is one spicy fried chicken and two cokes.  

When would you like the delivery?"
B037,sc18_bank,"Learner: I need it for my salary. | Minsu: A checking account is good for salary deposits.  
You will need an ID and proof of address.  
Do you have those documents ready? | Learner: Is there a monthly fee? | Minsu: Some checking accounts have a small monthly fee, but many banks waive it if you keep a regular salary deposit.  
Do you want to know which banks offer fee‑free accounts?","You need a photo ID (like a passport or driver’s license), a recent utility bill or lease for your address, and your employee’s salary statement.  
Do you have a copy of your salary statement?"
B038,sc20_birthday_party,"Learner: What should I bring? Maybe a cake? | Minsu: You can bring a cake, that would be great. What else do you plan to bring?
Remember to bring a gift too. What do you want to get Sara? | Learner: Okay, I will buy a small gift for her. | Minsu: That's a good idea to have a gift. What kind of gift do you have in mind?
What do you usually do at birthday parties?",That sounds fun! See you then! How did your weekend plans go?
B039,sc19_moving_apartment,"Learner: The rent is cheaper and it is near the subway. | Minsu: Ah, cheaper rent is good! Is the subway easy to use? | Learner: I need help to move my books. | Minsu: Moving books is hard! Do you need help packing?",Saturday is good! What time would you like?
B040,sc10_pharmacy,"Learner: I started feeling bad yesterday night. | Minsu: Did you eat or drink anything different yesterday? | Learner: Can I take this medicine with coffee? | Minsu: It's best to take it on an empty stomach. But if you really can't wait, try to drink water instead of coffee.","You should take it according to the instructions on the bottle. Usually, it's once or twice a day. How are you feeling now?"
```


> 이 프롬프트는 전체 79행 중 21~40행입니다.
