import Foundation

/// How `ContextManager` spends the conversation budget.
public struct ContextPolicy: Equatable, Sendable {
    /// Hard cap for system prompt + summary + kept turns + the current user text.
    public var maxTokens: Int
    /// How many trailing turns are kept verbatim when the budget allows it.
    public var recentTurns: Int
    /// Persona / level rules. Counted against `maxTokens`.
    public var systemPrompt: String

    public init(maxTokens: Int = 7_000, recentTurns: Int = 64, systemPrompt: String = "") {
        self.maxTokens = max(1, maxTokens)
        self.recentTurns = max(0, recentTurns)
        self.systemPrompt = systemPrompt
    }
}

/// Folds old turns into a short summary string.
///
/// Kept synchronous and pure so `ContextManager` stays unit-testable. The spike uses
/// `ExtractiveSummarizer`; a model-backed summarizer can be injected later without
/// touching the folding logic.
public protocol TurnSummarizing: Sendable {
    /// - Parameters:
    ///   - previous: Summary that already existed before this compaction.
    ///   - turns: Turns being folded right now, oldest first.
    func summarize(previous: String?, turns: [ConversationTurn]) -> String
}

/// Deterministic, extractive summarizer. It never invents content and its output
/// length is bounded, which keeps `ContextManager` monotone under repeated folding.
public struct ExtractiveSummarizer: TurnSummarizing, Sendable {
    public var maxCharacters: Int
    public var maxCharactersPerTurn: Int

    public init(maxCharacters: Int = 400, maxCharactersPerTurn: Int = 60) {
        self.maxCharacters = max(1, maxCharacters)
        self.maxCharactersPerTurn = max(1, maxCharactersPerTurn)
    }

    public func summarize(previous: String?, turns: [ConversationTurn]) -> String {
        var lines: [String] = []
        if let previous, !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Earlier: \(previous)")
        }
        for turn in turns {
            let speaker = turn.role == .assistant ? "AI" : "Learner"
            let condensed = turn.text
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            lines.append("\(speaker): \(String(condensed.prefix(maxCharactersPerTurn)))")
        }

        let joined = lines.joined(separator: " | ")
        guard joined.count > maxCharacters else { return joined }
        // Keep the newest facts when the summary has to be cut.
        return String(joined.suffix(maxCharacters))
    }
}

enum ContextFormatting {
    static let summaryPrefix = "Conversation summary so far:"
    static let summaryBlockPrefix = "\(summaryPrefix)\n"

    static func summaryBlock(_ summary: String) -> String {
        "\(summaryBlockPrefix)\(summary)"
    }
}

/// Result of fitting a conversation into the token budget. Pure value type.
public struct PreparedContext: Equatable, Sendable {
    public var systemPrompt: String
    public var summary: String?
    /// Turns kept verbatim, oldest first. Excludes `userText`.
    public var turns: [ConversationTurn]
    public var userText: String
    public var estimatedTokens: Int
    public var foldedTurnCount: Int
    public var droppedTurnCount: Int
    public var didDropSummary: Bool
    public var didTruncateUserText: Bool
    public var maxTokens: Int

    public init(
        systemPrompt: String,
        summary: String?,
        turns: [ConversationTurn],
        userText: String,
        estimatedTokens: Int,
        foldedTurnCount: Int,
        droppedTurnCount: Int,
        didDropSummary: Bool,
        didTruncateUserText: Bool,
        maxTokens: Int
    ) {
        self.systemPrompt = systemPrompt
        self.summary = summary
        self.turns = turns
        self.userText = userText
        self.estimatedTokens = estimatedTokens
        self.foldedTurnCount = foldedTurnCount
        self.droppedTurnCount = droppedTurnCount
        self.didDropSummary = didDropSummary
        self.didTruncateUserText = didTruncateUserText
        self.maxTokens = maxTokens
    }

    /// True only when even the system prompt alone does not fit the budget.
    public var isOverBudget: Bool { estimatedTokens > maxTokens }

    /// What to hand to `LanguageModelClient.respond(history:userText:)`.
    public func historyForModel() -> [ConversationTurn] {
        var result: [ConversationTurn] = []
        if !systemPrompt.isEmpty {
            result.append(.system(systemPrompt))
        }
        if let summary, !summary.isEmpty {
            result.append(.system(ContextFormatting.summaryBlock(summary)))
        }
        result.append(contentsOf: turns)
        return result
    }

    /// History plus the current user text. Used for logging / on-screen transcripts.
    public func messagesIncludingUser() -> [ConversationTurn] {
        historyForModel() + [.user(userText)]
    }
}

