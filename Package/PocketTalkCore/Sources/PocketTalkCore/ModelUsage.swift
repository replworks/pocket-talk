import Foundation

/// Token usage reported by a real model, when the framework exposes it.
///
/// On-device Foundation Models reports actual input/output token counts per response
/// (`Response.usage`, iOS 27+), which is the only non-guess number in this spike.
/// The mock client never reports usage, so these fields stay `nil` there.
public struct ModelUsage: Codable, Equatable, Sendable {
    /// Tokens the model actually read (prompt + instructions + history).
    public var inputTokens: Int?
    /// Tokens the model actually generated.
    public var outputTokens: Int?
    /// Input tokens served from the KV cache.
    public var cachedInputTokens: Int?
    /// Model context window at call time.
    public var contextSize: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        contextSize: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.contextSize = contextSize
    }
}

/// Optional capability for clients that can report real token usage.
///
/// Kept separate from `LanguageModelClient` so the model seam stays exactly the
/// signature TASKS.md specifies.
public protocol UsageReportingLanguageModelClient: LanguageModelClient {
    /// Usage of the most recent `respond` call, if the model reported it.
    func usageSnapshot() async -> ModelUsage?
}
