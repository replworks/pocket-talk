import AVFoundation
import Foundation
import Observation

/// Text-to-speech for the live session, with a way to timestamp when audio actually starts.
///
/// API verified in
/// `.../iPhoneSimulator27.1.sdk/System/Library/Frameworks/AVFAudio.framework/Headers/AVSpeechSynthesis.h`
/// - `AVSpeechSynthesizer.speakUtterance:`, `.isSpeaking`, `.stopSpeakingAtBoundary:`
/// - `AVSpeechSynthesizerDelegate.speechSynthesizer(_:didStartSpeechUtterance:)`
/// - `AVSpeechUtterance(string:)`, `.voice`, `.rate`
@MainActor
@Observable
final class SpeechSynthesis: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var startContinuation: AsyncStream<Date>.Continuation?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text` and resolves when the synthesizer actually starts producing audio.
    ///
    /// Returns `nil` if audio did not start within `timeout` seconds (missing voice, silent
    /// route). The timeout matters: the live loop must not hang forever on a broken voice.
    func speakAndWaitForStart(
        _ text: String,
        localeIdentifier: String = "en-US",
        timeout: Double = 3
    ) async -> Date? {
        AudioSessionController.configureForPlayback()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: localeIdentifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let (stream, continuation) = AsyncStream<Date>.makeStream()
        startContinuation = continuation
        isSpeaking = true

        let timeoutTask = Task { [continuation] in
            try? await Task.sleep(for: .seconds(timeout))
            continuation.finish()
        }

        synthesizer.speak(utterance)

        var startedAt: Date?
        for await date in stream {
            startedAt = date
            break
        }

        timeoutTask.cancel()
        startContinuation = nil
        return startedAt
    }

    /// Renders the utterance to buffers and returns the peak sample amplitude.
    ///
    /// This separates "the synthesizer produced audio" from "the audio reached a speaker":
    /// the simulator in CI has no audio route, so a listening test proves nothing there.
    /// Returns `nil` when no buffer was produced.
    func renderedPeakAmplitude(_ text: String, localeIdentifier: String = "en-US") async -> Float? {
        let renderer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: localeIdentifier)

        let (stream, continuation) = AsyncStream<Float?>.makeStream()
        var peak: Float = 0
        var sawBuffer = false

        renderer.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                continuation.yield(sawBuffer ? peak : nil)
                continuation.finish()
                return
            }
            sawBuffer = true
            peak = max(peak, Self.peak(of: pcm))
        }

        for await value in stream {
            return value
        }
        return nil
    }

    private static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        if let floatData = buffer.floatChannelData {
            let channel = floatData[0]
            var maximum: Float = 0
            for frame in 0..<Int(buffer.frameLength) {
                maximum = max(maximum, abs(channel[frame]))
            }
            return maximum
        }
        if let int16Data = buffer.int16ChannelData {
            let channel = int16Data[0]
            var maximum: Float = 0
            for frame in 0..<Int(buffer.frameLength) {
                maximum = max(maximum, abs(Float(channel[frame]) / 32_768))
            }
            return maximum
        }
        return 0
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // Swift 6.4 imports the ObjC `didStartSpeechUtterance:` as `didStart:`
    // (header still says didStartSpeechUtterance; compiler diagnostic is authoritative).
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.startContinuation?.yield(Date())
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
