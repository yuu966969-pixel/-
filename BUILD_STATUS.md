# Build status

## Latest verified GitHub Actions run

Latest verified run: [NekoAlarm iOS Build #52](https://github.com/yuu966969-pixel/-/actions/runs/44289681691)

Verified commit: `04b7907351c4407c3dd195a562367599cd432a8e`

All of these checks completed successfully:

- XcodeGen generates `NekoAlarm.xcodeproj`.
- `plutil -lint Info.plist` passes after project generation.
- The iOS Simulator app compiles successfully.
- The built app's Info.plist is checked for AlarmKit permission text, background processing, the permitted BG task identifier, Live Activities, launch storyboard, and iPhone-only device family.
- The unsigned iPhone device app compiles successfully.
- Both CI artifacts upload successfully:
  - `NekoAlarm-iOS-Simulator`
  - `NekoAlarm-iOS-Device-Unsigned`

Artifacts from run #52 expire on 2026-12-02.

The simulator app is compiled but the hosted simulator boot/launch smoke test is currently omitted because the simulator boot stalled in CI. An earlier version installed and launched successfully in [run #30](https://github.com/yuu966969-pixel/-/actions/runs/43583536615). The current source has not yet had its simulator UI launch verified.

## Product behavior and limitations

- The offline soundtrack is procedural WAV audio generated on-device. It is original audio, not AI-generated music.
- The iOS app accepts free-text composition requests, stores a backend HTTPS URL on-device, and offers WAV export/share for generated tracks. A FastAPI backend is included under `server/`; it calls Stability AI Stable Audio 2.5 and returns MP3 bytes. The backend source is committed but is not deployed and has no provider API key configured. See `server/README.md`.
- Background refresh is opportunistic. iOS does not guarantee execution at exactly 00:05.
- The app schedules a weekly repeating AlarmKit alarm and replaces its configuration after a new daily track is ready. This refresh is best-effort because iOS background execution is opportunistic; if the app is not run in time, the previous sound may repeat.
- The AlarmKit stop action still stops the system alarm immediately. Its `stopIntent` opens the app and presents the optional in-app password/quiz wake-up check afterward; it cannot block or reverse the system dismissal.
- The selected alarm time is persisted. When a new daily soundtrack is ready, the app replaces its repeating alarm with a new configuration using the latest sound.
- Downloaded MP3 tracks are decoded into Int16 PCM WAV before AlarmKit uses them. The offline fallback is also WAV.
- AlarmKit behavior, custom sound playback, stop-intent foregrounding, and background execution still need physical-iPhone verification.
- The CI device build is unsigned. It cannot be installed on a physical iPhone until signed with an Apple development identity and provisioning profile.

See [BUILDING.md](BUILDING.md) for artifact download and signing requirements.
