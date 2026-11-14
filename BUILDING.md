# NekoAlarm build and test

## Automated build

GitHub Actions uses XcodeGen and Xcode to compile the app for the iOS Simulator without code signing. The workflow uploads the `NekoAlarm-iOS-Simulator` artifact. The ZIP contains a `NekoAlarm.app` bundle that can be installed in an iOS Simulator on a Mac.

This is **not** an installable iPhone IPA and cannot be installed directly on a physical iPhone.

## Local build

Requirements:
- macOS with Xcode 26.1 or later
- Xcode command line tools
- XcodeGen

Run:

```sh
brew install xcodegen
xcodegen generate
xcodebuild \
  -project NekoAlarm.xcodeproj \
  -scheme NekoAlarm \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Audio generation

If the optional `NEKO_AI_AUDIO_ENDPOINT` Info.plist value is configured, the app sends a POST request containing the date, prompt, and requested MP3 format to that endpoint. The endpoint must return MP3 bytes.

If the endpoint is absent or unavailable, the app creates an original, procedurally synthesized WAV track on-device. This offline fallback is **not AI-generated**. AlarmKit uses the generated track when available and the system default sound otherwise.

Do not commit API secrets or private service credentials to this repository.

## Current limitations

- AlarmKit scheduling requests authorization and configures a repeating daily schedule, but physical-device behavior has not yet been tested.
- Background refresh is opportunistic; iOS does not guarantee execution at exactly 00:05. The app also checks for a new daily track when it is opened.
- The password and quiz are an in-app demonstration only. They do not prevent dismissal of the system AlarmKit alarm.
- No signed iPhone IPA or App Store/TestFlight build is produced by this workflow. Physical-device distribution requires signing and provisioning configured in Xcode.
