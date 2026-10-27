import Foundation

/// Where measurement files land on the device.
///
/// Everything goes under `Documents/results/` so the Files app / AirDrop can pull it
/// off the phone (`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`).
enum MeasurementStore {
    static var resultsDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "results", directoryHint: .isDirectory)
    }

    static func resultsURL(fileName: String) throws -> URL {
        let directory = resultsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: fileName)
    }
}

/// Reads the system prompt from the bundled `system_prompt.md`.
///
/// The prompt text exists exactly once (in `eval/system_prompt.md`). Returning `nil`
/// instead of a built-in fallback keeps a broken bundle visible instead of silently
/// measuring a different prompt than the eval scripts.
enum PromptAsset {
    static func systemPrompt(bundle: Bundle = .main) -> String? {
        systemPrompt(named: "system_prompt", bundle: bundle)
    }

    /// Compact variant used only by the latency experiment (`eval/system_prompt_compact.md`).
    static func compactSystemPrompt(bundle: Bundle = .main) -> String? {
        systemPrompt(named: "system_prompt_compact", bundle: bundle)
    }

    static func systemPrompt(named name: String, bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: name, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let prompt = firstFencedBlock(in: text),
              !prompt.isEmpty
        else {
            return nil
        }
        return prompt
    }

    /// The prompt lives in the first fenced code block of the markdown file.
    static func firstFencedBlock(in text: String) -> String? {
        var isCollecting = false
        var buffer: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if isCollecting {
                    return buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                isCollecting = true
                continue
            }
            if isCollecting {
                buffer.append(line)
            }
        }
        return nil
    }
}
