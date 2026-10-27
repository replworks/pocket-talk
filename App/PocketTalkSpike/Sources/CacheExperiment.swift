import Foundation
import PocketTalkCore

/// A/B experiment for the latency bottleneck: new session per turn vs one reused session.
///
/// TASKS.md §6 latency. The live session (48 turns) showed p50 2,545ms from speech end to
/// audio start, growing with the conversation. This runs the same 10 written turns through
/// both clients and records per-turn latency and `cachedInputTokens`, so the difference is
/// measured instead of assumed. Text only — no microphone, so an agent can run it.
@MainActor
enum CacheExperiment {
    static let userTurns = [
        "Hello! My name is Jina. I am from Busan.",
        "I work as a nurse at a hospital in Busan.",
        "I have one sister. Her name is Mina.",
        "On weekends I usually meet my sister and eat lunch together.",
        "My favorite food is kimchi, especially with rice.",
        "Last month I got a small dog. His name is Bori.",
        "I study English for one hour every evening.",
        "She wants to visit Busan next month.",
        "We will go to the beach and eat seafood.",
        "Do you have any advice for me?",
    ]

    struct Record: Codable, Sendable {
        var kind: String = "cache_turn"
        var mode: String
        var turn: Int
        var userText: String
        var reply: String
        var totalMilliseconds: Double
        var firstTokenMilliseconds: Double?
        var inputTokens: Int?
        var cachedInputTokens: Int?
        var outputTokens: Int?
    }

    /// Runs both modes and returns the JSONL file name (or an error description).
    static func run(systemPrompt: String, compactPrompt: String?) async -> String {
        let fileName = "cache-experiment-\(timestamp()).jsonl"
        do {
            let logger = try ResultLogger(fileURL: MeasurementStore.resultsURL(fileName: fileName))

            // A: fresh session per turn (current app behaviour)
            let fresh = AppleOnDeviceClient()
            var history: [ConversationTurn] = [.system(systemPrompt)]
            for (index, text) in userTurns.enumerated() {
                let clock = ContinuousClock()
                let startedAt = clock.now
                do {
                    let outcome = try await fresh.generate(history: history, userText: text)
                    let total = milliseconds(clock.now - startedAt)
                    history.append(.user(text))
                    history.append(.assistant(outcome.text))
                    try await logger.log(
                        Record(
                            mode: "fresh",
                            turn: index,
                            userText: text,
                            reply: outcome.text,
                            totalMilliseconds: total,
                            firstTokenMilliseconds: outcome.timeToFirstTokenMilliseconds,
                            inputTokens: outcome.usage?.inputTokens,
                            cachedInputTokens: outcome.usage?.cachedInputTokens,
                            outputTokens: outcome.usage?.outputTokens
                        )
                    )
                } catch {
                    await logger.close()
                    return "fresh 실패 (turn \(index)): \(error)"
                }
            }

            // B: compact system prompt, still fresh session per turn
            if let compactPrompt, !compactPrompt.isEmpty {
                let compact = AppleOnDeviceClient()
                var compactHistory: [ConversationTurn] = [.system(compactPrompt)]
                for (index, text) in userTurns.enumerated() {
                    let clock = ContinuousClock()
                    let startedAt = clock.now
                    do {
                        let outcome = try await compact.generate(history: compactHistory, userText: text)
                        let total = milliseconds(clock.now - startedAt)
                        compactHistory.append(.user(text))
                        compactHistory.append(.assistant(outcome.text))
                        try await logger.log(
                            Record(
                                mode: "compact",
                                turn: index,
                                userText: text,
                                reply: outcome.text,
                                totalMilliseconds: total,
                                firstTokenMilliseconds: outcome.timeToFirstTokenMilliseconds,
                                inputTokens: outcome.usage?.inputTokens,
                                cachedInputTokens: outcome.usage?.cachedInputTokens,
                                outputTokens: outcome.usage?.outputTokens
                            )
                        )
                    } catch {
                        await logger.close()
                        return "compact 실패 (turn \(index)): \(error)"
                    }
                }
            }

            // C: one session reused for every turn
            let reused = AppleOnDeviceReusableClient(instructions: systemPrompt)
            for (index, text) in userTurns.enumerated() {
                let clock = ContinuousClock()
                let startedAt = clock.now
                do {
                    let outcome = try await reused.generate(userText: text)
                    let total = milliseconds(clock.now - startedAt)
                    try await logger.log(
                        Record(
                            mode: "reused",
                            turn: index,
                            userText: text,
                            reply: outcome.text,
                            totalMilliseconds: total,
                            firstTokenMilliseconds: outcome.timeToFirstTokenMilliseconds,
                            inputTokens: outcome.usage?.inputTokens,
                            cachedInputTokens: outcome.usage?.cachedInputTokens,
                            outputTokens: outcome.usage?.outputTokens
                        )
                    )
                } catch {
                    await logger.close()
                    return "reused 실패 (turn \(index)): \(error)"
                }
            }

            await logger.close()
            return fileName
        } catch {
            return "실패: \(error)"
        }
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
