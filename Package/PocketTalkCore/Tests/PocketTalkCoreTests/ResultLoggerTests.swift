import XCTest
@testable import PocketTalkCore

final class ResultLoggerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "pocket-talk-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    private func sampleRecord(runID: String = "run-1") -> ScenarioResultRecord {
        ScenarioResultRecord(
            runID: runID,
            scenarioID: "sc01_self_intro",
            topic: "자기소개",
            client: "mock",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMilliseconds: 12.5,
            completed: true,
            errorMessage: nil,
            foldedTurnCount: 2,
            droppedTurnCount: 0,
            turns: [
                TurnResultRecord(
                    index: 0,
                    userText: "Hello. My name is Jina.",
                    reply: "Nice to meet you, Jina!",
                    modelMilliseconds: 3.25,
                    estimatedPromptTokens: 42,
                    promptTurnCount: 3,
                    foldedTurnCount: 2,
                    droppedTurnCount: 0,
                    didDropSummary: false,
                    didTruncateUserText: false
                )
            ]
        )
    }

    func testWritesOneJSONObjectPerLine() async throws {
        let fileURL = temporaryDirectory.appending(path: "results/mock.jsonl")
        let logger = try ResultLogger(fileURL: fileURL)

        try await logger.log(sampleRecord())
        try await logger.log(
            LiveTurnLatencyRecord(
                sessionID: "s1",
                turnIndex: 0,
                utteranceEndToRecognitionMilliseconds: 210,
                utteranceEndToFirstTokenMilliseconds: 640,
                utteranceEndToAudioStartMilliseconds: 1_120,
                replyCharacters: 24,
                thermalState: "nominal",
                batteryLevel: 0.87
            )
        )
        await logger.close()

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let scenario = try decoder.decode(ScenarioResultRecord.self, from: Data(lines[0].utf8))
        XCTAssertEqual(scenario.kind, "scenario")
        XCTAssertEqual(scenario.scenarioID, "sc01_self_intro")
        XCTAssertEqual(scenario.turns.count, 1)
        XCTAssertEqual(scenario.turns.first?.estimatedPromptTokens, 42)
        XCTAssertEqual(scenario.startedAt, Date(timeIntervalSince1970: 1_700_000_000))

        let latency = try decoder.decode(LiveTurnLatencyRecord.self, from: Data(lines[1].utf8))
        XCTAssertEqual(latency.kind, "live_turn")
        XCTAssertEqual(latency.utteranceEndToAudioStartMilliseconds, 1_120)
        XCTAssertEqual(latency.thermalState, "nominal")
    }

    func testAppendsAcrossLoggerInstances() async throws {
        let fileURL = temporaryDirectory.appending(path: "append.jsonl")

        let first = try ResultLogger(fileURL: fileURL)
        try await first.log(sampleRecord(runID: "run-1"))
        await first.close()

        let second = try ResultLogger(fileURL: fileURL)
        try await second.log(sampleRecord(runID: "run-2"))
        await second.close()

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let firstRecord = try decoder.decode(ScenarioResultRecord.self, from: Data(lines[0].utf8))
        let secondRecord = try decoder.decode(ScenarioResultRecord.self, from: Data(lines[1].utf8))
        XCTAssertEqual(firstRecord.runID, "run-1")
        XCTAssertEqual(secondRecord.runID, "run-2")
    }

    func testCreatesMissingDirectories() async throws {
        let fileURL = temporaryDirectory.appending(path: "nested/deeper/results.jsonl")
        let logger = try ResultLogger(fileURL: fileURL)
        try await logger.log(sampleRecord())
        await logger.close()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
}

final class ScenarioSetValidationTests: XCTestCase {
    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    func testRejectsDuplicateIdentifiers() {
        let json = """
        [
          {"id":"a","topic":"t","opening_prompt":"hi","user_turns":["1","2","3"]},
          {"id":"a","topic":"t2","opening_prompt":"hi","user_turns":["1","2","3"]}
        ]
        """

        XCTAssertThrowsError(try ScenarioSet.decode(data(json))) { error in
            XCTAssertEqual(error as? ScenarioValidationError, .duplicateID("a"))
        }
    }

    func testRejectsTurnCountOutsideThreeToFive() {
        let json = """
        [{"id":"a","topic":"t","opening_prompt":"hi","user_turns":["1","2"]}]
        """

        XCTAssertThrowsError(try ScenarioSet.decode(data(json))) { error in
            XCTAssertEqual(error as? ScenarioValidationError, .invalidTurnCount(id: "a", count: 2))
        }
    }

    func testRejectsEmptySet() {
        XCTAssertThrowsError(try ScenarioSet.decode(data("[]"))) { error in
            XCTAssertEqual(error as? ScenarioValidationError, .emptySet)
        }
    }

    func testDecodesSnakeCaseKeysFromTheSharedFile() throws {
        let scenario = Scenario(
            id: "x",
            topic: "topic",
            openingPrompt: "Hi!",
            userTurns: ["a", "b", "c"]
        )
        let encoded = try JSONEncoder().encode([scenario])
        let decoded = try ScenarioSet.decode(encoded)

        XCTAssertEqual(decoded, [scenario])
    }
}

final class MockLanguageModelClientTests: XCTestCase {
    func testCyclesThroughResponses() async throws {
        let client = MockLanguageModelClient(responses: ["one", "two"])

        let first = try await client.respond(history: [], userText: "x")
        let second = try await client.respond(history: [], userText: "x")
        let third = try await client.respond(history: [], userText: "x")

        XCTAssertEqual([first, second, third], ["one", "two", "one"])
        XCTAssertEqual(client.callCount, 3)
    }

    func testSubstitutesUserTextAndFailsWhenEmpty() async throws {
        let echoing = MockLanguageModelClient(responses: ["got: {user}"])
        let reply = try await echoing.respond(history: [], userText: "hello")
        XCTAssertEqual(reply, "got: hello")

        let empty = MockLanguageModelClient(responses: [])
        do {
            _ = try await empty.respond(history: [], userText: "hello")
            XCTFail("expected noResponses")
        } catch {
            XCTAssertEqual(error as? MockLanguageModelClient.MockError, .noResponses)
        }
    }
}
