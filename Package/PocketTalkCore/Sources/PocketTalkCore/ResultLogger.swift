import Foundation

/// One row of `eval/results/<client>.jsonl`.
public struct ScenarioResultRecord: Codable, Equatable, Sendable {
    public static let kind = "scenario"

    public var kind: String
    public var runID: String
    public var scenarioID: String
    public var topic: String
    public var client: String
    public var startedAt: Date
    public var durationMilliseconds: Double
    public var completed: Bool
    public var errorMessage: String?
    public var foldedTurnCount: Int
    public var droppedTurnCount: Int
    public var turns: [TurnResultRecord]

    public init(
        kind: String = ScenarioResultRecord.kind,
        runID: String,
        scenarioID: String,
        topic: String,
        client: String,
        startedAt: Date,
        durationMilliseconds: Double,
        completed: Bool,
        errorMessage: String?,
        foldedTurnCount: Int,
        droppedTurnCount: Int,
        turns: [TurnResultRecord]
    ) {
        self.kind = kind
        self.runID = runID
        self.scenarioID = scenarioID
        self.topic = topic
        self.client = client
        self.startedAt = startedAt
        self.durationMilliseconds = durationMilliseconds
        self.completed = completed
        self.errorMessage = errorMessage
        self.foldedTurnCount = foldedTurnCount
        self.droppedTurnCount = droppedTurnCount
        self.turns = turns
    }
}

public struct TurnResultRecord: Codable, Equatable, Sendable {
    public var index: Int
    public var userText: String
    public var reply: String
    /// Measured round trip of `LanguageModelClient.respond`, in milliseconds.
    public var modelMilliseconds: Double
    public var estimatedPromptTokens: Int
    public var promptTurnCount: Int
    public var foldedTurnCount: Int
    public var droppedTurnCount: Int
    public var didDropSummary: Bool
    public var didTruncateUserText: Bool
    /// Real usage from the model, nil for the mock client.
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var cachedInputTokens: Int?
    public var contextSize: Int?

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
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        contextSize: Int? = nil
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
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.contextSize = contextSize
    }
}

/// Live-session turn latency (tab 3). Filled by the app once speech is wired up (M3+).
public struct LiveTurnLatencyRecord: Codable, Equatable, Sendable {
    public static let kind = "live_turn"

    public var kind: String
    public var sessionID: String
    public var turnIndex: Int
    /// Speech end → final recognition result.
    public var utteranceEndToRecognitionMilliseconds: Double?
    /// Speech end → first model token.
    public var utteranceEndToFirstTokenMilliseconds: Double?
    /// Speech end → first synthesized audio frame.
    public var utteranceEndToAudioStartMilliseconds: Double?
    public var replyCharacters: Int?
    public var thermalState: String?
    public var batteryLevel: Double?
    /// Context accounting for this turn (summary folding / drops / real usage).
    public var estimatedPromptTokens: Int?
    public var foldedTurnCount: Int?
    public var droppedTurnCount: Int?
    public var inputTokens: Int?
    public var outputTokens: Int?

    public init(
        kind: String = LiveTurnLatencyRecord.kind,
        sessionID: String,
        turnIndex: Int,
        utteranceEndToRecognitionMilliseconds: Double? = nil,
        utteranceEndToFirstTokenMilliseconds: Double? = nil,
        utteranceEndToAudioStartMilliseconds: Double? = nil,
        replyCharacters: Int? = nil,
        thermalState: String? = nil,
        batteryLevel: Double? = nil,
        estimatedPromptTokens: Int? = nil,
        foldedTurnCount: Int? = nil,
        droppedTurnCount: Int? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.turnIndex = turnIndex
        self.utteranceEndToRecognitionMilliseconds = utteranceEndToRecognitionMilliseconds
        self.utteranceEndToFirstTokenMilliseconds = utteranceEndToFirstTokenMilliseconds
        self.utteranceEndToAudioStartMilliseconds = utteranceEndToAudioStartMilliseconds
        self.replyCharacters = replyCharacters
        self.thermalState = thermalState
        self.batteryLevel = batteryLevel
        self.estimatedPromptTokens = estimatedPromptTokens
        self.foldedTurnCount = foldedTurnCount
        self.droppedTurnCount = droppedTurnCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Live-session envelope: start/end battery and thermal state (TASKS.md §6).
public struct SessionRecord: Codable, Equatable, Sendable {
    public static let kind = "session"

    public var kind: String
    public var sessionID: String
    public var client: String
    public var startedAt: Date
    public var endedAt: Date?
    public var batteryStart: Double?
    public var batteryEnd: Double?
    public var thermalStateStart: String?
    public var thermalStateEnd: String?
    public var turnCount: Int

    public init(
        kind: String = SessionRecord.kind,
        sessionID: String,
        client: String,
        startedAt: Date,
        endedAt: Date? = nil,
        batteryStart: Double? = nil,
        batteryEnd: Double? = nil,
        thermalStateStart: String? = nil,
        thermalStateEnd: String? = nil,
        turnCount: Int = 0
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.client = client
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.batteryStart = batteryStart
        self.batteryEnd = batteryEnd
        self.thermalStateStart = thermalStateStart
        self.thermalStateEnd = thermalStateEnd
        self.turnCount = turnCount
    }
}

/// Appends measurements as JSONL (one JSON object per line).
///
/// JSONL was chosen over a single JSON array so a crashed or interrupted 30-minute
/// session still leaves readable rows. Dates are ISO 8601; keys are sorted for
/// stable diffs between runs.
public actor ResultLogger {
    public let fileURL: URL
    private let handle: FileHandle

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        self.handle = handle
    }

    public func log<T: Encodable & Sendable>(_ record: T) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)

        try handle.write(contentsOf: data)
        try handle.write(contentsOf: Data("\n".utf8))
        try handle.synchronize()
    }

    public func close() {
        try? handle.close()
    }
}
