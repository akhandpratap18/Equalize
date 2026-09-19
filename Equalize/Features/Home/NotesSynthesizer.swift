import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
class NotesSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    var isPlaying = false
    var isPaused = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(text: String, language: String) {
        if isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            isPaused = false
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        
        // Very basic markdown stripping for TTS
        let cleanText = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "*", with: "")
            
        let utterance = AVSpeechUtterance(string: cleanText)
        
        // If the language code is missing or generic, fallback to en-US.
        // AVSpeechSynthesisVoice handles BCP 47 codes like "fr-FR" or "es-US"
        let availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        if let bestVoice = availableVoices.first(where: { $0.quality == .premium }) ??
                           availableVoices.first(where: { $0.quality == .enhanced }) ??
                           availableVoices.first {
            utterance.voice = bestVoice
        } else if let fallbackVoice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = fallbackVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Lower the rate slightly (0.45 instead of 0.5 default) to make foreign languages much easier to understand
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.2 // Give the engine a moment to buffer
        
        // Ensure audio session is setup for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session for TTS: \\(error)")
        }

        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
        isPaused = true
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isPlaying = false
                self.isPaused = false
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isPlaying = false
                self.isPaused = false
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            self.isPaused = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
            self.isPaused = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = true
            self.isPaused = false
        }
    }
}
