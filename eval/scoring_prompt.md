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
