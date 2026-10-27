import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Availability snapshot of the on-device model, so the UI can say *why* it cannot run.
public enum AppleOnDeviceAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
    case unsupportedPlatform

    public var isAvailable: Bool { self == .available }

    public var description: String {
        switch self {
        case .available:
            return "사용 가능"
        case .unavailable(let reason):
            return "사용 불가: \(reason)"
        case .unsupportedPlatform:
            return "이 플랫폼에는 FoundationModels 없음"
        }
    }
}

/// Result of one streaming generation, with the timings the live session needs.
public struct GenerationOutcome: Equatable, Sendable {
    public var text: String
    /// Time from the call to the first non-empty token. `nil` when no token arrived.
    public var timeToFirstTokenMilliseconds: Double?
    public var usage: ModelUsage?

    public init(text: String, timeToFirstTokenMilliseconds: Double? = nil, usage: ModelUsage? = nil) {
        self.text = text
        self.timeToFirstTokenMilliseconds = timeToFirstTokenMilliseconds
        self.usage = usage
    }
}

public enum AppleOnDeviceClientError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case modelUnavailable(String)
    case emptyResponse
}

/// Foundation Models implementation of `LanguageModelClient`.
///
/// API signatures verified against the installed SDK interface:
/// `.../iPhoneSimulator27.1.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/
/// FoundationModels.swiftmodule/arm64-apple-ios-simulator.swiftinterface`
/// - `SystemLanguageModel.default` (static var), `.availability`, `.contextSize`
/// - `LanguageModelSession(model:tools:transcript:)`
/// - `session.respond(to: String, options:) async throws -> Response<String>`
/// - `Response.content`, `Response.usage.input/output.totalTokenCount` (iOS 27+)
///
/// `UNVERIFIED`: this file has not been executed on a physical device. Simulator runs
/// depend on the Mac's Apple Intelligence availability.
public actor AppleOnDeviceClient: UsageReportingLanguageModelClient {
    public nonisolated let identifier = "apple_ondevice"

    /// Reserved for the reply when sizing the context budget.
    public nonisolated let outputTokenReserve = 512

    private var lastUsage: ModelUsage?

    public init() {}

    public static func availability() -> AppleOnDeviceAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(String(describing: reason))
        }
        #else
        return .unsupportedPlatform
        #endif
    }

    /// Real context window of the model, or `nil` when Foundation Models is unavailable.
    public static func contextSize() -> Int? {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.contextSize
        #else
        return nil
        #endif
    }

    public func usageSnapshot() -> ModelUsage? {
        lastUsage
    }

    public func respond(history: [ConversationTurn], userText: String) async throws -> String {
        try await generate(history: history, userText: userText).text
    }

    /// Streams the reply so the live session can timestamp the first token.
    ///
    /// `streamResponse(to:)` and `Snapshot.usage` were verified in the SDK interface
    /// (`ResponseStream` is an `AsyncSequence` of `Snapshot`, `content` is cumulative
    /// partial text for `String` generation).
    public func generate(history: [ConversationTurn], userText: String) async throws -> GenerationOutcome {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AppleOnDeviceClientError.modelUnavailable(String(describing: reason))
        }

        let session = LanguageModelSession(transcript: Self.transcript(history: history))
        let clock = ContinuousClock()
        let startedAt = clock.now

        var firstTokenMilliseconds: Double?
        var text = ""
        var usage: ModelUsage?

        for try await snapshot in session.streamResponse(to: userText) {
            if firstTokenMilliseconds == nil, !snapshot.content.isEmpty {
                firstTokenMilliseconds = Self.milliseconds(clock.now - startedAt)
            }
            if !snapshot.content.isEmpty {
                text = snapshot.content
            }
            usage = ModelUsage(
                inputTokens: snapshot.usage.input.totalTokenCount,
                outputTokens: snapshot.usage.output.totalTokenCount,
                cachedInputTokens: snapshot.usage.input.cachedTokenCount,
                contextSize: SystemLanguageModel.default.contextSize
            )
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppleOnDeviceClientError.emptyResponse }

        lastUsage = usage
        return GenerationOutcome(
            text: text,
            timeToFirstTokenMilliseconds: firstTokenMilliseconds,
            usage: usage
        )
        #else
        throw AppleOnDeviceClientError.unsupportedPlatform
        #endif
    }

    static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    #if canImport(FoundationModels)
    /// Rebuilds the conversation as a Foundation Models transcript.
    ///
    /// `ContextManager` emits the persona and the folded summary as `.system` turns;
    /// Foundation Models wants one instructions entry, so all system text is merged there.
    static func transcript(history: [ConversationTurn]) -> Transcript {
        var instructions: [String] = []
        var entries: [Transcript.Entry] = []

        for turn in history {
            switch turn.role {
            case .system:
                instructions.append(turn.text)
            case .user:
                entries.append(.prompt(Transcript.Prompt(segments: [.text(.init(content: turn.text))])))
            case .assistant:
                entries.append(
                    .response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: turn.text))]))
                )
            }
        }

        if !instructions.isEmpty {
            entries.insert(
                .instructions(
                    Transcript.Instructions(
                        segments: [.text(.init(content: instructions.joined(separator: "\n\n")))],
                        toolDefinitions: []
                    )
                ),
                at: 0
            )
        }

        return Transcript(entries: entries)
    }
    #endif
}
