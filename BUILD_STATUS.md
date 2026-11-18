# Build status

## Latest verified GitHub Actions run

Latest verified run: [NekoAlarm iOS Build #46](https://github.com/yuu966969-pixel/-/actions/runs/44286645987)

Verified commit: `57d6161dab7a688b898819c59a0712b44e1e575c`

The following checks completed successfully:

- XcodeGen successfully generates `NekoAlarm.xcodeproj`.
- `Info.plist` passes `plutil -lint`.
- The iOS Simulator app compiles successfully.
- The unsigned iPhone device app compiles successfully.
- Both CI artifacts upload successfully:
  - `NekoAlarm-iOS-Simulator`
  - `NekoAlarm-iOS-Device-Unsigned`

Artifacts from run #46 expire on 2026-12-02.

The simulator installation/launch smoke-test step was removed because the hosted simulator boot stalled. Therefore this run verifies compilation and artifact creation, but does not verify simulator launch. An earlier version of the app installed and launched successfully in simulator in [run #30](https://github.com/yuu966969-pixel/-/actions/runs/43583536615).

## Product behavior and limitations

- The offline soundtrack is procedural WAV audio generated on-device. It is original audio, not AI-generated music.
- AI music requires a separately hosted service configured as `NEKO_AI_AUDIO_ENDPOINT`. No endpoint is configured in this repository.
- Background refresh is opportunistic. iOS does not guarantee execution at exactly 00:05.
- The app schedules a weekly repeating AlarmKit alarm and replaces its configuration after a new daily track is ready. This refresh is best-effort because iOS background execution is opportunistic; if the app is not run in time, the previous sound may repeat.
- The AlarmKit stop action still stops the system alarm immediately. Its `stopIntent` opens the app and presents the optional in-app password/quiz wake-up check afterward; it cannot block or reverse the system dismissal.
- The selected alarm time is persisted. When a new daily soundtrack is ready, the app replaces its repeating alarm with a new configuration using the latest sound.
- Downloaded MP3 tracks are decoded into Int16 PCM WAV before AlarmKit uses them. The offline fallback is also WAV.
- AlarmKit behavior, custom sound playback, stop-intent foregrounding, and background execution still need physical-iPhone verification.
- The CI device build is unsigned. It cannot be installed on a physical iPhone until signed with an Apple development identity and provisioning profile.

See [BUILDING.md](BUILDING.md) for artifact download and signing requirements.
