import SwiftUI
import AVFoundation

// Shared UI and interaction primitives used across multiple screens.
@MainActor
final class SpeechManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var speechEnabled = true
    private var voice: AVSpeechSynthesisVoice?
    
    init() {
        setupVoice()
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    private func setupVoice() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferredVoices = [
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.voice.supercompact.en-US.Samantha",
            "com.apple.voice.enhanced.en-GB.Kate",
            "com.apple.voice.compact.en-US.Samantha",
            "com.apple.voice.compact.en-GB.Kate",
            "com.apple.voice.enhanced.en-US.Noelle",
        ]
        
        for voiceId in preferredVoices {
            if let v = voices.first(where: { $0.identifier == voiceId }) {
                voice = v
                return
            }
        }
        
        voice = AVSpeechSynthesisVoice(language: "en-US")
    }
    
    func speak(_ text: String, emotion: Emotion = .neutral) {
        guard speechEnabled && !text.isEmpty else { return }
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        
        switch emotion {
        case .happy, .excited:
            utterance.pitchMultiplier = 1.25
            utterance.rate = 0.55
        case .sad, .concerned:
            utterance.pitchMultiplier = 0.9
            utterance.rate = 0.42
        case .angry:
            utterance.pitchMultiplier = 1.05
            utterance.rate = 0.58
        case .mysterious:
            utterance.pitchMultiplier = 0.95
            utterance.rate = 0.4
        case .surprised:
            utterance.pitchMultiplier = 1.35
            utterance.rate = 0.52
        case .gentle, .curious:
            utterance.pitchMultiplier = 1.1
            utterance.rate = 0.45
        case .neutral:
            utterance.pitchMultiplier = 1.1
            utterance.rate = 0.5
        }
        
        utterance.volume = 0.95
        
        isSpeaking = true
        synthesizer.speak(utterance)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Double(text.count) * 0.08 * 1_000_000_000))
            isSpeaking = false
        }
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    func toggle() {
        speechEnabled.toggle()
        if !speechEnabled { stop() }
    }
}

enum Emotion: String, CaseIterable {
    case neutral, happy, excited, sad, concerned, angry, mysterious, surprised, gentle, curious
}

enum CharacterAnimation {
    case idle, bounce, shake, pulse, wiggle, hop, nod
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
