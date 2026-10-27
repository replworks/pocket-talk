import XCTest
@testable import PocketTalkCore

final class ScenarioRunnerTests: XCTestCase {
    private func makeRunner(client: MockLanguageModelClient) -> ScenarioRunner {
        ScenarioRunner(
            client: client,
            contextManager: ContextManager(
                policy: ContextPolicy(maxTokens: 600, recentTurns: 8, systemPrompt: "You are Minsu, a conversation partner."),
                tokenCounter: WordTokenCounter()
            )
        )
    }

    func testScenarioFileHasTwentyValidScenarios() throws {
        let scenarios = try ScenarioSet.load(contentsOf: Fixtures.scenariosURL)

        XCTAssertEqual(scenarios.count, 20)
        XCTAssertEqual(Set(scenarios.map(\.id)).count, 20)
        for scenario in scenarios {
            XCTAssertTrue(ScenarioSet.allowedTurnCounts.contains(scenario.userTurns.count), scenario.id)
            XCTAssertFalse(scenario.openingPrompt.isEmpty, scenario.id)
        }
    }

    func testAllTwentyScenariosFinishWithMockClient() async throws {
        let scenarios = try ScenarioSet.load(contentsOf: Fixtures.scenariosURL)
        let runner = makeRunner(client: MockLanguageModelClient(responses: ["Nice! You said: {user}. Tell me more."]))

        let runs = await runner.runAll(scenarios, runID: "unit-test")

        XCTAssertEqual(runs.count, 20)
        XCTAssertTrue(runs.allSatisfy(\.completed), runs.filter { !$0.completed }.map(\.scenarioID).description)
        XCTAssertTrue(runs.allSatisfy { $0.client == "mock" })

        for (run, scenario) in zip(runs, scenarios) {
            XCTAssertEqual(run.scenarioID, scenario.id)
            XCTAssertEqual(run.turns.count, scenario.userTurns.count)
            XCTAssertEqual(run.transcript.first, .assistant(scenario.openingPrompt))
            XCTAssertEqual(run.transcript.last?.role, .assistant)
            XCTAssertEqual(run.transcript.count, 1 + scenario.userTurns.count * 2)
            XCTAssertGreaterThan(run.totalEstimatedPromptTokens, 0)
            XCTAssertFalse(run.turns.contains { $0.didTruncateUserText })
        }
    }

    func testMockRepliesAreParaphrasedIntoEachTurn() async throws {
        let scenario = Scenario(
            id: "one",
            topic: "test",
            openingPrompt: "Hi!",
            userTurns: ["I am fine", "And you?", "Goodbye"]
        )
        let runner = makeRunner(client: MockLanguageModelClient(responses: ["You said: {user}"]))

        let run = await runner.run(scenario)

        XCTAssertEqual(run.turns.map(\.reply), ["You said: I am fine", "You said: And you?", "You said: Goodbye"])
    }

    func testModelFailureIsRecordedAndStopsTheRun() async throws {
        let scenario = Scenario(
            id: "one",
            topic: "test",
            openingPrompt: "Hi!",
            userTurns: ["I am fine", "And you?", "Goodbye"]
        )
        let client = MockLanguageModelClient(responses: ["ok"])
        client.failAlways()
        let runner = makeRunner(client: client)

        let run = await runner.run(scenario)

        XCTAssertFalse(run.completed)
        XCTAssertNotNil(run.errorMessage)
        XCTAssertTrue(run.turns.isEmpty)
        XCTAssertEqual(run.transcript.count, 1)
    }

    func testContextFoldingKicksInForLongHistory() async throws {
        let longScenarios = [
            Scenario(
                id: "long",
                topic: "long",
                openingPrompt: "Hi!",
                userTurns: (0..<5).map { "turn \($0) with a few extra words to grow the history" }
            )
        ]
        let runner = ScenarioRunner(
            client: MockLanguageModelClient(responses: ["short reply"]),
            contextManager: ContextManager(
                policy: ContextPolicy(maxTokens: 60, recentTurns: 2, systemPrompt: "Be brief."),
                tokenCounter: WordTokenCounter()
            )
        )

        let runs = await runner.runAll(longScenarios)
        let run = try XCTUnwrap(runs.first)

        XCTAssertTrue(run.completed)
        XCTAssertGreaterThan(run.maxFoldedTurnCount, 0)
        XCTAssertTrue(run.turns.allSatisfy { $0.estimatedPromptTokens <= 60 })
    }
}
