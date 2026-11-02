import SwiftUI
import BackgroundTasks
import UIKit

@main
struct NekoAlarmApp: App {
    @UIApplicationDelegateAdaptor(NekoAlarmAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await DailyTrackGenerator.shared.generateIfNeeded()
                    NekoBackgroundRefresh.scheduleNext()
                    await watchForMidnightWhileForegrounded()
                }
        }
    }

    /// When the app remains open across midnight, generate today's track without a notification.
    @MainActor
    private func watchForMidnightWhileForegrounded() async {
        while !Task.isCancelled {
            let now = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1,
                                                  to: Calendar.current.startOfDay(for: now))!
            let seconds = max(1, tomorrow.timeIntervalSince(now) + 2)
            do {
                try await Task.sleep(for: .seconds(seconds))
                await DailyTrackGenerator.shared.generateIfNeeded()
                NekoBackgroundRefresh.scheduleNext()
            } catch {
                return
            }
        }
    }
}

final class NekoAlarmAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NekoBackgroundRefresh.register()
        NekoBackgroundRefresh.scheduleNext()
        return true
    }
}

enum NekoBackgroundRefresh {
    static let identifier = "jp.example.NekoAlarm.dailyTrackRefresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task: task as! BGProcessingTask)
        }
    }

    static func scheduleNext() {
        let request = BGProcessingTaskRequest(identifier: identifier)
        let next = Calendar.current.nextDate(after: Date(),
                                             matching: DateComponents(hour: 0, minute: 5),
                                             matchingPolicy: .nextTime)
        request.earliestBeginDate = next
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGProcessingTask) {
        scheduleNext()
        let work = Task { @MainActor in
            await DailyTrackGenerator.shared.generateIfNeeded()
        }
        task.expirationHandler = { work.cancel() }
        Task {
            await work.value
            task.setTaskCompleted(success: !Task.isCancelled)
        }
    }
}
