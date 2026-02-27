import SwiftUI
import AVFoundation
import Combine

// Shared UI and interaction primitives used across multiple screens.
enum SpeechVoiceProfile {
    case `default`
    case playerFemale
    case professorMale
}

@MainActor
final class SpeechManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let globalSettings: GlobalSettingsStore
    private var cancellables = Set<AnyCancellable>()
    @Published var isSpeaking = false
    @Published var speechEnabled = true
    var rateMultiplier: Float = 1.0
    private var voice: AVSpeechSynthesisVoice?
    private var playerFemaleVoice: AVSpeechSynthesisVoice?
    private var professorMaleVoice: AVSpeechSynthesisVoice?
    
    init(globalSettings: GlobalSettingsStore? = nil) {
        self.globalSettings = globalSettings ?? GlobalSettingsStore.shared
        setupVoice()
        configureAudioSession()
        bindGlobalSettings()
    }
    
    private func configureAudioSession() {
        #if canImport(UIKit)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        #endif
    }
    
    private func setupVoice() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        setupPlayerFemaleVoice(from: voices)
        setupProfessorMaleVoice(from: voices)

        let preferredVoices = [
            "com.apple.voice.compact.en-US.Samantha",
            "com.apple.voice.compact.en-GB.Kate",
            "com.apple.ttsbundle.Samantha-compact",
            "com.apple.ttsbundle.Karen-compact",
            "com.apple.voice.compact.en-US.Noelle",
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.voice.supercompact.en-US.Samantha",
            "com.apple.voice.enhanced.en-GB.Kate",
            "com.apple.voice.enhanced.en-US.Noelle",
        ]

        voice = playerFemaleVoice
            ?? preferredVoices
            .compactMap { voiceID in voices.first(where: { $0.identifier == voiceID }) }
            .first
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private func isLikelySiriVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let identifier = voice.identifier.lowercased()
        let name = voice.name.lowercased()
        return identifier.contains("siri") || name.contains("siri")
    }

    private func englishVoiceCandidate(_ voice: AVSpeechSynthesisVoice) -> Bool {
        voice.language.hasPrefix("en-US")
            || voice.language.hasPrefix("en-GB")
            || voice.language.hasPrefix("en-AU")
            || voice.language.hasPrefix("en-IE")
            || voice.language.hasPrefix("en-IN")
            || voice.language.hasPrefix("en")
    }

    private func isUsableSpeechVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if voice.voiceTraits.contains(.isNoveltyVoice) || voice.voiceTraits.contains(.isPersonalVoice) {
            return false
        }
        return true
    }

    private func voiceNameTokens(_ text: String) -> Set<String> {
        let tokens = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return Set(tokens)
    }

    private func looksLikeFemaleVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if voice.gender == .female {
            return true
        }
        let identifier = voice.identifier.lowercased()
        let tokens = voiceNameTokens(voice.name)
        let femaleHints = ["samantha", "noelle", "karen", "kate", "ava", "victoria", "serena", "moira", "nicky", "female"]

        if femaleHints.contains(where: { identifier.contains($0) }) {
            return true
        }

        return femaleHints.contains(where: { tokens.contains($0) })
    }

    private func looksLikeMaleVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if voice.gender == .male {
            return true
        }
        let identifier = voice.identifier.lowercased()
        let tokens = voiceNameTokens(voice.name)
        let maleHints = ["alex", "daniel", "aaron", "nathan", "tom", "oliver", "fred", "eddy", "male"]

        if identifier.contains("siri_male") {
            return true
        }
        if maleHints.contains(where: { identifier.contains($0) }) {
            return true
        }

        return maleHints.contains(where: { tokens.contains($0) })
    }

    private func setupPlayerFemaleVoice(from voices: [AVSpeechSynthesisVoice]) {
        let preferredFemaleVoiceIDs = [
            "com.apple.voice.compact.en-US.Samantha",
            "com.apple.ttsbundle.Samantha-compact",
            "com.apple.voice.compact.en-US.Noelle",
            "com.apple.ttsbundle.Karen-compact",
            "com.apple.voice.compact.en-GB.Kate",
            "com.apple.voice.compact.en-AU.Karen",
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.voice.super-compact.en-US.Samantha",
            "com.apple.voice.supercompact.en-US.Samantha",
            "com.apple.voice.enhanced.en-US.Noelle",
            "com.apple.voice.compact.en-US.Noelle",
            "com.apple.voice.super-compact.en-US.Noelle",
            "com.apple.voice.enhanced.en-GB.Kate",
            "com.apple.voice.super-compact.en-GB.Kate",
            "com.apple.voice.enhanced.en-AU.Karen",
            "com.apple.voice.super-compact.en-AU.Karen",
            "com.apple.voice.compact.en-AU.Karen"
        ]

        for voiceID in preferredFemaleVoiceIDs {
            if let candidate = voices.first(where: { $0.identifier == voiceID }) {
                playerFemaleVoice = candidate
                return
            }
        }

        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            voice.gender == .female &&
            !isLikelySiriVoice(voice)
        }) {
            playerFemaleVoice = candidate
            return
        }

        let femaleIdentifierHints = ["samantha", "noelle", "karen", "kate", "ava", "victoria", "serena", "siri_female"]
        if let candidate = voices.first(where: { voice in
            let identifier = voice.identifier.lowercased()
            return englishVoiceCandidate(voice) &&
                isUsableSpeechVoice(voice) &&
                !isLikelySiriVoice(voice) &&
                femaleIdentifierHints.contains(where: { identifier.contains($0) })
        }) {
            playerFemaleVoice = candidate
            return
        }

        let preferredFemaleNames = ["Samantha", "Noelle", "Karen", "Kate", "Ava", "Nicky", "Moira", "Siri"]
        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            !isLikelySiriVoice(voice) &&
            preferredFemaleNames.contains(where: { voice.name.localizedCaseInsensitiveContains($0) })
        }) {
            playerFemaleVoice = candidate
            return
        }

        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            !isLikelySiriVoice(voice) &&
            looksLikeFemaleVoice(voice)
        }) {
            playerFemaleVoice = candidate
            return
        }

        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            !isLikelySiriVoice(voice) &&
            !looksLikeMaleVoice(voice)
        }) {
            playerFemaleVoice = candidate
            return
        }

        if let englishFallback = voices.first(where: { $0.language.hasPrefix("en") }) {
            playerFemaleVoice = englishFallback
            return
        }

        playerFemaleVoice = AVSpeechSynthesisVoice(language: "en-US")
    }

    private func saferVoiceFallback(for profile: SpeechVoiceProfile) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        switch profile {
        case .playerFemale:
            let preferredSafeIDs = [
                "com.apple.voice.compact.en-US.Samantha",
                "com.apple.ttsbundle.Samantha-compact",
                "com.apple.voice.compact.en-US.Noelle",
                "com.apple.ttsbundle.Karen-compact",
                "com.apple.voice.compact.en-GB.Kate",
                "com.apple.voice.compact.en-AU.Karen"
            ]

            if let safePreferred = preferredSafeIDs.compactMap({ id in
                voices.first(where: { $0.identifier == id })
            }).first {
                return safePreferred
            }
            return AVSpeechSynthesisVoice(language: "en-US")

        case .professorMale:
            return professorMaleVoice ?? AVSpeechSynthesisVoice(language: "en-US")

        case .default:
            return voice ?? AVSpeechSynthesisVoice(language: "en-US")
        }
    }

    private func setupProfessorMaleVoice(from voices: [AVSpeechSynthesisVoice]) {
        let preferredMaleVoiceIDs = [
            "com.apple.voice.enhanced.en-US.Daniel",
            "com.apple.voice.compact.en-US.Daniel",
            "com.apple.voice.super-compact.en-US.Daniel",
            "com.apple.voice.enhanced.en-GB.Daniel",
            "com.apple.voice.compact.en-GB.Daniel",
            "com.apple.voice.super-compact.en-GB.Daniel",
            "com.apple.voice.enhanced.en-US.Alex",
            "com.apple.voice.compact.en-US.Alex",
            "com.apple.voice.super-compact.en-US.Alex",
            "com.apple.ttsbundle.Daniel-compact",
            "com.apple.ttsbundle.Alex-compact",
            "com.apple.voice.enhanced.en-US.Aaron",
            "com.apple.voice.compact.en-US.Aaron",
            "com.apple.voice.super-compact.en-US.Aaron",
            "com.apple.voice.super-compact.en-IN.Rishi"
        ]

        for voiceID in preferredMaleVoiceIDs {
            if let candidate = voices.first(where: { $0.identifier == voiceID }) {
                professorMaleVoice = candidate
                return
            }
        }

        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            voice.gender == .male &&
            voice.identifier != playerFemaleVoice?.identifier
        }) {
            professorMaleVoice = candidate
            return
        }

        let maleIdentifierHints = ["alex", "daniel", "aaron", "nathan", "tom", "oliver", "fred", "eddy", "siri_male"]
        if let candidate = voices.first(where: { voice in
            let identifier = voice.identifier.lowercased()
            return englishVoiceCandidate(voice) &&
                isUsableSpeechVoice(voice) &&
                maleIdentifierHints.contains(where: { identifier.contains($0) }) &&
                voice.identifier != playerFemaleVoice?.identifier
        }) {
            professorMaleVoice = candidate
            return
        }

        let preferredMaleNames = ["Daniel", "Alex", "Aaron", "Nathan", "Tom", "Oliver", "Fred", "Eddy"]
        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            preferredMaleNames.contains(where: { voice.name.localizedCaseInsensitiveContains($0) })
        }) {
            professorMaleVoice = candidate
            return
        }

        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            looksLikeMaleVoice(voice) &&
            voice.identifier != playerFemaleVoice?.identifier
        }) {
            professorMaleVoice = candidate
            return
        }

        if let candidate = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            !looksLikeFemaleVoice(voice) &&
            voice.identifier != playerFemaleVoice?.identifier
        }) {
            professorMaleVoice = candidate
            return
        }

        if let englishFallback = voices.first(where: { englishVoiceCandidate($0) && isUsableSpeechVoice($0) }) {
            if englishFallback.identifier != playerFemaleVoice?.identifier {
                professorMaleVoice = englishFallback
                return
            }
        }

        if let distinctEnglish = voices.first(where: { voice in
            englishVoiceCandidate(voice) &&
            isUsableSpeechVoice(voice) &&
            voice.identifier != playerFemaleVoice?.identifier
        }) {
            professorMaleVoice = distinctEnglish
            return
        }

        professorMaleVoice = AVSpeechSynthesisVoice(language: "en-US")
    }

    private func selectedVoice(for profile: SpeechVoiceProfile) -> AVSpeechSynthesisVoice? {
        switch profile {
        case .default:
            return voice
        case .playerFemale:
            return playerFemaleVoice ?? voice
        case .professorMale:
            return professorMaleVoice ?? voice
        }
    }

    private func bindGlobalSettings() {
        speechEnabled = globalSettings.speechEnabled

        globalSettings.$speechEnabled
            .sink { [weak self] enabled in
                Task { @MainActor in
                    guard let self else { return }
                    self.speechEnabled = enabled
                    if !enabled {
                        self.stop()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func speak(
        _ text: String,
        emotion: Emotion = .neutral,
        voiceProfile: SpeechVoiceProfile = .default
    ) {
        guard globalSettings.speechEnabled && !text.isEmpty else { return }
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        var selectedSpeechVoice = selectedVoice(for: voiceProfile)
        switch voiceProfile {
        case .playerFemale:
            // Prefer compact/bundle voices for reliability on devices where Siri/enhanced voices appear
            // in the voice list but fail to synthesize in-app.
            selectedSpeechVoice = saferVoiceFallback(for: .playerFemale) ?? selectedSpeechVoice
        case .default, .professorMale:
            if let currentVoice = selectedSpeechVoice, isLikelySiriVoice(currentVoice) {
                selectedSpeechVoice = saferVoiceFallback(for: voiceProfile) ?? currentVoice
            }
        }
        if selectedSpeechVoice == nil {
            selectedSpeechVoice = saferVoiceFallback(for: voiceProfile)
        }
        utterance.voice = selectedSpeechVoice
        
        switch emotion {
        case .happy, .excited:
            utterance.pitchMultiplier = 1.25
            utterance.rate = 0.55
        case .sad, .concerned:
            utterance.pitchMultiplier = 0.9
            utterance.rate = 0.42
        case .curious:
            utterance.pitchMultiplier = 1.1
            utterance.rate = 0.45
        case .neutral:
            utterance.pitchMultiplier = 1.1
            utterance.rate = 0.5
        }

        switch voiceProfile {
        case .playerFemale:
            let needsExtraLift = selectedSpeechVoice.map(looksLikeMaleVoice) ?? false
            utterance.pitchMultiplier = max(utterance.pitchMultiplier, needsExtraLift ? 1.36 : 1.26)
            utterance.rate = max(utterance.rate, 0.54)
        case .professorMale:
            let needsExtraDrop = selectedSpeechVoice.map(looksLikeFemaleVoice) ?? false
            utterance.pitchMultiplier = min(utterance.pitchMultiplier, needsExtraDrop ? 0.58 : 0.72)
            utterance.rate = max(utterance.rate, needsExtraDrop ? 0.62 : 0.60)
        case .default:
            break
        }
        
        utterance.volume = globalSettings.effectiveSpeechVolume

        // Apply speed multiplier (from dialog speed controls)
        if rateMultiplier > 1.0 {
            utterance.rate = min(utterance.rate * rateMultiplier, AVSpeechUtteranceMaximumSpeechRate)
        }

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
        globalSettings.speechEnabled.toggle()
    }
}

enum Emotion: String, CaseIterable {
    case neutral, happy, excited, sad, concerned, curious
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

// MARK: - Generic App Audio/SFX
@MainActor
final class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    private var bgmPlayer: AVAudioPlayer?
    @Published var isMusicEnabled: Bool = true {
        didSet {
            if isMusicEnabled {
                playBGM()
            } else {
                stopBGM()
            }
        }
    }
    
    private init() {}
    
    func playBGM() {
        guard isMusicEnabled else { return }
        
        // Return if it's already playing
        if let player = bgmPlayer, player.isPlaying {
            return
        }
        
        let audioName = "chapter1" // Always use chapter1 lofi music
        
        guard let dataAsset = NSDataAsset(name: audioName) else {
            print("Failed to find audio asset: \(audioName)")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                
                let player = try AVAudioPlayer(data: dataAsset.data)
                player.numberOfLoops = -1 // Loop indefinitely
                player.volume = 0.1 // Lowered volume per user request
                player.prepareToPlay()
                
                DispatchQueue.main.async {
                    self?.bgmPlayer = player
                    self?.bgmPlayer?.play()
                }
            } catch {
                print("Failed to play bgm: \(error.localizedDescription)")
            }
        }
    }
    
    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }
}
