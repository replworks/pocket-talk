import SwiftUI
import PocketTalkCore

/// Tab 2 — records the 30 `eval/asr_sentences.json` sentences and writes a WER CSV.
///
/// The agent can verify that the screen loads, that SpeechAnalyzer starts and stops, and
/// that the CSV format matches `eval/compute_wer.py`. It cannot verify recognition quality:
/// that needs a human voice on a real device.
struct ASRTestView: View {
    @State private var model = ASRRunModel()

    var body: some View {
        NavigationStack {
            List {
                Section("조건") {
                    Picker("조건", selection: $model.condition) {
                        Text("조용한 곳").tag("quiet")
                        Text("걷으며").tag("walking")
                        Text("이어폰").tag("earphones")
                    }
                    .pickerStyle(.segmented)
                }

                Section("문장 \(model.index + 1) / \(model.sentences.count)") {
                    Text(model.currentSentence?.text ?? "문장 없음")
                        .font(.title3)
                    Text(model.sentenceLengthLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if model.recognizer.isRecording {
                        Button("녹음 종료") { Task { await model.finishRecording() } }
                    } else {
                        Button("녹음 시작") { Task { await model.startRecording() } }
                            .disabled(model.currentSentence == nil)
                    }
                    if model.isBusy {
                        ProgressView()
                    }
                } footer: {
                    Text(model.status)
                }

                Section("인식 결과") {
                    Text(model.lastHypothesis.isEmpty ? "—" : model.lastHypothesis)
                    if let last = model.measurements.last {
                        Text("오류 단어 \(last.errorWords) / WER \(String(format: "%.3f", last.wer))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let assetNote = model.recognizer.assetNote.isEmpty ? nil : model.recognizer.assetNote {
                        Text(assetNote).font(.caption2).foregroundStyle(.secondary)
                    }
                }

                if let error = model.recognizer.errorMessage {
                    Section("오류") {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section("기록 \(model.measurements.count)건") {
                    if model.measurements.isEmpty {
                        Text("아직 측정 없음").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.measurements) { measurement in
                            VStack(alignment: .leading) {
                                Text("\(measurement.sentenceID) · \(measurement.condition)")
                                    .font(.caption)
                                Text(measurement.hypothesis)
                                    .font(.body)
                            }
                        }
                    }
                }

                Section {
                    Button("다음 문장") { model.advance() }
                        .disabled(model.index + 1 >= model.sentences.count)
                    Button("CSV 저장") { model.saveCSV() }
                        .disabled(model.measurements.isEmpty)
                    if let savedFileName = model.savedFileName {
                        Text("Documents/results/\(savedFileName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("ASR Test")
            .task { await model.load() }
        }
    }
}

@MainActor
@Observable
final class ASRRunModel {
    var sentences: [ASRSentence] = []
    var index = 0
    var condition = "quiet"
    var status = "준비 중"
    var measurements: [ASRMeasurement] = []
    var isBusy = false
    var lastHypothesis = ""
    var savedFileName: String?

    let recognizer = SpeechRecognizer()

    var currentSentence: ASRSentence? {
        sentences.indices.contains(index) ? sentences[index] : nil
    }

    var sentenceLengthLabel: String {
        guard let currentSentence else { return "" }
        return currentSentence.length == "short" ? "짧은 문장" : "긴 문장"
    }

    func load() async {
        do {
            sentences = try ASRSentenceSet.load()
            status = "준비 완료 — \(sentences.count)문장"
            _ = await recognizer.prepare()
            if let error = recognizer.errorMessage {
                status = error
            }
        } catch {
            status = "문장 로드 실패: \(error)"
        }
    }

    func startRecording() async {
        guard currentSentence != nil else { return }
        lastHypothesis = ""
        recognizer.reset()
        isBusy = true
        await recognizer.start()
        isBusy = false
        status = recognizer.isRecording
            ? "듣는 중… 다 읽으면 '녹음 종료'"
            : (recognizer.errorMessage ?? "녹음을 시작하지 못했다")
    }

    func finishRecording() async {
        guard let sentence = currentSentence else { return }
        isBusy = true
        let hypothesis = await recognizer.stop()
        lastHypothesis = hypothesis

        let detail = WordErrorRate.detail(reference: sentence.text, hypothesis: hypothesis)
        measurements.append(
            ASRMeasurement(
                sentenceID: sentence.id,
                reference: sentence.text,
                hypothesis: hypothesis,
                condition: condition,
                detail: detail
            )
        )
        status = "인식 완료 — 오류 \(detail.substitutions + detail.deletions + detail.insertions)단어"
        isBusy = false
    }

    func advance() {
        guard index + 1 < sentences.count else { return }
        index += 1
        lastHypothesis = ""
        recognizer.reset()
        status = "다음 문장"
    }

    func saveCSV() {
        guard !measurements.isEmpty else { return }
        do {
            let fileName = "asr-\(Self.timestamp()).csv"
            let url = try MeasurementStore.resultsURL(fileName: fileName)
            try ASRCSV.write(measurements, to: url)
            savedFileName = fileName
            status = "CSV 저장 완료 (\(measurements.count)건)"
        } catch {
            status = "CSV 저장 실패: \(error)"
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    ASRTestView()
}
