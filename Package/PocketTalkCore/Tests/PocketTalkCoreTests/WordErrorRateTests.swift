import XCTest
@testable import PocketTalkCore

final class WordErrorRateTests: XCTestCase {
    func testIdenticalSentenceHasZeroError() {
        let detail = WordErrorRate.detail(reference: "I like apples", hypothesis: "I like apples")

        XCTAssertEqual(detail.substitutions, 0)
        XCTAssertEqual(detail.deletions, 0)
        XCTAssertEqual(detail.insertions, 0)
        XCTAssertEqual(detail.rate, 0)
        XCTAssertEqual(WordErrorRate.distance(reference: "I like apples", hypothesis: "I like apples"), 0)
    }

    func testSingleSubstitution() {
        let detail = WordErrorRate.detail(reference: "I like apples", hypothesis: "I like oranges")

        XCTAssertEqual(detail.substitutions, 1)
        XCTAssertEqual(detail.deletions, 0)
        XCTAssertEqual(detail.insertions, 0)
        XCTAssertEqual(detail.referenceWordCount, 3)
        XCTAssertEqual(detail.rate, 1.0 / 3.0, accuracy: 1e-9)
    }

    func testSingleInsertion() {
        let detail = WordErrorRate.detail(reference: "I like apples", hypothesis: "I really like apples")

        XCTAssertEqual(detail.insertions, 1)
        XCTAssertEqual(detail.substitutions, 0)
        XCTAssertEqual(detail.rate, 1.0 / 3.0, accuracy: 1e-9)
    }

    func testSingleDeletion() {
        let detail = WordErrorRate.detail(reference: "I like green apples", hypothesis: "I like apples")

        XCTAssertEqual(detail.deletions, 1)
        XCTAssertEqual(detail.referenceWordCount, 4)
        XCTAssertEqual(detail.rate, 0.25, accuracy: 1e-9)
    }

    func testNormalizationIgnoresCasePunctuationAndApostrophes() {
        XCTAssertEqual(
            WordErrorRate.compute(reference: "I don't like it.", hypothesis: "i dont like it"),
            0
        )
        XCTAssertEqual(
            WordErrorRate.compute(reference: "Hello, world!", hypothesis: "hello   world"),
            0
        )
        XCTAssertEqual(WordErrorRate.normalize("It's a test—really!"), "its a test really")
    }

    func testEmptyHypothesisScoresOne() {
        XCTAssertEqual(WordErrorRate.compute(reference: "hello world", hypothesis: ""), 1)
    }

    func testEmptyReference() {
        XCTAssertEqual(WordErrorRate.compute(reference: "", hypothesis: ""), 0)
        XCTAssertEqual(WordErrorRate.compute(reference: "", hypothesis: "hello"), 1)
    }

    func testDistanceCountsAllEditTypes() {
        // Two substitutions and one deletion: 3 edits over 4 reference words.
        XCTAssertEqual(WordErrorRate.distance(reference: "a b c d", hypothesis: "a x y"), 3)
    }

    func testWhitespaceOnlyHypothesis() {
        XCTAssertEqual(WordErrorRate.compute(reference: "hello world", hypothesis: "   "), 1)
    }
}
