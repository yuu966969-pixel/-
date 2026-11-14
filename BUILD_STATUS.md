# Build status

The CI job validates the iOS Simulator build. The alarm is configured to repeat daily and uses the system alarm sound until an AI audio endpoint is configured. A simulator artifact is not a signed iPhone installation package.

The current AlarmKit implementation uses a daily repeating schedule and the default system alarm sound when no generated track is available.
