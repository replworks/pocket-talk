import AVFoundation
import Foundation
import Observation
import Speech

enum SpeechPipelineError: LocalizedError {
    case transcriberUnavailable
    case unsupportedLocale(String)
    case noAudioFormat
    case noMicrophone
    case notPrepared

    var errorDescription: String? {
        switch self {
        case .transcriberUnavailable:
            return "이 기기에서 SpeechTranscriber를 쓸 수 없다"
        case .unsupportedLocale(let locale):
            return "\(locale) 음성 인식 로케일이 지원되지 않는다"
        case .noAudioFormat:
            return "SpeechAnalyzer가 쓸 오디오 포맷이 없다"
        case .noMicrophone:
            return "마이크 입력이 없다 (시뮬레이터는 Mac 마이크를 쓴다)"
        case .notPrepared:
            return "인식기가 준비되지 않았다"
        }
    }
}

/// Holds a non-Sendable `AnalyzerInputConverter` so the audio tap closure (which runs on
/// the audio thread) can convert buffers without touching main-actor state.
final class AnalyzerInputConverterBox: @unchecked Sendable {
    let converter: AnalyzerInputConverter

    init(_ converter: AnalyzerInputConverter) {
        self.converter = converter
    }
}

/// One-shot speech recognition on top of SpeechAnalyzer + SpeechTranscriber.
///
/// API verified in:
/// `.../iPhoneSimulator27.1.sdk/System/Library/Frameworks/Speech.framework/Modules/
/// Speech.swiftmodule/arm64-apple-ios-simulator.swiftinterface`
/// - `SpeechTranscriber(locale:preset:)`, `.isAvailable`, `.supportedLocale(equivalentTo:)`
/// - `.supportedLocale`, `.results` (`AsyncSequence` of `Result`, `text: AttributedString`, `isFinal`)
/// - `SpeechAnalyzer(modules:)`, `.start(inputSequence:)`, `.finalizeAndFinishThroughEndOfInput()`
/// - `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`
/// - `AssetInventory.status(forModules:)`, `.assetInstallationRequest(supporting:)`, `.reserve(locale:)`
/// - `AnalyzerInputConverter(analyzerFormat:)`, `.convert(_:at:)`
///
/// `UNVERIFIED`: no real utterance has been recorded yet (the agent cannot speak).
/// Only session start/stop on the simulator is verified.
@MainActor
@Observable
final class SpeechRecognizer {
    enum State: Equatable {
        case idle
        case preparing
        case listening
        case finishing
    }

    private(set) var state: State = .idle
    private(set) var partialText = ""
    private(set) var errorMessage: String?
    private(set) var isSupported: Bool?
    private(set) var assetNote = ""

    private let localeIdentifier: String
    private var analyzer: SpeechAnalyzer?
    private var supportedLocale: Locale?
    private var resultsTask: Task<Void, Never>?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var converterBox: AnalyzerInputConverterBox?
    private var finalText = ""
    private var isTapInstalled = false
    private let audioEngine = AVAudioEngine()

    init(localeIdentifier: String = "en-US") {
        self.localeIdentifier = localeIdentifier
    }

    var isRecording: Bool { state == .listening || state == .preparing }

    /// Checks framework support, resolves the locale and installs the speech assets if needed.
    func prepare() async -> Bool {
        guard SpeechTranscriber.isAvailable else {
            isSupported = false
            errorMessage = SpeechPipelineError.transcriberUnavailable.errorDescription
            return false
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeIdentifier)) else {
            isSupported = false
            errorMessage = SpeechPipelineError.unsupportedLocale(localeIdentifier).errorDescription
            return false
        }

        supportedLocale = locale
        isSupported = true

        // A SpeechTranscriber instance must not be reused across analyzers: reusing one
        // traps inside Speech (`TranscriberCommon.worker.setter`) on the second session
        // (device crash 2026-10-27). Probe assets with a throwaway instance.
        let probe = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let status = await AssetInventory.status(forModules: [probe])
        if status == .installed {
            assetNote = "음성 모델 설치됨"
            return true
        }

        assetNote = "음성 모델 준비 중…"
        do {
            _ = try await AssetInventory.reserve(locale: locale)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                try await request.downloadAndInstall()
            }
            assetNote = "음성 모델 준비 완료"
            return true
        } catch {
            assetNote = "음성 모델 다운로드 실패: \(error)"
            return false
        }
    }

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil
        reset()

        state = .preparing
        if isSupported != true {
            guard await prepare() else {
                state = .idle
                return
            }
        }
        guard let locale = supportedLocale else {
            errorMessage = SpeechPipelineError.notPrepared.errorDescription
            state = .idle
            return
        }

        do {
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            try activateAudioSession()

            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw SpeechPipelineError.noAudioFormat
            }

            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            inputContinuation = continuation

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            resultsTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        self.partialText = text
                        if result.isFinal {
                            self.finalText = text
                        }
                    }
                } catch {
                    self.errorMessage = "인식 실패: \(error)"
                }
            }

            try await analyzer.start(inputSequence: stream)
            try startAudio(analyzerFormat: analyzerFormat)
            state = .listening
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            teardown()
            state = .idle
        }
    }

    /// Stops recording, finalizes the analyzer and returns the final transcript.
    func stop() async -> String {
        guard isRecording else { return finalText }
        state = .finishing

        audioEngine.stop()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        inputContinuation?.finish()
        inputContinuation = nil

        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            errorMessage = "종료 실패: \(error)"
        }

        await resultsTask?.value
        teardown()
        state = .idle

        let text = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? partialText.trimmingCharacters(in: .whitespacesAndNewlines) : text
    }

    func reset() {
        partialText = ""
        finalText = ""
    }

    private func activateAudioSession() throws {
        try AudioSessionController.configureForRecording()
    }

    private func startAudio(analyzerFormat: AVAudioFormat) throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw SpeechPipelineError.noMicrophone
        }

        let box = AnalyzerInputConverterBox(AnalyzerInputConverter(analyzerFormat: analyzerFormat))
        converterBox = box
        let continuation = inputContinuation

        // The tap runs on a realtime audio thread. An explicitly @Sendable closure keeps it
        // nonisolated; a closure formed in this @MainActor method otherwise inherits isolation
        // and traps with `_dispatch_assert_queue_fail` on a device (crash seen 2026-10-27).
        let tapHandler: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [box, continuation] buffer, time in
            do {
                for input in try box.converter.convert(buffer, at: time) {
                    continuation?.yield(input)
                }
            } catch {
                // Dropping a buffer only shortens the audio the analyzer sees.
            }
        }
        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat, block: tapHandler)
        isTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func teardown() {
        audioEngine.stop()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        converterBox = nil
    }
}
