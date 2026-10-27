import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Same on-device model, but one `LanguageModelSession` is reused across turns.
///
/// Why this exists: the live session creates a fresh session per turn, so the prompt is
/// prefilled every time and `cachedInputTokens` is always 0. Latency grows with the
/// conversation (2.0s → 2.9s over 48 turns). This client is the A/B counterpart used by
/// the cache experiment; it is not wired into the normal scenario/live paths yet.
///
/// `LanguageModelSession(instructions:)`, `streamResponse(to:)` and `Snapshot.usage` are the
/// same SDK APIs already recorded in `AppleOnDeviceClient`.
public actor AppleOnDeviceReusableClient {
    public nonisolated let identifier = "apple_ondevice_reused"

    private let instructions: String
    private var session: LanguageModelSession?
    private var lastUsage: ModelUsage?

    public init(instructions: String) {
        self.instructions = instructions
    }

    public func usageSnapshot() -> ModelUsage? {
        lastUsage
    }

    public func generate(userText: String) async throws -> GenerationOutcome {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AppleOnDeviceClientError.modelUnavailable(String(describing: reason))
        }

        let session: LanguageModelSession
        if let existing = self.session {
            session = existing
        } else {
            let created = LanguageModelSession(
                instructions: instructions.isEmpty ? nil : instructions
            )
            self.session = created
            session = created
        }

        let clock = ContinuousClock()
        let startedAt = clock.now

        var firstTokenMilliseconds: Double?
        var text = ""
        var usage: ModelUsage?

        for try await snapshot in session.streamResponse(to: userText) {
            if firstTokenMilliseconds == nil, !snapshot.content.isEmpty {
                firstTokenMilliseconds = AppleOnDeviceClient.milliseconds(clock.now - startedAt)
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

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleOnDeviceClientError.emptyResponse
        }

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
}
