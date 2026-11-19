# NekoAlarm build and installation

## CI artifacts

The GitHub Actions workflow builds the app without code signing and uploads artifacts:

- `NekoAlarm-iOS-Simulator`: simulator app bundle. Intended for Xcode Simulator, not direct installation on an iPhone.
- `NekoAlarm-iOS-Device-Unsigned`: unsigned iPhone app bundle. It is not installable on a physical iPhone until signed with a valid Apple development identity and provisioning profile.

Open the repository's **Actions** tab, select a successful **NekoAlarm iOS Build** run, then download the artifact from the run's Artifacts section. Artifacts expire after 14 days.

## Local build

1. Install Xcode with an iOS 26.1 SDK and XcodeGen.
2. Run `xcodegen generate` from the repository root.
3. The generated `Info.plist` is defined by the `info.properties` section in `project.yml`. Change runtime metadata there; do not hand-edit the generated plist because XcodeGen rewrites it.
4. Open `NekoAlarm.xcodeproj` in Xcode.
5. Select an iOS Simulator destination and build.

## Physical iPhone

To install on a physical iPhone, configure a valid Apple development team, bundle identifier, signing certificate, and provisioning profile in Xcode or the CI environment. Do not commit signing certificates, private keys, or provisioning profiles to this public repository.

## AI music endpoint

The app reads `NEKO_AI_AUDIO_ENDPOINT` from its generated Info.plist. Set that Xcode build setting to an HTTPS endpoint you control; do not put provider API keys in the iOS app or commit secrets. The endpoint accepts a JSON POST body with `date`, `prompt`, `format: "mp3"`, and `mode` (`daily` or `custom`). It must return the generated MP3 bytes directly with a 2xx response. The app converts the result to a local WAV file so it can be previewed, shared/saved, and used as the AlarmKit sound. For a custom request, `prompt` contains the user's description and the app will not silently substitute a random offline track if AI generation fails.

## Known product limitations

- The daily offline soundtrack is procedural audio generated on-device. It is not AI music.
- AI composition and downloading/sharing are wired into the app, but actual AI generation requires a separately hosted service configured as `NEKO_AI_AUDIO_ENDPOINT`. No such service is configured in this repository, so custom AI composition will report that the server is unavailable until one is deployed.
- iOS background refresh is opportunistic and cannot guarantee execution at an exact time.
- The AlarmKit stop intent opens the app after the system has stopped the alarm so the user can complete the optional in-app wake-up check. It cannot block the system's stop action.
- The selected alarm time is persisted. When a new daily track is ready, the app replaces its repeating alarm with a new configuration using the latest sound. This is best-effort because iOS background processing is opportunistic.
- Downloaded MP3 audio is converted to Int16 PCM WAV before AlarmKit uses it; the offline fallback is also WAV.
- Physical-device AlarmKit behavior, custom sound playback, stop-intent foregrounding, and background execution still need to be tested on an iPhone.
