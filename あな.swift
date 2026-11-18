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

    private var folderURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NekoAlarm", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private var remoteTrackURL: URL {
        folderURL.appendingPathComponent("daily-\(todayKey).mp3")
    }

    private var localTrackURL: URL {
        folderURL.appendingPathComponent("daily-\(todayKey).wav")
    }

    private var currentTrackURL: URL? {
        if FileManager.default.fileExists(atPath: remoteTrackURL.path) { return remoteTrackURL }
        if FileManager.default.fileExists(atPath: localTrackURL.path) { return localTrackURL }
        return nil
    }

    var hasTrackForToday: Bool {
        trackDate == todayKey && currentTrackURL != nil
    }

    /// AlarmKit reads custom sounds from the app bundle or Library/Sounds.
    /// Copy today's generated file there and return its resource name.
    func prepareAlarmSound() throws -> String {
        guard hasTrackForToday, let source = currentTrackURL else { throw TrackError.noTrack }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let sounds = library.appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: sounds, withIntermediateDirectories: true)
        let resourceName = "neko-daily-\(todayKey)"
        let destination = sounds.appendingPathComponent(resourceName + "." + source.pathExtension)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        // Include the extension: AlarmKit resolves the complete sound filename.
        return resourceName + "." + source.pathExtension
    }

    func generateIfNeeded() async {
        guard !hasTrackForToday, !isGenerating else { return }
        await generateForToday()
    }

    func generateForToday() async {
        guard !isGenerating else { return }
        isGenerating = true
        status = "今日の曲を生成中…"
        defer { isGenerating = false }

        let endpointString = Bundle.main.object(forInfoDictionaryKey: "NEKO_AI_AUDIO_ENDPOINT") as? String
        if let raw = endpointString, !raw.isEmpty, let endpoint = URL(string: raw) {
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
                try data.write(to: remoteTrackURL, options: .atomic)
                saveTrackDate()
                status = "今日のAI曲が完成！"
                return
            } catch {
                // Keep the alarm usable offline if the optional AI service is unavailable.
            }
        }

        do {
            let wav = Self.makeDailyWAV(seed: todayKey)
            try wav.write(to: localTrackURL, options: .atomic)
            saveTrackDate()
            status = endpointString == nil || endpointString?.isEmpty == true
                ? "AIサーバー未設定。端末内で今日のランダム曲を作成しました。"
                : "AI生成に接続できなかったため、端末内のランダム曲を作成しました。"
        } catch {
            status = "今日の曲を作成できませんでした。次回起動時に再試行します。"
        }
    }

    private func saveTrackDate() {
        trackDate = todayKey
        UserDefaults.standard.set(todayKey, forKey: defaultsKey)
    }

    /// Creates a short, original daily instrumental locally. This is procedural audio, not AI.
    private static func makeDailyWAV(seed date: String) -> Data {
        let sampleRate: UInt32 = 22_050
        let duration = 20.0
        let frameCount = Int(Double(sampleRate) * duration)
        var seed = date.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
        func nextRandom() -> UInt32 {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return seed
        }

        let scale: [Double] = [0, 3, 5, 7, 10, 12, 15, 17]
        let melody = (0..<40).map { _ in scale[Int(nextRandom() % UInt32(scale.count))] }
        var samples = [Int16]()
        samples.reserveCapacity(frameCount)

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            let beatPosition = time / 0.5
            let beat = Int(beatPosition)
            let beatPhase = beatPosition - Double(beat)
            let withinBeat = beatPhase * 0.5
            var value = 0.0

            // Soft kick on beats 1 and 3.
            if (beat % 4 == 0 || beat % 4 == 2) && withinBeat < 0.20 {
                let envelope = exp(-withinBeat * 17.0)
                let sweep = 55.0 - 22.0 * withinBeat
                value += sin(2.0 * .pi * sweep * withinBeat) * envelope * 0.42
            }

            // Light snare and hi-hat texture.
            let noiseSeed = (UInt32(frame) &* 1_103_515_245 &+ seed) % 65_536
            let noise = (Double(noiseSeed) / 32_768.0) - 1.0
            if (beat % 4 == 1 || beat % 4 == 3) && withinBeat < 0.10 {
                value += noise * exp(-withinBeat * 34.0) * 0.10
            }
            if beatPhase > 0.48 && beatPhase < 0.58 {
                value += noise * 0.035
            }

            // Daily randomized pentatonic melody.
            let semitone = melody[min(39, max(0, beat))]
            let frequency = 220.0 * pow(2.0, semitone / 12.0)
            let melodyEnvelope = min(1.0, withinBeat * 18.0) * exp(-withinBeat * 2.8)
            value += sin(2.0 * .pi * frequency * time) * melodyEnvelope * 0.16
            value += sin(2.0 * .pi * frequency * 2.0 * time) * melodyEnvelope * 0.035

            // Warm bass pulse every two seconds.
            let barPhase = time.truncatingRemainder(dividingBy: 2.0)
            let bassEnvelope = exp(-barPhase * 1.7)
            let bassFrequency = beat % 8 < 4 ? 55.0 : 65.4
            value += sin(2.0 * .pi * bassFrequency * time) * bassEnvelope * 0.12

            let clipped = max(-0.82, min(0.82, value))
            samples.append(Int16(clipped * 32_767.0))
        }

        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            let bits = UInt16(bitPattern: sample)
            pcm.append(UInt8(bits & 0xff))
            pcm.append(UInt8((bits >> 8) & 0xff))
        }

        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        appendLE(UInt32(36 + pcm.count), to: &wav)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        appendLE(UInt32(16), to: &wav)
        appendLE(UInt16(1), to: &wav) // PCM
        appendLE(UInt16(1), to: &wav) // mono
        appendLE(sampleRate, to: &wav)
        appendLE(sampleRate * 2, to: &wav)
        appendLE(UInt16(2), to: &wav)
        appendLE(UInt16(16), to: &wav)
        wav.append(contentsOf: "data".utf8)
        appendLE(UInt32(pcm.count), to: &wav)
        wav.append(pcm)
        return wav
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    func preview() {
        guard hasTrackForToday, let url = currentTrackURL else {
            status = "今日の曲はまだありません。"
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            status = "曲を再生できませんでした。"
        }
    }

    enum TrackError: LocalizedError {
        case server, noTrack

        var errorDescription: String? {
            switch self {
            case .server:
                return "AI音源サーバーから曲を取得できませんでした。"
            case .noTrack:
                return "今日の曲がまだ生成されていません。"
            }
        }
    }
}
