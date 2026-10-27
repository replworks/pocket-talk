import Foundation

/// Deterministic stand-in for a real model.
///
/// Responses are served in order and then cycled, so a 20-scenario run always
/// terminates. `{user}` inside a canned response is replaced with the user text,
/// which makes transcripts readable without recording real model output.
public final class MockLanguageModelClient: LanguageModelClient, @unchecked Sendable {
    public enum MockError: Error, Equatable, Sendable {
        case noResponses
        case injectedFailure
    }

    public let identifier: String

    private let lock = NSLock()
    private var responses: [String]
    private var cursor = 0
    private var callCountStorage = 0
    private var shouldFail = false

    public init(identifier: String = "mock", responses: [String] = ["(mock reply)"]) {
        self.identifier = identifier
        self.responses = responses
    }

    /// Fails every call after this is set. Used to test the error path of `ScenarioRunner`.
    public func failAlways() {
        lock.lock()
        defer { lock.unlock() }
        shouldFail = true
    }

    public var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCountStorage
    }

    public func respond(history: [ConversationTurn], userText: String) async throws -> String {
        try nextReply(userText: userText)
    }

    /// Locking lives in a synchronous helper: `NSLock.lock()` is unavailable directly
    /// from async contexts, and the response cursor must stay consistent under concurrent calls.
    private func nextReply(userText: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        if shouldFail { throw MockError.injectedFailure }
        guard !responses.isEmpty else { throw MockError.noResponses }

        let template = responses[cursor % responses.count]
        cursor += 1
        callCountStorage += 1
        return template.replacingOccurrences(of: "{user}", with: userText)
    }
}
