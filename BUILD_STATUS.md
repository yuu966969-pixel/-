# Build status

## Verified in GitHub Actions

Latest verified run: [NekoAlarm iOS Build #30](https://github.com/yuu966969-pixel/-/actions/runs/43583536615)

Commit: `fc2377a6aac558154e19d7ebfcf1d5165ee0e2db`

- XcodeGen successfully generates `NekoAlarm.xcodeproj`.
- `Info.plist` passes `plutil -lint`.
- The iOS Simulator app builds successfully.
- The app installs and launches on an iPhone Simulator.
- The iPhone device target builds successfully without code signing.
- Both CI artifacts upload successfully:
  - `NekoAlarm-iOS-Simulator`
  - `NekoAlarm-iOS-Device-Unsigned`

The artifacts are retained for 14 days from the run (created 2026-11-14).

## Product behavior and limitations

- The offline soundtrack is procedural WAV audio generated on-device. It is original audio, not AI-generated music.
- AI music requires a separately hosted service configured as `NEKO_AI_AUDIO_ENDPOINT`. No endpoint is configured in this repository.
- Background refresh is opportunistic. iOS does not guarantee execution at exactly 00:05.
- The app currently schedules a weekly repeating AlarmKit alarm. The sound resource is selected when the alarm is scheduled; automatic replacement of that resource for each subsequent day has not been verified.
- The AlarmKit stop action still stops the system alarm immediately. Its `stopIntent` opens the app and presents the optional in-app password/quiz wake-up check afterward; it cannot block or reverse the system dismissal.
- AlarmKit behavior, custom sound playback, and background execution still need physical-iPhone verification.
- The CI device build is unsigned. It cannot be installed on a physical iPhone until signed with an Apple development identity and provisioning profile.

See [BUILDING.md](BUILDING.md) for artifact download and signing requirements.
