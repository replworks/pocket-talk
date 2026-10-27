import Foundation

/// The only seam between PocketTalkCore and a language model.
///
/// The live app uses an on-device implementation (M3); tests and scripts use
/// `MockLanguageModelClient`. Nothing in the core may call a model directly.
public protocol LanguageModelClient: Sendable {
    /// Short stable name used in logs and result files (e.g. "mock", "apple_ondevice").
    var identifier: String { get }

    /// Produces the assistant reply for `userText`, given the turns that came before it.
    ///
    /// - Parameters:
    ///   - history: Conversation so far, oldest first. May already contain a system
    ///     prompt and a folded summary produced by `ContextManager`.
    ///   - userText: The new user utterance. Not yet part of `history`.
    func respond(history: [ConversationTurn], userText: String) async throws -> String
}

public extension LanguageModelClient {
    var identifier: String { "unknown" }
}

public enum LanguageModelClientError: Error, Equatable, Sendable {
    case emptyResponse
}
