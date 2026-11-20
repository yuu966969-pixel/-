import SwiftUI
import CryptoKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("nekoAlarmChallengePending") private var challengePending = false
    @StateObject private var dailyTrack = DailyTrackGenerator.shared
    @AppStorage("nekoAlarmPasswordHash") private var passwordHash = ""
    @AppStorage("nekoAlarmHour") private var savedAlarmHour = 7
    @AppStorage("nekoAlarmMinute") private var savedAlarmMinute = 0
    @State private var alarmTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    @State private var newPassword = ""
    @State private var enteredPassword = ""
    @State private var message = ""
    @State private var customPrompt = ""
    @AppStorage("nekoAlarmAudioEndpoint") private var audioEndpoint = ""
    @State private var isSpinning = false
    @State private var quizIndex = 0
    @State private var quizPassed = false
    @State private var passwordPassed = false

    private let questions: [(String, [String], Int)] = [
        ("日本の首都は？", ["東京", "大阪", "京都", "札幌"], 0),
        ("7 × 8 は？", ["54", "56", "64", "48"], 1),
        ("水の化学式は？", ["CO₂", "O₂", "H₂O", "NaCl"], 2)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("🐱").font(.system(size: 76))
                            .rotationEffect(.degrees(isSpinning ? 360 : 0))
                            .animation(isSpinning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSpinning)
                        Text("猫ミーム地獄アラーム")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("起きるまで、猫は止まらない（アプリ内演出）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    GroupBox("① 今日のランダム曲") {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(dailyTrack.status, systemImage: dailyTrack.hasTrackForToday ? "checkmark.circle.fill" : "waveform")
                            Button {
                                Task { await dailyTrack.generateForToday() }
                            } label: {
                                Label("今日の曲を生成・再試行", systemImage: "sparkles")
                            }
                            .disabled(dailyTrack.isGenerating || dailyTrack.hasTrackForToday)
                            Button {
                                dailyTrack.preview()
                            } label: {
                                Label("今日の曲を試聴", systemImage: "play.fill")
                            }
                            .disabled(!dailyTrack.hasTrackForToday)
                            Text("AI音源サーバーがあればAI生成し、未設定・接続失敗時は端末内でオリジナルのランダム曲を作ります。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    GroupBox("② AIに好きな曲を作ってもらう") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AIサーバーURL（HTTPS）")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("https://あなたのサーバー.example/api/generate", text: $audioEndpoint)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityLabel("AI作曲サーバーURL")
                            Text("APIキーはここに入力しないでください。サーバー側の環境変数で安全に管理します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("どんな曲にしたいか、自由に書いてね。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("例：朝に元気が出る、猫っぽくて明るい電子音楽", text: $customPrompt, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                                .accessibilityLabel("作曲リクエスト")
                            Button {
                                Task { await dailyTrack.generateForToday(prompt: customPrompt) }
                            } label: {
                                Label("この内容でAI作曲する", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(dailyTrack.isGenerating || customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customPrompt.count > 300)
                            if customPrompt.count > 300 {
                                Text("リクエストは300文字以内にしてください。")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            if let trackURL = dailyTrack.downloadableTrackURL {
                                ShareLink(item: trackURL) {
                                    Label("完成した曲を保存・共有", systemImage: "square.and.arrow.down")
                                }
                            }
                            Text("AIサーバーが設定されている場合に作曲できます。完成した音源はWAV形式で保存・共有できます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox("③ アラーム時刻") {
                        DatePicker("鳴らす時刻", selection: $alarmTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }

                    GroupBox("④ 解除パスワード") {
                        VStack(alignment: .leading, spacing: 10) {
                            SecureField("4文字以上のパスワード", text: $newPassword)
                                .textFieldStyle(.roundedBorder)
                            Button("パスワードを保存") {
                                guard newPassword.count >= 4 else {
                                    message = "パスワードは4文字以上にしてください。"
                                    return
                                }
                                passwordHash = Self.hash(newPassword)
                                newPassword = ""
                                enteredPassword = ""
                                passwordPassed = false
                                quizPassed = false
                                message = "パスワードを保存しました。"
                            }
                            .buttonStyle(.borderedProminent)
                            Text(passwordHash.isEmpty ? "まだ設定されていません" : "パスワード設定済み")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task {
                            do {
                                await dailyTrack.generateIfNeeded()
                                let soundName = try? dailyTrack.prepareAlarmSound()
                                let components = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
                                _ = try await AlarmScheduler.schedule(
                                    hour: components.hour ?? 7,
                                    minute: components.minute ?? 0,
                                    soundResourceName: soundName
                                )
                                message = soundName == nil
                                    ? "毎日のアラームを予約しました。曲が未準備のためシステム音を使います。"
                                    : "毎日のアラームを予約しました。"
                            } catch {
                                message = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("アラームを予約する", systemImage: "alarm.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)

                    GroupBox("⑤ アラーム停止後の起床チェック（アプリ内）") {
                        VStack(alignment: .leading, spacing: 12) {
                            SecureField("保存したパスワードを入力", text: $enteredPassword)
                                .textFieldStyle(.roundedBorder)
                            Button("パスワードを確認") {
                                guard !passwordHash.isEmpty, Self.hash(enteredPassword) == passwordHash else {
                                    passwordPassed = false
                                    quizPassed = false
                                    message = "パスワードが違います。"
                                    return
                                }
                                passwordPassed = true
                                quizIndex = 0
                                quizPassed = false
                                message = "パスワードOK！クイズに進めます。"
                            }
                            .buttonStyle(.bordered)

                            if passwordPassed {
                                Text(questions[quizIndex].0)
                                    .font(.headline)
                                ForEach(questions[quizIndex].1.indices, id: \.self) { index in
                                    Button(questions[quizIndex].1[index]) {
                                        if index == questions[quizIndex].2 {
                                            if quizIndex < questions.count - 1 {
                                                quizIndex += 1
                                                message = "正解！次の問題です。"
                                            } else {
                                                quizPassed = true
                                                message = "全問正解！アプリ内クイズをクリアしました。"
                                            }
                                        } else {
                                            message = "不正解。もう一度挑戦！"
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if quizPassed {
                                    Label("クイズクリア！", systemImage: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                }
                            } else {
                                Text("パスワードを確認するとクイズが表示されます。アラームのシステム停止そのものをブロックする機能ではありません。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(isSpinning ? "猫ミームを止める" : "猫ミーム演出を試す") {
                        isSpinning.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Neko Alarm")
        }
        .onAppear {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour = savedAlarmHour
            components.minute = savedAlarmMinute
            alarmTime = Calendar.current.date(from: components) ?? alarmTime
            handleAlarmStopIfNeeded()
        }
        .onChange(of: alarmTime) { _, value in
            let components = Calendar.current.dateComponents([.hour, .minute], from: value)
            savedAlarmHour = components.hour ?? 7
            savedAlarmMinute = components.minute ?? 0
        }
        .onChange(of: challengePending) { _, pending in
            if pending { handleAlarmStopIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { handleAlarmStopIfNeeded() }
        }
    }

    private func handleAlarmStopIfNeeded() {
        guard challengePending else { return }
        challengePending = false
        passwordPassed = false
        quizPassed = false
        quizIndex = 0
        enteredPassword = ""
        message = "アラームを停止しました。起床チェックに進んでください。"
        Task {
            await dailyTrack.generateIfNeeded()
            await AlarmScheduler.refreshSavedAlarm()
        }
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
