import SwiftUI
import PocketTalkCore

/// Tab 1 — runs `eval/scenarios.json` through a client and writes JSONL.
///
/// The mock path verifies the measurement plumbing offline. The Apple path uses the
/// on-device model and records the *real* input/output token counts the framework
/// reports; on a machine without Apple Intelligence it records the failure instead of
/// pretending to measure.
struct ScenarioRunnerView: View {
    private enum ClientChoice: String, CaseIterable, Identifiable {
        case mock
        case apple

        var id: String { rawValue }
        var label: String { rawValue }
    }

    /// Three context policies over the same 34-turn script (TASKS.md §5).
    private enum LongRunMode: String, CaseIterable, Identifiable {
        case noFold
        case defaultFold
        case recommended
        case tight

        var id: String { rawValue }

        var label: String {
            switch self {
            case .noFold: return "요약 없음"
            case .defaultFold: return "요약 8턴"
            case .recommended: return "기본 64"
            case .tight: return "요약 700"
            }
        }
    }

    private let mockBudget = 7_000
    private let outputReserve = 512
    private let fallbackBudget = 3_000

    @State private var clientChoice: ClientChoice = .mock
    @State private var scenarios: [Scenario] = []
    @State private var systemPrompt: String?
    @State private var statusLine = "대기 중"
    @State private var isRunning = false
    @State private var runs: [ScenarioRun] = []
    @State private var logFileName: String?
    @State private var longMode: LongRunMode = .defaultFold
    @State private var longStatus = "대기 중"
    @State private var longFileName: String?
    @State private var cacheStatus = "대기 중"
    @State private var cacheFileName: String?

    private var appleAvailability: AppleOnDeviceAvailability {
        AppleOnDeviceClient.availability()
    }

    private var appleContextSize: Int? {
        AppleOnDeviceClient.contextSize()
    }

    private var effectiveMaxTokens: Int {
        switch clientChoice {
        case .mock:
            return mockBudget
        case .apple:
            // On iOS 27.0.1 the device reported contextSize 0 once; treat that as unknown
            // instead of collapsing the budget to nothing.
            guard let size = appleContextSize, size > 0 else { return fallbackBudget }
            return max(256, min(mockBudget, size - outputReserve))
        }
    }

