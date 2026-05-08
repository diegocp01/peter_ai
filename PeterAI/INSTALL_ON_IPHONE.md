# Install PeterAI on iPhone

## Current blocker

This Mac does not currently have full Xcode installed. The command line tools are present, but `xcodebuild` and `devicectl` both report that Xcode is required.

Install Xcode from the Mac App Store or from Apple Developer Downloads first.

## Run checklist

1. Open `PeterAI.xcodeproj` in Xcode.
2. Select the `PeterAI` project, then the `PeterAI` target.
3. Open Signing & Capabilities.
4. Choose your Apple Development Team.
5. Keep automatic signing enabled.
6. Connect your iPhone by USB and trust the Mac on the phone.
7. Select your iPhone as the run destination.
8. Press Run.
9. On the iPhone, paste your OpenAI API key and tap the key button.
10. Tap Activate Peter, allow microphone access, speak, then pause.

## Expected result

- The status changes from Connecting to Listening after the Realtime session is accepted.
- The iOS microphone indicator appears while active.
- Your spoken words appear in the transcript after the turn completes.
- Peter replies with streamed audio.
- Peter's reply appears in the transcript.

## If it fails

- If signing fails, change the bundle identifier in Xcode to something unique, such as `com.<yourname>.peterai`.
- If the app opens but does not connect, confirm the API key has Realtime API access and check the notice text in the app.
- If audio input works but no reply plays, keep the app active, check the phone volume, and try headphones or speaker output.
- If Xcode asks for Developer Mode, enable it on the iPhone under Settings > Privacy & Security > Developer Mode.
