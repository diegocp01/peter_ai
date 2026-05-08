Context I gave ChatGPT: 'Hey, so this May 5th, I was invited to the OpenAI headquarters to meet Sam Altman in San Francisco, and I went, actually. And I met a lot of people, and one of these people I met was a developer that focuses specifically on make iPhone apps. I asked him how easy is to make an iPhone app, and he told me if I want the iPhone app only for me, it's actually very, very easy. I just have to literally connect my phone to my Mac, and that's it. And he told me that probably I don't even need Xcode. So my goal is to make an app for my phone that simulates the movie called Her, H-E-R, because I like the ChatGPT voice mode, but it's ugly, I don't like it. But yesterday, they released a new GPT Real-Time 2 model in the API that I can probably leverage for real-time conversations. So what I'm looking for is like to make a local app for my iPhone where when I, you know, click on activate in the app, it will start listening all the time. So it will always be listening in my phone in the background. And then it would, at the end of the day, give me a summary of kind of like what happened in the day or give me kind of like interesting insights, like how many words did I say, like statistics, or if I have a question, I can call it because it's always listening and I can say, for example, Hey, I don't know, Peter, and when he hears its name, it will wake up because the new real-time 2 model from OpenAI is actually super smart. And it can just like only be hearing until it hears its name and then kind of like react. So when I use that one in an app in my phone, pretty much just for that, it's always listening to everything and gives me summaries and insights and stats at the end of the day. And then if I need to ask something, I can just say like, Hey, Peter, help me out, whatever, because it's always listening. So I'm gonna use Codex, OpenAI Codex to code this. I do not have Xcode, so give me a quick plan of what we need to do first. Just a couple of bullet points. Don't give me a whole, you know, huge two pages, whatever. Just give me half of a page.'

Answer ChatGPT gave me: 'Yes, this is doable, but the **first version should be simpler than “always listening forever in the background.”** GPT-Realtime-2 is real and designed for low-latency voice agents with reasoning, speech, tool calls, and live conversation state. OpenAI’s docs list `gpt-realtime-2` as the model for low-latency voice agents, and Realtime sessions keep an open connection while your app sends audio and receives events. ([OpenAI][1])

Here’s the practical plan:

* **Step 1: Install Xcode anyway.**
  Codex can write the Swift code in VS Code, but for running it on your physical iPhone, signing, provisioning, device registration, microphone permissions, and SwiftUI project setup, Xcode is still the easiest path. Apple’s docs say iOS development provisioning needs an App ID, certificates, registered devices, and Xcode can manage profiles automatically. ([Apple Developer][2])

* **Step 2: Build a tiny SwiftUI MVP first.**
  One screen: big “Activate Peter” button, microphone permission, live transcript, voice response, stop button. No background mode yet. Just prove: iPhone mic → GPT-Realtime-2 → spoken response.

* **Step 3: Use GPT-Realtime-2 for conversation, not wake word detection at first.**
  The app should open a Realtime session only after you press Activate. Realtime is best for live audio, while request-based audio is better for bounded audio files or summaries. ([OpenAI Platform][3])

* **Step 4: Add “daily memory” locally.**
  Store transcripts locally on the phone, probably SQLite or JSON. At the end of the day, send only the day’s transcript summary request to the API: “summarize my day, insights, mood, word count, topics.”

* **Step 5: Then experiment with background audio.**
  iOS has background audio modes, but Apple is strict. You can configure background execution modes, and Apple’s speech docs also warn about speech recognition limits and recording transparency. ([Apple Developer][4])
  For personal use, we can test it, but I would not make the first version depend on true always-on background listening.

* **Step 6: Privacy-first design.**
  Make it obvious when recording: visible UI, mic indicator, local storage, manual delete button, no hidden recording. For the “Her” feeling, the safe version is: **press Activate, talk naturally, Peter listens while active, then gives daily insights.**

The first Codex goal should be:

```text
Create a minimal SwiftUI iPhone app called PeterAI with one screen. It should request microphone permission, start/stop recording with a button, connect to OpenAI Realtime API using gpt-realtime-2, stream microphone audio, play back the model voice response, and show a live transcript. Keep the code simple and runnable on my physical iPhone through Xcode.
```

[1]: https://openai.com/index/advancing-voice-intelligence-with-new-models-in-the-api/ "Advancing voice intelligence with new models in the API | OpenAI"
[2]: https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/ "Create a development provisioning profile - Provisioning profiles - Account - Help - Apple Developer"
[3]: https://platform.openai.com/docs/guides/realtime "Realtime and audio | OpenAI API"
[4]: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes?utm_source=chatgpt.com "Configuring background execution modes"' you are Codex so go do this app, I have an openai api key and a mac and iphone, goal is to make this app to live only in my iphone I dont have Xcode, first lets make sure the app works in my phone the way is supposed to and then we keep iterating. GO