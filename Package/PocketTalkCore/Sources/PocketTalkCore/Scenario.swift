import Foundation

/// One scripted conversation for the scenario tab (`eval/scenarios.json`).
public struct Scenario: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var topic: String
    /// The AI's first line. The learner answers it.
    public var openingPrompt: String
    /// What the learner says, in order. Beginner-to-intermediate level.
    public var userTurns: [String]

    public init(id: String, topic: String, openingPrompt: String, userTurns: [String]) {
        self.id = id
        self.topic = topic
        self.openingPrompt = openingPrompt
        self.userTurns = userTurns
    }

    enum CodingKeys: String, CodingKey {
        case id
        case topic
        case openingPrompt = "opening_prompt"
        case userTurns = "user_turns"
    }
}

public enum ScenarioValidationError: Error, Equatable, Sendable {
    case emptySet
    case duplicateID(String)
    case emptyTopic(String)
    case emptyOpeningPrompt(String)
    case invalidTurnCount(id: String, count: Int)
    case emptyUserTurn(id: String, index: Int)
}

public enum ScenarioSet {
    /// Number of learner turns a scenario may script, per TASKS.md ("3~5턴").
    public static let allowedTurnCounts = 3...5

    public static func load(
        contentsOf url: URL,
        turnRange: ClosedRange<Int> = allowedTurnCounts
    ) throws -> [Scenario] {
        let data = try Data(contentsOf: url)
        return try decode(data, turnRange: turnRange)
    }

    public static func decode(
        _ data: Data,
        turnRange: ClosedRange<Int> = allowedTurnCounts
    ) throws -> [Scenario] {
        let scenarios = try JSONDecoder().decode([Scenario].self, from: data)
        try validate(scenarios, turnRange: turnRange)
        return scenarios
    }

    public static func validate(
        _ scenarios: [Scenario],
        turnRange: ClosedRange<Int> = allowedTurnCounts
    ) throws {
        guard !scenarios.isEmpty else { throw ScenarioValidationError.emptySet }

        var seen = Set<String>()
        for scenario in scenarios {
            guard seen.insert(scenario.id).inserted else {
                throw ScenarioValidationError.duplicateID(scenario.id)
            }
            guard !scenario.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ScenarioValidationError.emptyTopic(scenario.id)
            }
            guard !scenario.openingPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ScenarioValidationError.emptyOpeningPrompt(scenario.id)
            }
            guard turnRange.contains(scenario.userTurns.count) else {
                throw ScenarioValidationError.invalidTurnCount(id: scenario.id, count: scenario.userTurns.count)
            }
            for (index, turn) in scenario.userTurns.enumerated() {
                guard !turn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ScenarioValidationError.emptyUserTurn(id: scenario.id, index: index)
                }
            }
        }
    }
}
