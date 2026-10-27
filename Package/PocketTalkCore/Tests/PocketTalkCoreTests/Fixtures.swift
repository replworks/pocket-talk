import Foundation

/// Paths to shared fixtures that live outside the Swift package.
///
/// `eval/scenarios.json` is the single source of truth for the scenario set, so tests
/// read the repository file instead of carrying a copy that could drift.
enum Fixtures {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PocketTalkCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // PocketTalkCore
            .deletingLastPathComponent()  // Package
            .deletingLastPathComponent()  // repository root
    }

    static var scenariosURL: URL {
        repoRoot.appending(path: "eval/scenarios.json")
    }

    static var systemPromptURL: URL {
        repoRoot.appending(path: "eval/system_prompt.md")
    }
}
