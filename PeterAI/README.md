# PeterAI

PeterAI is a minimal personal iPhone SwiftUI app for active voice conversations with OpenAI Realtime.

## What it does

- Saves your OpenAI API key in the iOS Keychain.
- Requests microphone permission.
- Streams microphone audio as 24 kHz PCM to `gpt-realtime-2`.
- Uses server voice activity detection so Peter responds after you pause.
- Plays the model's streamed voice response.
- Shows user and assistant transcripts in one screen.

## Run on your iPhone

1. Install Xcode from the Mac App Store.
2. Open `PeterAI.xcodeproj`.
3. In the PeterAI target, set your Apple development team under Signing & Capabilities.
4. Connect your iPhone by USB, trust the Mac on the phone, and select the phone as the run destination.
5. Press Run.
6. In the app, paste your OpenAI API key, tap the key button, then tap Activate Peter.

This first version listens only while the app is open and activated. True always-on background listening is a separate iOS background-mode and privacy review problem, so it is intentionally not part of the MVP.
