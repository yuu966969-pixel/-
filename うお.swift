import AlarmKit
import AppIntents
import ActivityKit
import SwiftUI
import Foundation

enum AlarmScheduler {
    private static let alarmIDKey = "nekoAlarmScheduledAlarmID"
    private static let hourKey = "nekoAlarmHour"
    private static let minuteKey = "nekoAlarmMinute"
    private static let scheduledSoundDateKey = "nekoAlarmScheduledSoundDate"

    static func schedule(hour: Int, minute: Int, soundResourceName: String?) async throws -> UUID {
        let manager = AlarmManager.shared
        let authorization = try await manager.requestAuthorization()
        guard authorization == .authorized else {
            throw AlarmSetupError.notAuthorized
        }

        let oldID = UserDefaults.standard.string(forKey: alarmIDKey).flatMap(UUID.init(uuidString:))
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
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: everyDay))
        let sound = soundResourceName.map { AlertConfiguration.AlertSound.named($0) } ?? .default
        let configuration = AlarmManager.AlarmConfiguration<NekoAlarmMetadata>(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: NekoAlarmStopIntent(),
            sound: sound
        )

        // Schedule the replacement first so a failed update doesn't erase the existing alarm.
        try await manager.schedule(id: id, configuration: configuration)
        if let oldID, oldID != id {
            do {
                try manager.cancel(id: oldID)
            } catch {
                // Preserve the previous alarm if it could not be replaced cleanly.
                try? manager.cancel(id: id)
                throw error
            }

            // The old alarm is gone, so its daily custom sound can be removed safely.
            if let oldDate = UserDefaults.standard.string(forKey: scheduledSoundDateKey),
               !oldDate.isEmpty {
                let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                let oldSound = library.appendingPathComponent("Sounds", isDirectory: true)
                    .appendingPathComponent("neko-daily-\(oldDate).wav")
                try? FileManager.default.removeItem(at: oldSound)
            }
        }
        let defaults = UserDefaults.standard
        defaults.set(id.uuidString, forKey: alarmIDKey)
        defaults.set(hour, forKey: hourKey)
        defaults.set(minute, forKey: minuteKey)
        defaults.set(soundResourceName == nil ? "" : DailyTrackGenerator.shared.todayKey,
                     forKey: scheduledSoundDateKey)
        return id
    }

    /// Replaces the repeating alarm after a new daily track is ready.
    /// iOS background execution is opportunistic, so the existing alarm remains active if refresh is delayed.
    static func refreshSavedAlarm() async {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: alarmIDKey) != nil,
              DailyTrackGenerator.shared.hasTrackForToday,
              defaults.string(forKey: scheduledSoundDateKey) != DailyTrackGenerator.shared.todayKey,
              let soundName = try? DailyTrackGenerator.shared.prepareAlarmSound() else {
            return
        }
        let hour = defaults.object(forKey: hourKey) == nil ? 7 : defaults.integer(forKey: hourKey)
        let minute = defaults.object(forKey: minuteKey) == nil ? 0 : defaults.integer(forKey: minuteKey)
        do {
            _ = try await schedule(hour: hour, minute: minute, soundResourceName: soundName)
        } catch {
            // Keep the existing alarm active; the next refresh can retry.
        }
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
