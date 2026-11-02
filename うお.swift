import AlarmKit
import SwiftUI
import Foundation

enum AlarmScheduler {
    static func schedule(hour: Int, minute: Int, soundResourceName: String) async throws -> UUID {
        let manager = AlarmManager.shared

        let authorization = try await manager.requestAuthorization()
        guard authorization == .authorized else {
            throw AlarmSetupError.notAuthorized
        }

        let id = UUID()
        let alert = AlarmPresentation.Alert(title: "🐱 猫ミーム地獄アラーム")

        let countdown = AlarmPresentation.Countdown(
            title: "猫ミーム接近中",
            pauseButton: AlarmButton(
                text: "一時停止",
                textColor: .white,
                systemImageName: "pause.fill"
            )
        )

        let paused = AlarmPresentation.Paused(
            title: "猫ミーム待機中",
            resumeButton: AlarmButton(
                text: "再開",
                textColor: .white,
                systemImageName: "play.fill"
            )
        )

        let attributes = AlarmAttributes<NekoAlarmMetadata>(
            presentation: AlarmPresentation(
                alert: alert,
                countdown: countdown,
                paused: paused
            ),
            metadata: NekoAlarmMetadata(),
            tintColor: Color.pink
        )

        let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
        let schedule = Alarm.Schedule.relative(
            .init(time: time, repeats: .never)
        )

        // 予定時刻の60秒前からロック画面にカウントダウンを表示します。
        let duration = Alarm.CountdownDuration(preAlert: 60, postAlert: 60)

        let configuration = AlarmManager.AlarmConfiguration<NekoAlarmMetadata>(
            countdownDuration: duration,
            schedule: schedule,
            attributes: attributes,
            sound: AlertConfiguration.AlertSound.named(soundResourceName)
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
