import AlarmKit
import AppIntents
import ActivityKit
import SwiftUI
import Foundation

enum AlarmScheduler {
    static func schedule(hour: Int, minute: Int, soundResourceName: String?) async throws -> UUID {
        let manager = AlarmManager.shared

        let authorization = try await manager.requestAuthorization()
        guard authorization == .authorized else {
            throw AlarmSetupError.notAuthorized
        }

        let id = UUID()
        let alert = AlarmPresentation.Alert(title: "🐱 猫ミーム地獄アラーム")
        let attributes = AlarmAttributes<NekoAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: NekoAlarmMetadata(),
            tintColor: Color.pink
        )

        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let everyDay = Alarm.Schedule.Relative.Recurrence.weekly([
            .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
        ])
        let schedule = Alarm.Schedule.relative(
            .init(time: time, repeats: everyDay)
        )

        // Use the generated daily track when available; otherwise use the system alarm sound.
        let sound = soundResourceName.map { AlertConfiguration.AlertSound.named($0) } ?? .default
        let configuration = AlarmManager.AlarmConfiguration<NekoAlarmMetadata>(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: NekoAlarmStopIntent(),
            sound: sound
        )

        try await manager.schedule(id: id, configuration: configuration)
        return id
    }
}

enum AlarmSetupError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "アラームの使用が許可されませんでした。iPhoneの設定を確認してください。"
        }
    }
}


/// Opens the app after the system has stopped the alarm so the user can complete
/// the optional in-app wake-up check. AlarmKit still stops the alarm immediately.
struct NekoAlarmStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "起床チェックを開く"
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "nekoAlarmChallengePending")
        return .result()
    }
}
