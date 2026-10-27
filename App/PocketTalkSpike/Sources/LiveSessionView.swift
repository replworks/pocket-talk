import SwiftUI
import PocketTalkCore

/// Tab 3 — one live turn: microphone → SpeechAnalyzer → on-device model → speech synthesis.
///
/// Every turn is written to `Documents/results/live-*.jsonl` with three latencies and the
/// real token usage. The session start/end battery and thermal state go in a `session`
/// record (TASKS.md §6).
struct LiveSessionView: View {
    @State private var model = LiveSessionModel()

    var body: some View {
        NavigationStack {
            List {
                Section("세션") {
                    if model.isRunning {
                        LabeledContent("세션 ID", value: model.sessionID)
                        LabeledContent("시작", value: model.startedAtText)
                        LabeledContent("턴", value: "\(model.turnCount)")
                        Button("세션 종료") { Task { await model.endSession() } }
                    } else {
                        Button("세션 시작") { Task { await model.startSession() } }
                    }
                    Text(model.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if model.recognizer.isRecording {
                        Button("발화 완료") { Task { await model.finishTurn() } }
                    } else {
                        Button("발화 시작") { Task { await model.startListening() } }
                            .disabled(!model.isRunning || model.isBusy)
                    }
                    if model.isBusy {
                        ProgressView()
                    }
                    Button("TTS만 확인") { Task { await model.testSpeechSynthesis() } }
                        .disabled(model.recognizer.isRecording || model.isBusy)
                } footer: {
                    Text("'발화 완료'를 누른 시각을 발화 종료로 기록한다. 실제 말이 끝난 시각과는 차이가 있다.")
                }

                Section("대화") {
                    if model.transcript.isEmpty {
                        Text("아직 대화 없음").foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.transcript.enumerated()), id: \.offset) { _, turn in
                        VStack(alignment: .leading) {
                            Text(turn.role == .user ? "나" : "Minsu")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(turn.text)
                        }
                    }
                }

                Section("턴별 지연") {
                    if model.records.isEmpty {
                        Text("기록 없음").foregroundStyle(.secondary)
                    }
                    ForEach(model.records, id: \.turnIndex) { record in
                        VStack(alignment: .leading) {
                            Text("턴 \(record.turnIndex + 1)").font(.caption)
                            Text(model.latencyText(record))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Live Session")
        }
    }
}

@MainActor
@Observable
final class LiveSessionModel {
    let recognizer = SpeechRecognizer()
    let synthesizer = SpeechSynthesis()
    let client = AppleOnDeviceClient()

    var isRunning = false
    var isBusy = false
    var status = "세션을 시작하세요"
    var sessionID = "-"
    var startedAtText = "-"
    var turnCount = 0
    var transcript: [ConversationTurn] = []
    var records: [LiveTurnLatencyRecord] = []

    private var history: [ConversationTurn] = []
    private var logger: ResultLogger?
    private var startedAt: Date?
    private var batteryStart: Double?
    private var thermalStart: String?
    private var contextManager: ContextManager?

    func startSession() async {
        let prompt = PromptAsset.systemPrompt() ?? ""
        guard !prompt.isEmpty else {
            status = "system_prompt.md를 읽지 못해 시작할 수 없다"
            return
        }

        DeviceMetrics.startMonitoring()

        sessionID = String(UUID().uuidString.prefix(8))
        startedAt = Date()
        startedAtText = Self.clock.string(from: Date())
        turnCount = 0
        transcript = []
        history = []
        records = []
        batteryStart = DeviceMetrics.batteryLevel
        thermalStart = DeviceMetrics.thermalState

        let reportedSize = AppleOnDeviceClient.contextSize() ?? 0
        let budget = reportedSize > 0 ? max(1_000, reportedSize - 512) : 3_000
        contextManager = ContextManager(
            policy: ContextPolicy(maxTokens: budget, recentTurns: 64, systemPrompt: prompt),
            tokenCounter: CharacterTokenCounter()
        )

        do {
            let fileName = "live-\(Self.fileTimestamp()).jsonl"
            logger = try ResultLogger(fileURL: MeasurementStore.resultsURL(fileName: fileName))
            status = "세션 시작 — '발화 시작'을 누르고 영어로 말하세요"
        } catch {
            status = "로그 파일 생성 실패: \(error)"
        }

        isRunning = true
        if recognizer.isSupported == nil {
            _ = await recognizer.prepare()
        }
    }

    func startListening() async {
        isBusy = true
        await recognizer.start()
        isBusy = false
        status = recognizer.isRecording
            ? "듣는 중… 말이 끝나면 '발화 완료'"
            : (recognizer.errorMessage ?? "녹음을 시작하지 못했다")
    }

    func finishTurn() async {
        guard isRunning, let contextManager else { return }
        isBusy = true
        defer { isBusy = false }

        let utteranceEnd = Date()
        let userText = await recognizer.stop()
        let recognizedAt = Date()

        guard !userText.isEmpty else {
            status = "인식된 말이 없다 — 마이크/음성 모델 확인"
            return
        }

        let prepared = contextManager.prepare(history: history, userText: userText)

        var reply = ""
        var firstTokenMilliseconds: Double?
        var usage: ModelUsage?
        do {
            let outcome = try await client.generate(
                history: prepared.historyForModel(),
                userText: prepared.userText
            )
            reply = outcome.text
            usage = outcome.usage
            if let timeToFirstToken = outcome.timeToFirstTokenMilliseconds {
                // generate() measured from its own start; the report needs it from speech end.
                firstTokenMilliseconds = timeToFirstToken
                    + recognizedAt.timeIntervalSince(utteranceEnd) * 1_000
            }
        } catch {
            status = "모델 실패: \(error)"
            return
        }

        history.append(.user(userText))
        history.append(.assistant(reply))
        transcript.append(.user(userText))
        transcript.append(.assistant(reply))

        let audioStart = await synthesizer.speakAndWaitForStart(reply)

        let record = LiveTurnLatencyRecord(
            sessionID: sessionID,
            turnIndex: turnCount,
            utteranceEndToRecognitionMilliseconds: recognizedAt.timeIntervalSince(utteranceEnd) * 1_000,
            utteranceEndToFirstTokenMilliseconds: firstTokenMilliseconds,
            utteranceEndToAudioStartMilliseconds: audioStart.map { $0.timeIntervalSince(utteranceEnd) * 1_000 },
            replyCharacters: reply.count,
            thermalState: DeviceMetrics.thermalState,
            batteryLevel: DeviceMetrics.batteryLevel,
            estimatedPromptTokens: prepared.estimatedTokens,
            foldedTurnCount: prepared.foldedTurnCount,
            droppedTurnCount: prepared.droppedTurnCount,
            inputTokens: usage?.inputTokens,
            outputTokens: usage?.outputTokens
        )

        records.append(record)
        turnCount += 1
        try? await logger?.log(record)

        if let latency = record.utteranceEndToAudioStartMilliseconds {
            status = "턴 \(turnCount) 완료 — 음성 시작까지 \(Int(latency))ms"
        } else {
            status = "턴 \(turnCount) 완료 — 음성 시작 감지 실패"
        }
    }

    /// Verifies the speech-synthesis half of the loop independently.
    /// ASR needs a physical device (SpeechTranscriber is unavailable in the simulator),
    /// but TTS can be checked here.
    func testSpeechSynthesis() async {
        let sample = "Hello! How was your weekend?"
        let peak = await synthesizer.renderedPeakAmplitude(sample)
        let startedAt = Date()
        let audioStart = await synthesizer.speakAndWaitForStart(sample)

        let peakText = peak.map { String(format: "%.3f", $0) } ?? "없음(무음)"
        if let audioStart {
            status = "TTS 시작까지 \(Int(audioStart.timeIntervalSince(startedAt) * 1_000))ms · 렌더 피크 \(peakText)"
        } else {
            status = "TTS 시작 감지 실패 · 렌더 피크 \(peakText)"
        }
    }

    func endSession() async {
        if recognizer.isRecording {
            _ = await recognizer.stop()
        }
        synthesizer.stop()

        let record = SessionRecord(
            sessionID: sessionID,
            client: "apple_ondevice",
            startedAt: startedAt ?? Date(),
            endedAt: Date(),
            batteryStart: batteryStart,
            batteryEnd: DeviceMetrics.batteryLevel,
            thermalStateStart: thermalStart,
            thermalStateEnd: DeviceMetrics.thermalState,
            turnCount: turnCount
        )
        try? await logger?.log(record)
        await logger?.close()
        logger = nil
        isRunning = false
        status = "세션 종료 — \(turnCount)턴 기록"
    }

    func latencyText(_ record: LiveTurnLatencyRecord) -> String {
        let recognition = record.utteranceEndToRecognitionMilliseconds.map { "인식 \(Int($0))ms" } ?? "인식 -"
        let firstToken = record.utteranceEndToFirstTokenMilliseconds.map { "첫토큰 \(Int($0))ms" } ?? "첫토큰 -"
        let audio = record.utteranceEndToAudioStartMilliseconds.map { "음성 \(Int($0))ms" } ?? "음성 -"
        let tokens = record.inputTokens.map { " / in \($0) out \(record.outputTokens ?? 0)" } ?? ""
        return "\(recognition) · \(firstToken) · \(audio)\(tokens)"
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    LiveSessionView()
}
