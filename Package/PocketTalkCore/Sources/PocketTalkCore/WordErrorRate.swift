import Foundation

/// Word-level edit distance between a reference sentence and an ASR hypothesis.
///
/// Normalization rules (applied to both sides):
/// - lowercased
/// - apostrophes (`'`, `’`) are removed, so `don't` → `dont`
/// - every other non-alphanumeric character becomes a word separator
/// - whitespace is collapsed
public enum WordErrorRate {
    public struct Detail: Codable, Equatable, Sendable {
        public var substitutions: Int
        public var insertions: Int
        public var deletions: Int
        public var referenceWordCount: Int
        public var hypothesisWordCount: Int

        public init(
            substitutions: Int,
            insertions: Int,
            deletions: Int,
            referenceWordCount: Int,
            hypothesisWordCount: Int
        ) {
            self.substitutions = substitutions
            self.insertions = insertions
            self.deletions = deletions
            self.referenceWordCount = referenceWordCount
            self.hypothesisWordCount = hypothesisWordCount
        }

        /// (S + D + I) / reference word count.
        ///
        /// An empty reference scores 0 when the hypothesis is also empty and 1 otherwise:
        /// there is no denominator, so any output counts as an error.
        public var rate: Double {
            guard referenceWordCount > 0 else {
                return hypothesisWordCount == 0 ? 0 : 1
            }
            return Double(substitutions + deletions + insertions) / Double(referenceWordCount)
        }
    }

    public static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars {
            if scalar == "'" || scalar == "’" {
                continue
            }
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
            } else {
                scalars.append(" ")
            }
        }
        return String(scalars).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func words(_ text: String) -> [String] {
        let normalized = normalize(text)
        return normalized.isEmpty ? [] : normalized.split(separator: " ").map(String.init)
    }

    public static func detail(reference: String, hypothesis: String) -> Detail {
        let ref = words(reference)
        let hyp = words(hypothesis)

        // Levenshtein matrix over words.
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: hyp.count + 1), count: ref.count + 1)
        for r in 0...ref.count { matrix[r][0] = r }
        for c in 0...hyp.count { matrix[0][c] = c }
        if !ref.isEmpty && !hyp.isEmpty {
            for r in 1...ref.count {
                for c in 1...hyp.count {
                    if ref[r - 1] == hyp[c - 1] {
                        matrix[r][c] = matrix[r - 1][c - 1]
                    } else {
                        matrix[r][c] = min(matrix[r - 1][c - 1], matrix[r - 1][c], matrix[r][c - 1]) + 1
                    }
                }
            }
        }

        // Backtrace to label the edits.
        var substitutions = 0
        var insertions = 0
        var deletions = 0
        var r = ref.count
        var c = hyp.count

        while r > 0 || c > 0 {
            if r > 0, c > 0, ref[r - 1] == hyp[c - 1], matrix[r][c] == matrix[r - 1][c - 1] {
                r -= 1
                c -= 1
            } else if r > 0, c > 0, matrix[r][c] == matrix[r - 1][c - 1] + 1 {
                substitutions += 1
                r -= 1
                c -= 1
            } else if r > 0, matrix[r][c] == matrix[r - 1][c] + 1 {
                deletions += 1
                r -= 1
            } else {
                insertions += 1
                c -= 1
            }
        }

        return Detail(
            substitutions: substitutions,
            insertions: insertions,
            deletions: deletions,
            referenceWordCount: ref.count,
            hypothesisWordCount: hyp.count
        )
    }

    public static func compute(reference: String, hypothesis: String) -> Double {
        detail(reference: reference, hypothesis: hypothesis).rate
    }

    /// Total edit distance in words, regardless of edit type.
    public static func distance(reference: String, hypothesis: String) -> Int {
        let detail = detail(reference: reference, hypothesis: hypothesis)
        return detail.substitutions + detail.deletions + detail.insertions
    }
}
