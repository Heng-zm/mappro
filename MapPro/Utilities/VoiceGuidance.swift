import AVFoundation
import Foundation

/// Speaks maneuver instructions for in-app navigation. Apple Maps handoff is
/// not available for OpenStreetMap-routed trips, so this keeps guidance usable.
final class VoiceGuidance: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceGuidance()

    private let synthesizer = AVSpeechSynthesizer()
    private var lastStepIndex: Int?
    private var lastSpokenText: String?
    private var hasActiveSession = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, stepIndex: Int, force: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !force, stepIndex == lastStepIndex, trimmed == lastSpokenText {
            return
        }

        configureSessionIfNeeded()
        lastStepIndex = stepIndex
        lastSpokenText = trimmed

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.12
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        lastStepIndex = nil
        lastSpokenText = nil
        deactivateSession()
    }

    // MARK: - Audio session

    private func configureSessionIfNeeded() {
        guard !hasActiveSession else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            hasActiveSession = true
        } catch {
            // Voice guidance is best-effort; navigation continues silently.
        }
    }

    private func deactivateSession() {
        guard hasActiveSession else { return }
        hasActiveSession = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.synthesizer.isSpeaking else { return }
            self.deactivateSession()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // A replacement utterance may already be speaking; only release the
        // audio session if nothing else was queued.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.synthesizer.isSpeaking else { return }
            self.deactivateSession()
        }
    }
}
