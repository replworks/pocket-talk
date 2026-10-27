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
B061,sc13_public_transport,"Learner: Which line should I take? | Minsu: You need to take the Blue Line toward Downtown.  
It stops at City Hall after three stations.  
Do you see the Blue Line sign? | Learner: How many stops is it? | Minsu: It is three stops away.  
The train will stop at two stations before City Hall.  
Do you need help finding the platform?","You can transfer at the second station, called Central Station.  
There you can change to the Red Line if you need another direction.  
Do you want to know the time of the next train?"
B062,sc11_phone_call,Learner: I call to ask about the meeting tomorrow. | Minsu: We're going to discuss the new project at work. Are you looking forward to it? | Learner: What time does it start? | Minsu: It starts at 10 am. Can you get here on time?,Sounds good. I'll see you then. Do you need me to remind you anything else?
B063,sc15_movies_friends,Learner: I like comedy movies. The action is too loud for me. | Minsu: Comedy movies are good. Do you want to watch one tonight? | Learner: What time is the movie start? | Minsu: I do not know. What time is good for you?,Seven is good. Do you want to bring snacks?
B064,sc17_gym_exercise,"Learner: I usually walk, but I want to be stronger. | Minsu: Our gym has a good weight section. What do you think about lifting weights? | Learner: Do you have a class in the evening? | Minsu: We have yoga and Pilates classes in the evening. Do you think you would like to join a class?","The membership fee is 500,000 KRW for a month. Is that within your budget?"
B065,sc11_phone_call,"Learner: I call to ask about the meeting tomorrow. | Minsu: Ah, the meeting tomorrow. Do you know the time? | Learner: What time does it start? | Minsu: It starts at 10 o’clock. Is this helpful?",Nine is good. Do you need help with anything else?
B066,sc06_hobbies,"Learner: Last weekend I go to Bukhansan with my friend. | Minsu: That is great! What time did you go? | Learner: It was very hard but the view was amazing. | Minsu: Wow, that sounds hard! Did you take photos?",I do not know. Do you like to rest on weekends?
B067,sc09_travel_plan,Learner: I will stay for three days with my sister. | Minsu: Three days sounds perfect! What are you two going to do? | Learner: What should I see in Jeju? | Minsu: You should see Halla Mountain and the beach. What do you think?,Good idea! Will you book for you and your sister?
B068,sc15_movies_friends,Learner: I like comedy movies. The action is too loud for me. | Minsu: Comedies are fun. I like watching comedies with friends too. Do you have a favorite comedian? | Learner: What time is the movie start? | Minsu: The movie starts at 7:30 PM. Are you free to meet at 7:30?,I'll meet you at the theater at 7. What time should we grab dinner before the movie?
B069,sc05_making_appointment,"Learner: Friday afternoon is good for me. | Minsu: Perfect! We have a slot available at 3:00 PM. Is that okay? | Learner: Can I come at three? I finish work at two. | Minsu: Sure, you can come at 3:00 PM. Will that work?",That's good to know. Thanks for sharing. Is there anything else you need help with?
B070,sc12_hotel_checkin,"Learner: It is under the name Kim Jina. | Minsu: Okay, Kim Jina. Got it. Should I proceed with your reservation? | Learner: Can I have a room on a high floor? | Minsu: Sure thing! Would you like a room on a high floor?",Breakfast is served from 7:00 to 9:00. Is that good for you?
B071,sc04_directions,Learner: How long does it take on foot? | Minsu: It takes about 15 minutes. Is that helpful? | Learner: Is there a bus? I am tired. | Minsu: There is a bus. Is that good?,You are welcome! Is today busy?
B072,sc11_phone_call,"Learner: I call to ask about the meeting tomorrow. | Minsu: Sure, the meeting is at 10 am tomorrow in Room 3. Do you need any other information? | Learner: What time does it start? | Minsu: The meeting starts at 10 am. It will last about an hour. Do you need the meeting agenda?","Great, I’ll see you at 9 am. Do you need directions to Room 3?"
B073,sc13_public_transport,Learner: Which line should I take? | Minsu: The line for City Hall? You need the blue line. Is this clear? | Learner: How many stops is it? | Minsu: It is 5 stops. Does this help?,You can transfer at Station A. Is this helpful?
B074,sc14_work_smalltalk,Learner: The food was very good and I meet many people. | Minsu: Sounds like a fun event. Did you dance at the wedding? | Learner: How about you? What did you do? | Minsu: I went to the park with my dog. Did you have a favorite part of the wedding?,I'm free this afternoon. Do you want to try that new Korean restaurant?
B075,sc17_gym_exercise,"Learner: I usually walk, but I want to be stronger. | Minsu: That's a good goal! What can you do now that makes you feel stronger? | Learner: Do you have a class in the evening? | Minsu: I'm not sure about classes. What time do you have in mind?",One month usually costs a bit more. How many classes do you plan to take?
B076,sc06_hobbies,Learner: Last weekend I go to Bukhansan with my friend. | Minsu: Nice! Bukhansan is beautiful. Did you enjoy the view? | Learner: It was very hard but the view was amazing. | Minsu: I'm glad you liked it. Do you plan another hike soon?,I usually read a book or go for a short walk. Sometimes I meet friends for coffee. What do you like to eat on weekends?
B077,sc17_gym_exercise,"Learner: I usually walk, but I want to be stronger. | Minsu: Stronger is good! Do you think lifting weights is right for you? | Learner: Do you have a class in the evening? | Minsu: Yes! Do you want to know more about the evening classes?",I don't know. Do you know what the price is?
B078,sc07_weather_weekend,Learner: What is the weather like on Saturday? | Minsu: I don't know. Do you want to plan something else? | Learner: Rainy? Then I will watch a movie at home. | Minsu: Rainy sounds okay. Do you like watching movies?,That sounds fun! Do you want to watch a favorite movie?
B079,sc01_self_intro,Learner: I am work at a small company in Seoul. | Minsu: You work at a small company in Seoul. What is your job there? | Learner: I like listen to music and watch movies. | Minsu: Listening to music and watching movies is fun. What kind of music do you like?,That's great! How do you practice English at work?
```


> 이 프롬프트는 전체 79행 중 61~79행입니다.
