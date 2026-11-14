# Build status

## Verified in CI

- XcodeGen successfully generates `NekoAlarm.xcodeproj`.
- The iOS Simulator target compiles successfully.
- The workflow publishes a `NekoAlarm-iOS-Simulator` artifact.
- The app has an offline procedural WAV fallback. This is original generated audio, not AI-generated music.
- If `NEKO_AI_AUDIO_ENDPOINT` is configured in the app's Info.plist and the service returns a valid audio response, the app attempts to use that remote track instead.
- Alarm scheduling is configured to repeat every day of the week and falls back to the system alarm sound when no daily track is available.

## Not yet verified

- AlarmKit behavior on a physical iPhone.
- Background refresh timing. iOS treats background processing as opportunistic; the app cannot guarantee generation at exactly 00:05.
- A working hosted AI audio service. No endpoint is configured in this repository.
- Signed iPhone installation, TestFlight, or App Store distribution. The repository does not contain Apple signing credentials or provisioning profiles.
- The password and quiz are app-local practice UI only. They do not gate the system AlarmKit dismiss action.

See [BUILDING.md](BUILDING.md) for build artifacts and signing requirements.
