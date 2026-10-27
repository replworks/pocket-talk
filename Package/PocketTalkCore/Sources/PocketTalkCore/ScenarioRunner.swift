import Foundation

/// One learner turn inside a `ScenarioRun`, with the context measurements for that turn.
public struct ScenarioTurnResult: Codable, Equatable, Sendable {
    public var index: Int
    public var userText: String
    public var reply: String
    public var modelMilliseconds: Double
    public var estimatedPromptTokens: Int
    public var promptTurnCount: Int
    public var foldedTurnCount: Int
    public var droppedTurnCount: Int
    public var didDropSummary: Bool
    public var didTruncateUserText: Bool
    /// Real token usage when the client reports it (Apple on-device only).
    public var usage: ModelUsage?

    public init(
        index: Int,
        userText: String,
        reply: String,
        modelMilliseconds: Double,
        estimatedPromptTokens: Int,
        promptTurnCount: Int,
        foldedTurnCount: Int,
        droppedTurnCount: Int,
        didDropSummary: Bool,
        didTruncateUserText: Bool,
        usage: ModelUsage? = nil
    ) {
        self.index = index
        self.userText = userText
        self.reply = reply
        self.modelMilliseconds = modelMilliseconds
        self.estimatedPromptTokens = estimatedPromptTokens
        self.promptTurnCount = promptTurnCount
        self.foldedTurnCount = foldedTurnCount
        self.droppedTurnCount = droppedTurnCount
        self.didDropSummary = didDropSummary
        self.didTruncateUserText = didTruncateUserText
        self.usage = usage
    }
}

/// Result of running one scenario end to end.
public struct ScenarioRun: Codable, Equatable, Sendable {
    public var runID: String
    public var scenarioID: String
    public var topic: String
    public var client: String
    public var startedAt: Date
    public var durationMilliseconds: Double
    public var completed: Bool
    public var errorMessage: String?
    public var transcript: [ConversationTurn]
    public var turns: [ScenarioTurnResult]

    public init(
        runID: String,
        scenarioID: String,
        topic: String,
        client: String,
        startedAt: Date,
        durationMilliseconds: Double,
        completed: Bool,
        errorMessage: String?,
        transcript: [ConversationTurn],
        turns: [ScenarioTurnResult]
    ) {
        self.runID = runID
        self.scenarioID = scenarioID
        self.topic = topic
        self.client = client
        self.startedAt = startedAt
        self.durationMilliseconds = durationMilliseconds
        self.completed = completed
        self.errorMessage = errorMessage
        self.transcript = transcript
        self.turns = turns
    }

    public var totalEstimatedPromptTokens: Int {
        turns.reduce(0) { $0 + $1.estimatedPromptTokens }
    }

    public var maxFoldedTurnCount: Int {
        turns.map(\.foldedTurnCount).max() ?? 0
    }
}

/// Runs scripted scenarios against a `LanguageModelClient`.
///
/// A failure on one turn is captured in `ScenarioRun.completed`/`errorMessage` instead of
/// aborting a 20-scenario batch: the spike needs to know how many scenarios finish, not
/// to crash on the first model error.
public struct ScenarioRunner: Sendable {
    public let client: any LanguageModelClient
    public let contextManager: ContextManager

    public init(client: any LanguageModelClient, contextManager: ContextManager) {
        self.client = client
        self.contextManager = contextManager
    }

    public func run(
        _ scenario: Scenario,
        runID: String = UUID().uuidString,
        logger: ResultLogger? = nil
    ) async -> ScenarioRun {
        let startedAt = Date()
        let clock = ContinuousClock()
        let scenarioStart = clock.now

        // The AI speaks first, so its opening line is part of the history.
        var transcript: [ConversationTurn] = [.assistant(scenario.openingPrompt)]
        var turnResults: [ScenarioTurnResult] = []
        var completed = true
        var errorMessage: String?

        for (index, userText) in scenario.userTurns.enumerated() {
            let prepared = contextManager.prepare(history: transcript, userText: userText)

            let turnStart = clock.now
            do {
                let reply = try await client.respond(
                    history: prepared.historyForModel(),
                    userText: prepared.userText
                )
                let elapsed = milliseconds(clock.now - turnStart)
                let usage = await Self.usage(of: client)

                transcript.append(.user(userText))
                transcript.append(.assistant(reply))

                turnResults.append(
                    ScenarioTurnResult(
                        index: index,
                        userText: userText,
                        reply: reply,
                        modelMilliseconds: elapsed,
                        estimatedPromptTokens: prepared.estimatedTokens,
                        promptTurnCount: prepared.historyForModel().count,
                        foldedTurnCount: prepared.foldedTurnCount,
                        droppedTurnCount: prepared.droppedTurnCount,
                        didDropSummary: prepared.didDropSummary,
                        didTruncateUserText: prepared.didTruncateUserText,
                        usage: usage
                    )
                )
            } catch {
                completed = false
                errorMessage = String(describing: error)
                break
            }
        }

        let run = ScenarioRun(
            runID: runID,
            scenarioID: scenario.id,
            topic: scenario.topic,
            client: client.identifier,
            startedAt: startedAt,
            durationMilliseconds: milliseconds(clock.now - scenarioStart),
            completed: completed,
            errorMessage: errorMessage,
            transcript: transcript,
            turns: turnResults
        )

        if let logger {
            try? await logger.log(record(for: run))
        }
        return run
    }

    public func runAll(
        _ scenarios: [Scenario],
        runID: String = UUID().uuidString,
        logger: ResultLogger? = nil
    ) async -> [ScenarioRun] {
        var runs: [ScenarioRun] = []
        for scenario in scenarios {
            runs.append(await run(scenario, runID: runID, logger: logger))
        }
        return runs
    }

    public func record(for run: ScenarioRun) -> ScenarioResultRecord {
        ScenarioResultRecord(
            runID: run.runID,
            scenarioID: run.scenarioID,
            topic: run.topic,
            client: run.client,
            startedAt: run.startedAt,
            durationMilliseconds: run.durationMilliseconds,
            completed: run.completed,
            errorMessage: run.errorMessage,
            foldedTurnCount: run.maxFoldedTurnCount,
            droppedTurnCount: run.turns.map(\.droppedTurnCount).max() ?? 0,
            turns: run.turns.map { turn in
                TurnResultRecord(
                    index: turn.index,
                    userText: turn.userText,
                    reply: turn.reply,
                    modelMilliseconds: turn.modelMilliseconds,
                    estimatedPromptTokens: turn.estimatedPromptTokens,
                    promptTurnCount: turn.promptTurnCount,
                    foldedTurnCount: turn.foldedTurnCount,
                    droppedTurnCount: turn.droppedTurnCount,
                    didDropSummary: turn.didDropSummary,
                    didTruncateUserText: turn.didTruncateUserText,
                    inputTokens: turn.usage?.inputTokens,
                    outputTokens: turn.usage?.outputTokens,
                    cachedInputTokens: turn.usage?.cachedInputTokens,
                    contextSize: turn.usage?.contextSize
                )
            }
        )
    }

    private static func usage(of client: any LanguageModelClient) async -> ModelUsage? {
        guard let reporting = client as? any UsageReportingLanguageModelClient else { return nil }
        return await reporting.usageSnapshot()
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
