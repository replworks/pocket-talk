import Foundation
import PocketTalkCore

/// The 30 ASR sentences from `eval/asr_sentences.json` (15 short + 15 long).
struct ASRSentence: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var length: String
    var text: String
}

enum ASRSentenceSet {
    static func load(bundle: Bundle = .main) throws -> [ASRSentence] {
        guard let url = bundle.url(forResource: "asr_sentences", withExtension: "json") else {
            throw ASRSentenceError.missingFile
        }
        let data = try Data(contentsOf: url)
        let sentences = try JSONDecoder().decode([ASRSentence].self, from: data)
        guard sentences.count == 30 else { throw ASRSentenceError.wrongCount(sentences.count) }
        return sentences
    }
}

enum ASRSentenceError: Error, Equatable {
    case missingFile
    case wrongCount(Int)
}

/// One measured sentence: reference vs. what the recognizer heard.
struct ASRMeasurement: Identifiable, Equatable, Sendable {
    var sentenceID: String
    var reference: String
    var hypothesis: String
    var condition: String
    var detail: WordErrorRate.Detail

    var id: String { sentenceID + "-" + condition }
    var errorWords: Int { detail.substitutions + detail.deletions + detail.insertions }
    var wer: Double { detail.rate }
}

enum ASRCSV {
    static func write(_ measurements: [ASRMeasurement], to url: URL) throws {
        var lines = ["sentence_id,reference,hypothesis,error_words,wer,condition"]
        for measurement in measurements {
            lines.append(
                [
                    measurement.sentenceID,
                    escape(measurement.reference),
                    escape(measurement.hypothesis),
                    String(measurement.errorWords),
                    String(format: "%.4f", measurement.wer),
                    measurement.condition,
                ].joined(separator: ",")
            )
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escape(_ text: String) -> String {
        let needsQuotes = text.contains(",") || text.contains("\"") || text.contains("\n")
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}
