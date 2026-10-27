import Foundation
import PocketTalkCore

/// Small CLI for agent-side checks that do not need a model.
///
/// `swift run EvalRunner` prints on-device model availability for the host machine.
/// `swift run EvalRunner --dump-context` replays the 34-turn script through
/// `ContextManager` and prints what the summary actually contains at each turn.
/// This is the evidence behind `eval/long_conversation_report.md`: it shows *why* a
/// fact is not in the prompt, independent of the model.

struct Options {
    var dumpContext = false
    var replayPath: String?
    var jsonOut: String?
    var scriptPath = "../../eval/long_conversation.json"
    var recentTurns = 64
    var maxTokens = 7_000
    var systemPrompt = "You are Minsu, a friendly English conversation partner for a Korean learner."

    static func parse(_ arguments: [String]) -> Options {
        var options = Options()
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--dump-context":
                options.dumpContext = true
            case "--replay":
                index += 1
                if index < arguments.count { options.replayPath = arguments[index] }
            case "--json-out":
                index += 1
                if index < arguments.count { options.jsonOut = arguments[index] }
            case "--script":
                index += 1
                if index < arguments.count { options.scriptPath = arguments[index] }
            case "--recent":
                index += 1
                if index < arguments.count, let value = Int(arguments[index]) { options.recentTurns = value }
            case "--budget":
                index += 1
                if index < arguments.count, let value = Int(arguments[index]) { options.maxTokens = value }
            default:
                break
            }
            index += 1
        }
        return options
    }
}

let options = Options.parse(CommandLine.arguments)

if options.dumpContext {
    let url = URL(fileURLWithPath: options.scriptPath)
    do {
        guard let scenario = try ScenarioSet.load(contentsOf: url, turnRange: 30...100).first else {
            print("script has no scenario")
            exit(1)
        }

        let policy = ContextPolicy(
            maxTokens: options.maxTokens,
            recentTurns: options.recentTurns,
            systemPrompt: options.systemPrompt
        )
        let manager = ContextManager(policy: policy, tokenCounter: CharacterTokenCounter())
        let facts = ["jina", "busan", "nurse", "mina", "saturday", "kimchi", "bori", "hour"]

        print("policy: recentTurns=\(options.recentTurns) maxTokens=\(options.maxTokens)")
        var history: [ConversationTurn] = [.assistant(scenario.openingPrompt)]

        for (index, userText) in scenario.userTurns.enumerated() {
            let prepared = manager.prepare(history: history, userText: userText)
            let summary = prepared.summary ?? ""
            let present = facts.filter { summary.lowercased().contains($0) }
            print(
                "turn \(index): folded=\(prepared.foldedTurnCount) dropped=\(prepared.droppedTurnCount) "
                    + "kept=\(prepared.turns.count) estimated=\(prepared.estimatedTokens) "
                    + "summary=\(summary.count)chars factsInSummary=\(present)"
            )
            if index == 9 || index == 11 || index == 29 {
                print("    summary: \(summary)")
            }
            history.append(.user(userText))
            history.append(.assistant("(reply \(index))"))
        }
    } catch {
        print("failed: \(error)")
        exit(1)
    }
} else if let replayPath = options.replayPath {
    // Replays a real run's replies through ContextManager to see what the prompt contained.
    do {
        let scenario = try ScenarioSet.load(
            contentsOf: URL(fileURLWithPath: options.scriptPath),
            turnRange: 30...100
        )[0]

        let lines = try String(contentsOfFile: replayPath, encoding: .utf8)
            .split(separator: "\n")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let record = try lines.compactMap({ try? decoder.decode(ScenarioResultRecord.self, from: Data($0.utf8)) }).first else {
            print("no scenario record in \(replayPath)")
            exit(1)
        }

        let policy = ContextPolicy(
            maxTokens: options.maxTokens,
            recentTurns: options.recentTurns,
            systemPrompt: options.systemPrompt
        )
        let manager = ContextManager(policy: policy, tokenCounter: CharacterTokenCounter())
        let facts = ["jina", "busan", "nurse", "mina", "saturday", "kimchi", "bori", "hour"]

        var history: [ConversationTurn] = [.assistant(scenario.openingPrompt)]
        var rows: [[String: Any]] = []

        for turn in record.turns {
            let prepared = manager.prepare(history: history, userText: turn.userText)
            let summary = prepared.summary ?? ""
            let present = facts.filter { summary.lowercased().contains($0) }
            rows.append([
                "turn": turn.index,
                "foldedTurnCount": prepared.foldedTurnCount,
                "droppedTurnCount": prepared.droppedTurnCount,
                "summaryCharacters": summary.count,
                "factsInSummary": present,
                "summary": summary,
            ])
            print("turn \(turn.index): folded=\(prepared.foldedTurnCount) summary=\(summary.count)chars facts=\(present)")
            history.append(.user(turn.userText))
            history.append(.assistant(turn.reply))
        }

        if let jsonOut = options.jsonOut {
            let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: jsonOut))
            print("wrote \(jsonOut)")
        }
    } catch {
        print("replay failed: \(error)")
        exit(1)
    }
} else {
    print("availability:", AppleOnDeviceClient.availability().description)
    print("contextSize:", AppleOnDeviceClient.contextSize().map(String.init) ?? "nil")
    print("hint: --dump-context replays eval/long_conversation.json without a model")
}
