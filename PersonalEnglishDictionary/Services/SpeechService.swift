import AVFoundation
import Foundation

@MainActor
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {}

    func speak(_ text: String, language: String = "en-US") {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)

        if language == "en-US" {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter {
                $0.language == "en-US"
            }

            for voice in voices {
                print("[Lexi Voice] Available: \(voice.name) | \(voice.identifier) | quality: \(voice.quality.rawValue)")
            }

            let evan = voices.first {
                ($0.name.localizedCaseInsensitiveContains("Evan") ||
                 $0.identifier.localizedCaseInsensitiveContains("Evan")) &&
                $0.quality == .enhanced
            }

            if let evan = evan {
                utterance.voice = evan
                print("[Lexi Voice] Evan Enhanced found")
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: language)
                print("[Lexi Voice] Evan Enhanced NOT found. Using default voice.")
            }

            if let voice = utterance.voice {
                print("[Lexi Voice] Selected: \(voice.name) | \(voice.identifier) | quality: \(voice.quality.rawValue)")
            }
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        synthesizer.speak(utterance)
    }
}
