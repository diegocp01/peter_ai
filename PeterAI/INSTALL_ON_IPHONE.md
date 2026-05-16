# Install PeterAI On iPhone And Apple Watch

PeterAI is designed to run on a physical iPhone, with an optional paired Apple
Watch app.

## iPhone Install Checklist

1. Install Xcode from the Mac App Store or Apple Developer Downloads.
2. Open `PeterAI.xcodeproj` in Xcode.
3. Select the `PeterAI` project.
4. For the iPhone target, choose your Apple Development Team.
5. Replace `com.example.peterai` with a unique bundle identifier.
6. Keep automatic signing enabled.
7. Connect your iPhone by USB and trust the Mac on the phone.
8. Select your iPhone as the run destination.
9. Press Run.
10. On iPhone, paste your OpenAI API key and tap the key button.
11. Press Play, allow microphone access, speak, then press Pause.

## Apple Watch Install Checklist

1. Install the watchOS platform support in Xcode if prompted.
2. Keep the iPhone connected to the Mac.
3. Make sure the Apple Watch is paired, unlocked, and on your wrist.
4. For the Watch target, choose your Apple Development Team.
5. Replace `com.example.peterai.watchkitapp` with a unique Watch bundle ID.
6. Make sure the Watch target companion bundle ID matches the iPhone bundle ID.
7. Select the Watch run destination or the iPhone + Watch destination.
8. Press Run.
9. Open PeterAI on iPhone and Apple Watch.
10. Send or sync the API key from iPhone to Watch.
11. Press Play on the Watch and talk to Peter.

## Expected Result

- The status changes from connecting to ready/listening.
- The system microphone indicator appears while active.
- Your speech appears as transcript text.
- Peter replies with streamed voice and transcript text.
- On Apple Watch, the iPhone handles the network relay to OpenAI.

## Troubleshooting

- If signing fails, set your Apple Development Team and use unique bundle IDs.
- If Xcode asks for Developer Mode, enable it on iPhone under Settings >
  Privacy & Security > Developer Mode.
- If the app opens but does not connect, confirm the API key has Realtime API
  access.
- If Watch says it is waiting for iPhone, open the iPhone app and keep the phone
  nearby.
- If Watch networking fails, use the current iPhone relay flow instead of direct
  Watch networking.
- If audio input works but no reply plays, check volume and speaker/headphone
  output.
