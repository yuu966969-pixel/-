import SwiftUI
import CryptoKit

struct ContentView: View {
    @StateObject private var dailyTrack = DailyTrackGenerator.shared
    @AppStorage("nekoAlarmPasswordHash") private var passwordHash = ""
    @State private var alarmTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    @State private var newPassword = ""
    @State private var enteredPassword = ""
    @State private var message = ""
    @State private var isSpinning = false
    @State private var quizIndex = 0
    @State private var quizPassed = false

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

                    GroupBox("① 今日のランダムAI曲") {
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
                            Text("日付ごとに1曲を保存。AlarmKitのアラーム音にも使います。生成通知は出しません。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    GroupBox("② アラーム時刻") {
                        DatePicker("鳴らす時刻", selection: $alarmTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }

                    GroupBox("③ 解除パスワード") {
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
                                let soundName = try dailyTrack.prepareAlarmSound()
                                let components = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
                                _ = try await AlarmScheduler.schedule(
                                    hour: components.hour ?? 7,
                                    minute: components.minute ?? 0,
                                    soundResourceName: soundName
                                )
                                message = "アラームを予約しました。ロック画面にもカウントダウンが表示されます。"
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

                    GroupBox("④ アプリ内の解除テスト") {
                        VStack(alignment: .leading, spacing: 12) {
                            SecureField("保存したパスワードを入力", text: $enteredPassword)
                                .textFieldStyle(.roundedBorder)
                            Button("パスワードを確認") {
                                guard !passwordHash.isEmpty, Self.hash(enteredPassword) == passwordHash else {
                                    message = "パスワードが違います。"
                                    return
                                }
                                quizIndex = 0
                                quizPassed = false
                                message = "パスワードOK！クイズに進めます。"
                            }
                            .buttonStyle(.bordered)

                            if !passwordHash.isEmpty {
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
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
