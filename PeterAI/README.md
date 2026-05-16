# PeterAI

PeterAI is a SwiftUI voice agent for iPhone and Apple Watch. It uses OpenAI's
Realtime API with `gpt-realtime-2` for live voice conversations, plus a small
web search tool for current information.

The app is intentionally simple: press play, talk to Peter, hear the answer,
and press pause to end the session.

## Features

- iPhone voice mode using the microphone and streamed audio playback.
- Apple Watch voice mode that relays audio through the paired iPhone.
- OpenAI Realtime session with `gpt-realtime-2`.
- Web search tool powered by the OpenAI Responses API.
- Live transcript bubbles on iPhone and Apple Watch.
- API key saved locally in the device Keychain.
- Manual API key sync from iPhone to Apple Watch.
- Dark mode interface with shared iPhone and Watch app icons.

## What this is not

- Not an always-listening background recorder.
- Not an App Store-ready product.
- Not a backend service. Your OpenAI API key is entered on-device.

## Requirements

- macOS with Xcode installed.
- iPhone running iOS 17 or newer.
- Optional: Apple Watch running watchOS 10 or newer.
- An OpenAI API key with access to `gpt-realtime-2` and web search.

## Setup

1. Clone the repo.
2. Open `PeterAI/PeterAI.xcodeproj` in Xcode.
3. Select the `PeterAI` project and open **Signing & Capabilities**.
4. Set your Apple development team for both the iPhone and Watch targets.
5. Change the placeholder bundle IDs to unique values:
   - iPhone target: `com.yourname.peterai`
   - Watch target: `com.yourname.peterai.watchkitapp`
6. Make sure the Watch target's companion app bundle identifier matches the
   iPhone bundle ID.
7. Connect your iPhone, trust the Mac, select the iPhone run destination, and run.
8. If using Apple Watch, make sure the Watch is paired, unlocked, on your wrist,
   and installed from Xcode.

## Using The App

### iPhone

1. Open PeterAI.
2. Paste your OpenAI API key.
3. Tap the key button to save it.
4. Press **Play** and talk.
5. Press **Pause** to end the conversation.

### Apple Watch

1. Open PeterAI on iPhone first.
2. Open PeterAI on Apple Watch.
3. In the iPhone app, tap **Send API key to Apple Watch**.
4. On the Watch, tap **Sync Key** if needed.
5. Press play on the Watch and talk to Peter.

The current Watch implementation routes the Realtime connection through the
iPhone. Keep the iPhone nearby and avoid force-closing the iPhone app while
using the Watch app.

## Privacy Notes

- The app uses the microphone only while voice mode is active.
- Transcripts are shown in the current UI and can be cleared.
- The OpenAI API key is stored locally in Keychain.
- Do not commit API keys, provisioning profiles, certificates, or local notes.

## License

MIT
