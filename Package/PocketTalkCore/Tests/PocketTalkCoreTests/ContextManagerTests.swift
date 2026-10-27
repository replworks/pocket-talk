import XCTest
@testable import PocketTalkCore

/// Deterministic token counter for tests: one token per whitespace-separated word.
struct FakeWordCounter: TokenCounting {
    func count(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

final class ContextManagerTests: XCTestCase {
    private let counter = FakeWordCounter()

    private func makeManager(maxTokens: Int, recentTurns: Int, systemPrompt: String = "") -> ContextManager {
        ContextManager(
            policy: ContextPolicy(maxTokens: maxTokens, recentTurns: recentTurns, systemPrompt: systemPrompt),
            tokenCounter: counter
        )
    }

    private func makeHistory(turns: Int, wordsPerTurn: Int = 4) -> [ConversationTurn] {
        (0..<turns).map { index in
            let text = (0..<wordsPerTurn).map { "w\(index)_\($0)" }.joined(separator: " ")
            return ConversationTurn(role: index.isMultiple(of: 2) ? .user : .assistant, text: text)
        }
    }

    func testSummarizesOlderTurnsAndKeepsRecentWindow() {
        let history = makeHistory(turns: 12)
        let prepared = makeManager(maxTokens: 400, recentTurns: 4).prepare(
            history: history,
            userText: "one more question"
        )

        XCTAssertEqual(prepared.foldedTurnCount, 8)
        XCTAssertEqual(prepared.turns.count, 4)
        XCTAssertEqual(prepared.turns, Array(history.suffix(4)))
        XCTAssertNotNil(prepared.summary)
        XCTAssertFalse(prepared.isOverBudget)
    }

    func testNeverExceedsBudget() {
        // 40 turns of 10 words each, against budgets from very tight to comfortable.
        let history = makeHistory(turns: 40, wordsPerTurn: 10)
        let userText = "this is the current learner turn"

        for budget in [20, 50, 100, 250, 600] {
            let prepared = makeManager(maxTokens: budget, recentTurns: 8).prepare(
                history: history,
                userText: userText
            )
            XCTAssertLessThanOrEqual(
                prepared.estimatedTokens,
                budget,
                "budget \(budget) exceeded: \(prepared.estimatedTokens) tokens"
            )
            XCTAssertFalse(prepared.isOverBudget)
        }
    }

    func testDropsOldestKeptTurnsWhenRecentWindowDoesNotFit() {
        let history = makeHistory(turns: 20, wordsPerTurn: 10)
        let prepared = makeManager(maxTokens: 60, recentTurns: 20).prepare(
            history: history,
            userText: "short turn"
        )

        XCTAssertGreaterThan(prepared.droppedTurnCount, 0)
        XCTAssertLessThanOrEqual(prepared.estimatedTokens, 60)
    }

    func testTruncatesUserTextWhenBudgetIsTiny() {
        let longText = (0..<100).map { "word\($0)" }.joined(separator: " ")
        let prepared = makeManager(maxTokens: 10, recentTurns: 0).prepare(history: [], userText: longText)

        XCTAssertTrue(prepared.didTruncateUserText)
        XCTAssertLessThanOrEqual(prepared.estimatedTokens, 10)
        XCTAssertLessThanOrEqual(prepared.userText.split(separator: " ").count, 10)
    }

    func testDropsSummaryBeforeDroppingTheUserText() {
        let history = makeHistory(turns: 6, wordsPerTurn: 20)
        let prepared = makeManager(maxTokens: 25, recentTurns: 2).prepare(
            history: history,
            userText: "hello there"
        )

        XCTAssertTrue(prepared.didDropSummary)
        XCTAssertNil(prepared.summary)
        XCTAssertLessThanOrEqual(prepared.estimatedTokens, 25)
    }

    func testHistoryForModelCarriesSystemPromptAndSummary() {
        let history = makeHistory(turns: 6)
        let prepared = makeManager(maxTokens: 400, recentTurns: 2, systemPrompt: "Be a partner.").prepare(
            history: history,
            userText: "next"
        )

        let messages = prepared.historyForModel()
        XCTAssertEqual(messages.first, .system("Be a partner."))
        XCTAssertEqual(messages.dropFirst().first?.role, .system)
        XCTAssertTrue(messages.dropFirst().first?.text.contains("Conversation summary so far") == true)
        XCTAssertEqual(messages.last, history.last)
        XCTAssertEqual(messages.filter { $0.role == .user }.count, 1)
    }

    func testPreviousSummaryIsCarriedForward() {
        let prepared = makeManager(maxTokens: 400, recentTurns: 2).prepare(
            history: makeHistory(turns: 6),
            userText: "and then?",
            previousSummary: "the learner talked about dogs"
        )

        XCTAssertTrue(prepared.summary?.contains("dogs") ?? false)
    }

    func testEmptyHistoryStaysUnderBudget() {
        let prepared = makeManager(maxTokens: 50, recentTurns: 8, systemPrompt: "Be a partner.").prepare(
            history: [],
            userText: "hello"
        )

        XCTAssertTrue(prepared.turns.isEmpty)
        XCTAssertNil(prepared.summary)
        XCTAssertEqual(prepared.foldedTurnCount, 0)
        XCTAssertEqual(prepared.userText, "hello")
        XCTAssertFalse(prepared.isOverBudget)
    }

    func testNoTurnIsLostWhenHistoryIsShorterThanRecentWindow() {
        let history = makeHistory(turns: 3)
        let prepared = makeManager(maxTokens: 400, recentTurns: 8).prepare(history: history, userText: "hi")

        XCTAssertEqual(prepared.turns, history)
        XCTAssertNil(prepared.summary)
        XCTAssertEqual(prepared.foldedTurnCount, 0)
    }
}
