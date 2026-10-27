import Foundation

/// Counts how many context tokens a piece of text will cost.
///
/// On-device context budgets are measured in tokens, but the exact tokenizer is
/// model-specific and (for Foundation Models) not exposed. Injected counting keeps
/// `ContextManager` testable with a fake and lets the app swap in a measured value.
public protocol TokenCounting: Sendable {
    func count(_ text: String) -> Int
}

/// Rough approximation: one token per `charactersPerToken` characters, rounded up.
///
/// This is deliberately crude. It is only used when no measured tokenizer is
/// available, and `ContextManager` treats it as an upper-bound target.
public struct CharacterTokenCounter: TokenCounting, Equatable, Sendable {
    public var charactersPerToken: Double

    public init(charactersPerToken: Double = 4) {
        self.charactersPerToken = max(0.5, charactersPerToken)
    }

    public func count(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, Int((Double(text.count) / charactersPerToken).rounded(.up)))
    }
}

/// One token per whitespace-separated word. Slightly pessimistic for English but
/// stable across languages and easy to reason about in tests.
public struct WordTokenCounter: TokenCounting, Equatable, Sendable {
    public init() {}

    public func count(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
