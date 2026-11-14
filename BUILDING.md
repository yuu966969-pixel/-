# NekoAlarm build and installation

## CI artifacts

The GitHub Actions workflow builds the app without code signing and uploads artifacts:

- `NekoAlarm-iOS-Simulator`: simulator app bundle. Intended for Xcode Simulator, not direct installation on an iPhone.
- `NekoAlarm-iOS-Device-Unsigned`: unsigned iPhone app bundle. It is not installable on a physical iPhone until signed with a valid Apple development identity and provisioning profile.

Open the repository's **Actions** tab, select a successful **NekoAlarm iOS Build** run, then download the artifact from the run's Artifacts section. Artifacts expire after 14 days.

## Local build

1. Install Xcode with an iOS 26.1 SDK and XcodeGen.
2. Run `xcodegen generate` from the repository root.
3. Open `NekoAlarm.xcodeproj` in Xcode.
4. Select an iOS Simulator destination and build.

## Physical iPhone

To install on a physical iPhone, configure a valid Apple development team, bundle identifier, signing certificate, and provisioning profile in Xcode or the CI environment. Do not commit signing certificates, private keys, or provisioning profiles to this public repository.

## Known product limitations

- The daily offline soundtrack is procedural audio generated on-device. It is not AI music.
- AI music requires a separately hosted service configured as `NEKO_AI_AUDIO_ENDPOINT`. No such service is configured in this repository.
- iOS background refresh is opportunistic and cannot guarantee execution at an exact time.
- The password and quiz screens are app-local demonstrations. They do not prevent dismissal of the system AlarmKit alarm.
- Physical-device AlarmKit behavior still needs to be tested on an iPhone.