    private var canRun: Bool {
        !isRunning && !scenarios.isEmpty && systemPrompt != nil
            && (clientChoice == .mock || appleAvailability.isAvailable)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("클라이언트") {
                    Picker("모델", selection: $clientChoice) {
                        ForEach(ClientChoice.allCases) { choice in
                            Text(choice.label).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch clientChoice {
                    case .mock:
                        Text("고정 응답. 품질 측정값이 아니라 배관 검증용이다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .apple:
                        Text(appleAvailability.description)
                            .font(.caption)
                            .foregroundStyle(appleAvailability.isAvailable ? Color.secondary : Color.orange)
                    }
                }

                Section("설정") {
                    LabeledContent("시나리오", value: "\(scenarios.count)개")
                    LabeledContent("컨텍스트 예산", value: "\(effectiveMaxTokens) 토큰")
                    if let appleContextSize, appleContextSize > 0 {
                        LabeledContent("모델 컨텍스트", value: "\(appleContextSize) 토큰")
                    } else if clientChoice == .apple {
                        LabeledContent("모델 컨텍스트", value: "확인 불가 (예산 \(fallbackBudget))")
                    }
                    LabeledContent("시스템 프롬프트", value: systemPrompt == nil ? "없음" : "eval/system_prompt.md")
                }

                Section {
                    Button(isRunning ? "실행 중…" : "\(clientChoice.label)으로 전체 실행") {
                        Task { await runAll() }
                    }
                    .disabled(!canRun)
                } footer: {
                    Text("결과는 Documents/results/ 에 JSONL로 쌓인다. 파일 앱으로 꺼낸다.")
                }

                Section {
                    Picker("컨텍스트 정책", selection: $longMode) {
                        ForEach(LongRunMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("장기 대화 실행") {
                        Task { await runLongConversation() }
                    }
                    .disabled(isRunning || systemPrompt == nil || (clientChoice == .apple && !appleAvailability.isAvailable))

                    Text(longStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let longFileName {
                        Text("Documents/results/\(longFileName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("장기 대화 (34턴)")
                } footer: {
                    Text("같은 34턴 스크립트를 요약 정책만 바꿔 실행한다. 앞 내용 기억 상실 지점을 비교한다.")
                }

                Section {
                    Button("캐시 실험 실행 (10턴 × 2)") {
                        Task { await runCacheExperiment() }
                    }
                    .disabled(isRunning || systemPrompt == nil || (clientChoice == .apple && !appleAvailability.isAvailable))

                    Text(cacheStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cacheFileName {
                        Text("Documents/results/\(cacheFileName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("캐시 재사용 실험")
                } footer: {
                    Text("같은 10턴을 (A) 턴마다 새 세션 (B) 세션 재사용으로 실행해 지연과 캐시 토큰을 비교한다.")
                }

                Section("상태") {
                    Text(statusLine)
                    if let turn = runs.last?.turns.last {
                        Text("마지막 턴: 추정 \(turn.estimatedPromptTokens) 토큰")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let usage = turn.usage {
                            Text(
                                "실측 모델 토큰: 입력 \(usage.inputTokens ?? -1) / 출력 \(usage.outputTokens ?? -1)"
                                    + (usage.contextSize.map { " / 컨텍스트 \($0)" } ?? "")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    if let logFileName {
                        Text("Documents/results/\(logFileName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("결과") {
                    if runs.isEmpty {
                        Text("실행 전").foregroundStyle(.secondary)
                    } else {
                        ForEach(runs, id: \.scenarioID) { run in
                            HStack {
                                Image(systemName: run.completed ? "checkmark.circle" : "xmark.octagon")
                                    .foregroundStyle(run.completed ? Color.green : Color.red)
                                VStack(alignment: .leading) {
                                    Text(run.scenarioID)
                                    Text(run.errorMessage ?? run.topic)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text("\(run.turns.count)턴").font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scenario Runner")
            .task {
                await prepare()
                await autoRunIfRequested()
            }
        }
    }

    /// Device runs are driven from a Mac with `devicectl ... -- --autorun-apple`, because
    /// a free developer profile cannot install the UI test runner alongside this app.
    private func autoRunIfRequested() async {
        if ProcessInfo.processInfo.arguments.contains("--autorun-cache") {
            clientChoice = .apple
            guard appleAvailability.isAvailable else {
                statusLine = "캐시 실험 중단 — Apple Intelligence \(appleAvailability.description)"
                return
            }
            await runCacheExperiment()
            return
        }

        guard ProcessInfo.processInfo.arguments.contains("--autorun-apple") else { return }
        clientChoice = .apple

        guard appleAvailability.isAvailable else {
            statusLine = "자동 실행 중단 — Apple Intelligence \(appleAvailability.description)"
            return
        }
        await runAll()
    }

    private func prepare() async {
        do {
            guard let url = Bundle.main.url(forResource: "scenarios", withExtension: "json") else {
                statusLine = "번들에 scenarios.json이 없다"
                return
            }
            scenarios = try ScenarioSet.load(contentsOf: url)
        } catch {
            statusLine = "시나리오 로드 실패: \(error)"
            return
        }

        guard let prompt = PromptAsset.systemPrompt() else {
            statusLine = "system_prompt.md를 번들에서 읽지 못했다"
            return
        }
        systemPrompt = prompt
        statusLine = "준비 완료 — \(scenarios.count)개"
    }

    private func runAll() async {
        guard let systemPrompt else { return }
        isRunning = true
        defer { isRunning = false }

        do {
            let fileName = "scenarios-\(clientChoice.rawValue)-\(Self.timestamp()).jsonl"
            let url = try MeasurementStore.resultsURL(fileName: fileName)
            let logger = try ResultLogger(fileURL: url)

            let runner = ScenarioRunner(
                client: makeClient(),
                contextManager: ContextManager(
                    policy: ContextPolicy(
                        maxTokens: effectiveMaxTokens,
                        recentTurns: 64,
                        systemPrompt: systemPrompt
                    ),
                    tokenCounter: CharacterTokenCounter()
                )
            )

            statusLine = "실행 중…"
            let result = await runner.runAll(scenarios, logger: logger)
            await logger.close()

            runs = result
            logFileName = fileName
            let completed = result.filter(\.completed).count
            if let firstError = result.first(where: { !$0.completed })?.errorMessage {
                statusLine = "완료 \(completed)/\(result.count) — 첫 오류: \(firstError)"
            } else {
                statusLine = "완료 \(completed)/\(result.count)"
            }
        } catch {
            statusLine = "실행 실패: \(error)"
        }
    }

    private func runCacheExperiment() async {
        guard let systemPrompt else { return }
        isRunning = true
        defer { isRunning = false }

        cacheStatus = "실행 중… (약 40초)"
        let result = await CacheExperiment.run(systemPrompt: systemPrompt, compactPrompt: PromptAsset.compactSystemPrompt())
        if result.hasSuffix(".jsonl") {
            cacheFileName = result
            cacheStatus = "완료 — \(result)"
        } else {
            cacheStatus = result
        }
    }

    private func runLongConversation() async {
        guard let systemPrompt else { return }
        isRunning = true
        defer { isRunning = false }

        do {
            guard let url = Bundle.main.url(forResource: "long_conversation", withExtension: "json") else {
                longStatus = "번들에 long_conversation.json이 없다"
                return
            }
            guard let scenario = try ScenarioSet.load(contentsOf: url, turnRange: 30...100).first else {
                longStatus = "장기 대화 스크립트가 비어 있다"
                return
            }

            let policy: ContextPolicy
            switch longMode {
            case .noFold:
                policy = ContextPolicy(maxTokens: 8_000, recentTurns: 100, systemPrompt: systemPrompt)
            case .defaultFold:
                policy = ContextPolicy(maxTokens: effectiveMaxTokens, recentTurns: 8, systemPrompt: systemPrompt)
            case .recommended:
                policy = ContextPolicy(maxTokens: effectiveMaxTokens, recentTurns: 64, systemPrompt: systemPrompt)
            case .tight:
                policy = ContextPolicy(maxTokens: 700, recentTurns: 8, systemPrompt: systemPrompt)
            }

            let fileName = "long-\(longMode.rawValue)-\(Self.timestamp()).jsonl"
            let logger = try ResultLogger(fileURL: MeasurementStore.resultsURL(fileName: fileName))
            let runner = ScenarioRunner(
                client: makeClient(),
                contextManager: ContextManager(policy: policy, tokenCounter: CharacterTokenCounter())
            )

            longStatus = "실행 중…"
            let result = await runner.runAll([scenario], logger: logger)
            await logger.close()

            longFileName = fileName
            let completed = result.filter(\.completed).count
            if let error = result.first(where: { !$0.completed })?.errorMessage {
                longStatus = "완료 \(completed)/1 · \(longMode.label) — 오류: \(error)"
            } else {
                longStatus = "완료 \(completed)/1 · \(longMode.label) — \(result.first?.turns.count ?? 0)턴"
            }
        } catch {
            longStatus = "실패: \(error)"
        }
    }

    private func makeClient() -> any LanguageModelClient {
        switch clientChoice {
        case .mock:
            return MockLanguageModelClient(identifier: "mock", responses: Self.mockReplies)
        case .apple:
            return AppleOnDeviceClient()
        }
    }

    private static let mockReplies = [
        "(mock) That sounds nice! What happened next?",
        "(mock) I see. Why do you think so?",
    ]

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    ScenarioRunnerView()
}
