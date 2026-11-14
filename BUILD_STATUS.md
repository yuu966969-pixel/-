# NekoAlarm build status

## Verified
- XcodeGen project generation succeeds.
- Swift compilation for the iOS Simulator succeeds.
- GitHub Actions packages and uploads the simulator app bundle.
- AlarmKit is configured with a daily repeating schedule and requests authorization at runtime.
- If the optional AI audio endpoint is unavailable, the app generates an original procedural WAV track locally and uses it as the custom alarm sound.

## Not yet verified
- Installation and alarm behavior on a physical iPhone.
- A signed device build or IPA.
- A configured AI audio service. The local procedural track is not AI-generated.
- Exact 00:05 background execution; iOS background task scheduling is opportunistic.
- Password/quiz integration with the system alarm dismissal. The current quiz is only an in-app demonstration.

See [BUILDING.md](BUILDING.md) for build instructions and limitations.
