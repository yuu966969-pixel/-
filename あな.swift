import Foundation
import Combine
import AVFoundation

@MainActor
final class DailyTrackGenerator: ObservableObject {
    static let shared = DailyTrackGenerator()
    @Published private(set) var status = "今日の曲を確認しています"
    @Published private(set) var trackDate: String?
    @Published private(set) var isGenerating = false
    private var player: AVAudioPlayer?
    private let defaultsKey = "nekoAlarmGeneratedTrackDate"

    private init() { trackDate = UserDefaults.standard.string(forKey: defaultsKey) }

    var todayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var trackURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NekoAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("daily-\(todayKey).mp3")
    }

    var hasTrackForToday: Bool {
        trackDate == todayKey && FileManager.default.fileExists(atPath: trackURL.path)
    }

    /// AlarmKit reads custom sounds from the app bundle or Library/Sounds.
    /// Copy today's generated file there and return its resource name.
    func prepareAlarmSound() throws -> String {
        guard hasTrackForToday else { throw TrackError.noTrack }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let sounds = library.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        let resourceName = "neko-daily-\(todayKey)"
        let destination = sounds.appendingPathComponent(resourceName + ".mp3")
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: trackURL, to: destination)
        }
        return resourceName
    }

    func generateIfNeeded() async {
        guard !hasTrackForToday, !isGenerating else { return }
        await generateForToday()
    }

    func generateForToday() async {
        guard !isGenerating else { return }
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "NEKO_AI_AUDIO_ENDPOINT") as? String,
              let endpoint = URL(string: raw), !raw.isEmpty else {
            status = "AI音源サーバー未設定。READMEを確認してください。"
            return
        }
        isGenerating = true
        status = "今日の爆音曲をAI生成中…"
        defer { isGenerating = false }

        let prompt = """
        Create an original, attention-grabbing 20-second alarm instrumental.
        Randomize genre, rhythm, synth timbres and structure each day.
        Use punchy electronic percussion, dramatic bass and surprising sound design.
        No copyrighted melodies, no existing songs, no speech, no clipping.
        Date seed: \(todayKey). Make today's result distinct.
        """
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 180
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "date": todayKey, "prompt": prompt, "format": "mp3"
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode), data.count > 8_000 else {
                throw TrackError.server
            }
            try data.write(to: trackURL, options: .atomic)
            trackDate = todayKey
            UserDefaults.standard.set(todayKey, forKey: defaultsKey)
            status = "今日の曲が完成！"
        } catch {
            status = "生成できませんでした。次回起動時に再試行します。"
        }
    }

    func preview() {
        guard hasTrackForToday else { status = "今日の曲はまだありません。"; return }
        do {
            player = try AVAudioPlayer(contentsOf: trackURL)
            player?.prepareToPlay()
            player?.play()
        } catch { status = "曲を再生できませんでした。" }
    }

    enum TrackError: LocalizedError {\n        case server, noTrack\n        var errorDescription: String? {\n            switch self {\n            case .server: return "AI音源サーバーから曲を取得できませんでした。"\n            case .noTrack: return "今日のAI曲がまだ生成されていません。"\n            }\n        }\n    }
}
