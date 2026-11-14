import AlarmKit
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