/// Folds old turns into a summary and keeps the most recent turns verbatim so the
/// prompt never exceeds the token budget.
///
/// Degradation order, in this order:
/// 1. fold every turn older than the recent window into the summary,
/// 2. drop the oldest kept turns (never below one turn unless the budget still fails),
/// 3. drop the summary,
/// 4. truncate the user text.
///
/// The final `estimatedTokens` never exceeds `maxTokens` unless the system prompt
/// alone is larger than the budget (`PreparedContext.isOverBudget`).
public struct ContextManager: Sendable {
    public let policy: ContextPolicy
    private let tokenCounter: any TokenCounting
    private let summarizer: any TurnSummarizing

    public init(
        policy: ContextPolicy,
        tokenCounter: any TokenCounting = CharacterTokenCounter(),
        summarizer: any TurnSummarizing = ExtractiveSummarizer()
    ) {
        self.policy = policy
        self.tokenCounter = tokenCounter
        self.summarizer = summarizer
    }

    public func prepare(
        history: [ConversationTurn],
        userText: String,
        previousSummary: String? = nil
    ) -> PreparedContext {
        let budget = policy.maxTokens
        let keep = policy.recentTurns
        let systemTokens = tokenCounter.count(policy.systemPrompt)

        let originSummary: String? = (previousSummary?.isEmpty == false) ? previousSummary : nil
        var summary: String? = originSummary

        var pending: [ConversationTurn]
        var recent: [ConversationTurn]
        if keep == 0 {
            pending = history
            recent = []
        } else if history.count > keep {
            pending = Array(history.dropLast(keep))
            recent = Array(history.suffix(keep))
        } else {
            pending = []
            recent = history
        }

        var foldedTurns: [ConversationTurn] = []
        var foldedTurnCount = 0
        var droppedTurnCount = 0
        var didDropSummary = false

        func summaryTokens(_ value: String?) -> Int {
            guard let value, !value.isEmpty else { return 0 }
            return tokenCounter.count(ContextFormatting.summaryBlock(value))
        }

        func totalTokens(_ currentUserText: String) -> Int {
            let turnTokens = recent.reduce(0) { $0 + tokenCounter.count($1.text) }
            return systemTokens + summaryTokens(summary) + turnTokens + tokenCounter.count(currentUserText)
        }

        // 1. Fold every turn older than the recent window into the summary. This happens
        //    even when the prompt still fits: otherwise the old turns would be dropped
        //    silently instead of being summarized.
        if !pending.isEmpty {
            foldedTurns = pending
            foldedTurnCount = pending.count
            summary = summarizer.summarize(previous: originSummary, turns: foldedTurns)
            pending.removeAll()
        }

        // 2. Drop the oldest kept turns, but keep at least one if we can.
        while totalTokens(userText) > budget && recent.count > 1 {
            recent.removeFirst()
            droppedTurnCount += 1
        }

        // 3. Give up the summary.
        if totalTokens(userText) > budget, summary != nil {
            summary = nil
            didDropSummary = true
        }

        // 4. Last resort: drop the remaining kept turns, then cut the user text.
        while totalTokens(userText) > budget && !recent.isEmpty {
            recent.removeFirst()
            droppedTurnCount += 1
        }

        var finalUserText = userText
        var didTruncateUserText = false
        if totalTokens(userText) > budget {
            let turnTokens = recent.reduce(0) { $0 + tokenCounter.count($1.text) }
            let room = budget - (systemTokens + summaryTokens(summary) + turnTokens)
            finalUserText = truncate(userText, toTokens: max(0, room))
            didTruncateUserText = finalUserText != userText
        }

        let estimatedTokens = totalTokens(finalUserText)

        return PreparedContext(
            systemPrompt: policy.systemPrompt,
            summary: summary,
            turns: recent,
            userText: finalUserText,
            estimatedTokens: estimatedTokens,
            foldedTurnCount: foldedTurnCount,
            droppedTurnCount: droppedTurnCount,
            didDropSummary: didDropSummary,
            didTruncateUserText: didTruncateUserText,
            maxTokens: budget
        )
    }

    /// Longest prefix of `text` whose token count fits `budget`.
    private func truncate(_ text: String, toTokens budget: Int) -> String {
        guard budget > 0 else { return "" }
        guard tokenCounter.count(text) > budget else { return text }

        let characters = Array(text)
        var low = 0
        var high = characters.count
        while low < high {
            let mid = (low + high + 1) / 2
            if tokenCounter.count(String(characters[0..<mid])) <= budget {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return String(characters[0..<low])
    }
}
