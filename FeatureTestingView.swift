import SwiftUI
import AVFoundation

// MARK: - Speech Manager with Emotion Support
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
        // Try to find best available female voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Priority order for female voices with emotion support
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
        
        // Fallback
        voice = AVSpeechSynthesisVoice(language: "en-US")
    }
    
    func speak(_ text: String, emotion: Emotion = .neutral) {
        guard speechEnabled && !text.isEmpty else { return }
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        
        // Apply emotion settings
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

// MARK: - Character Animation Types
enum CharacterAnimation {
    case idle, bounce, shake, pulse, wiggle, hop, nod
}

// FeatureTestingView uses the shared ResponsiveLayout from ResponsiveLayout.swift

// MARK: - Feature Testing Menu
struct FeatureTestingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDialogTest = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = ResponsiveLayout(
                    width: geo.size.width,
                    height: geo.size.height,
                    safeAreaInsets: geo.safeAreaInsets
                )
                
                ZStack {
                    // Animated mesh gradient background
                    MeshGradientBackground()
                    
                    ScrollView {
                        VStack(spacing: layout.sectionSpacing) {
                            // Animated header
                            FeatureHeader(layout: layout)
                                .padding(.top, geo.safeAreaInsets.top + layout.scaled(20))
                            
                            // Feature cards
                            VStack(spacing: layout.elementSpacing) {
                                FeatureCard(
                                    title: "Visual Novel Dialog",
                                    subtitle: "Interactive dialog with Ploy featuring voice, choices, and touch interactions",
                                    icon: "bubble.left.and.bubble.right.fill",
                                    color: .pink,
                                    layout: layout,
                                    isNew: true
                                ) {
                                    showDialogTest = true
                                }
                                
                                FeatureCard(
                                    title: "Animation Tests",
                                    subtitle: "Character animations and visual effects",
                                    icon: "film.fill",
                                    color: .blue,
                                    layout: layout,
                                    disabled: true,
                                    action: {}
                                )
                                
                                FeatureCard(
                                    title: "Audio Tests",
                                    subtitle: "Sound effects and voice synthesis",
                                    icon: "speaker.wave.2.fill",
                                    color: .green,
                                    layout: layout,
                                    disabled: true,
                                    action: {}
                                )
                                
                                FeatureCard(
                                    title: "UI Components",
                                    subtitle: "Buttons, cards, and interface elements",
                                    icon: "rectangle.grid.2x2.fill",
                                    color: .orange,
                                    layout: layout,
                                    disabled: true,
                                    action: {}
                                )
                            }
                            .padding(.horizontal, layout.padding)
                            
                            Spacer(minLength: layout.scaled(40))
                            
                            // Back button
                            BackButton(action: { dismiss() }, layout: layout)
                                .padding(.horizontal, layout.padding)
                                .padding(.bottom, layout.padding)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showDialogTest) {
                ResponsiveDialogView(nodes: sampleDialogNodes)
            }
        }
    }
}

// MARK: - Mesh Gradient Background (iOS 18+ fallback)
struct MeshGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base dark gradient
                LinearGradient(
                    colors: [
                        Color(hex: "0d0d1a"),
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Animated orbs
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .offset(
                        x: animate ? 100 : -50,
                        y: animate ? -80 : 50
                    )
                    .blur(radius: 80)
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.pink.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.35
                        )
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(
                        x: animate ? -80 : 60,
                        y: animate ? 100 : -60
                    )
                    .blur(radius: 60)
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true).delay(2), value: animate)
                
                // Noise overlay
                Color.black.opacity(0.15)
            }
            .ignoresSafeArea()
            .onAppear { animate = true }
        }
    }
}

// MARK: - Feature Header
struct FeatureHeader: View {
    let layout: ResponsiveLayout
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: layout.elementSpacing) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.pink.opacity(0.3))
                    .frame(width: layout.scaled(100), height: layout.scaled(100))
                    .blur(radius: layout.scaled(25))
                
                Image(systemName: "testtube.2")
                    .font(.system(size: layout.scaled(48), weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .modifier(BounceModifier())
            }
            
            Text("Feature Testing")
                .font(.system(size: layout.headlineFontSize + 4, weight: .bold))
                .foregroundColor(.white)
            
            Text("Developer Tools & Prototypes")
                .font(.system(size: layout.bodyFontSize - 1, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1
                opacity = 1
            }
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let layout: ResponsiveLayout
    var disabled: Bool = false
    var isNew: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.elementSpacing) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .fill(color.opacity(disabled ? 0.1 : 0.2))
                        .frame(width: layout.scaled(56), height: layout.scaled(56))
                    
                    Image(systemName: icon)
                        .font(.system(size: layout.scaled(24)))
                        .foregroundColor(disabled ? .gray : color)
                    
                    if isNew && !disabled {
                        NewBadge(layout: layout)
                            .offset(x: layout.scaled(20), y: -layout.scaled(20))
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: layout.elementSpacing / 2) {
                    Text(title)
                        .font(.system(size: layout.bodyFontSize + 2, weight: .semibold))
                        .foregroundColor(disabled ? .gray : .white)
                    
                    Text(subtitle)
                        .font(.system(size: layout.captionFontSize + 1))
                        .foregroundColor(.white.opacity(disabled ? 0.3 : 0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: layout.captionFontSize + 2, weight: .semibold))
                    .foregroundColor(color.opacity(isHovered ? 1 : 0.5))
                    .offset(x: isHovered ? 4 : 0)
            }
            .padding(layout.padding)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(color.opacity(disabled ? 0 : (isHovered ? 0.5 : 0.3)), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .shadow(
                color: color.opacity(disabled ? 0 : (isHovered ? 0.3 : 0.1)),
                radius: isHovered ? layout.scaled(16) : layout.scaled(8),
                x: 0,
                y: isHovered ? layout.scaled(8) : layout.scaled(4)
            )
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - New Badge
struct NewBadge: View {
    let layout: ResponsiveLayout
    
    var body: some View {
        Text("NEW")
            .font(.system(size: layout.scaled(8), weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, layout.scaled(6))
            .padding(.vertical, layout.scaled(2))
            .background(
                LinearGradient(
                    colors: [.pink, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(layout.scaled(4))
    }
}

// MARK: - Back Button
struct BackButton: View {
    let action: () -> Void
    let layout: ResponsiveLayout
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.elementSpacing) {
                Image(systemName: "arrow.left")
                    .font(.system(size: layout.bodyFontSize))
                Text("Back to Main Menu")
                    .font(.system(size: layout.bodyFontSize, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(layout.padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Visual Novel Dialog View
struct VisualNovelDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechManager = SpeechManager()
    
    // Dialog state
    @State private var currentNode = 0
    @State private var displayedText = ""
    @State private var isTyping = false
    @State private var showChoices = false
    @State private var showTextInput = false
    @State private var userInput = ""
    @State private var currentEmotion: Emotion = .happy
    
    // Character animation
    @State private var charScale: CGFloat = 1.0
    @State private var charOffset: CGFloat = 0
    @State private var charRotation: Double = 0
    @State private var charOpacity: Double = 1.0
    @State private var isPressed = false
    @State private var currentAnimation: CharacterAnimation = .idle
    
    // Haptic feedback
    @State private var impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    let nodes: [(speaker: String, text: String, emotion: Emotion, hasChoices: Bool, hasInput: Bool)] = [
        ("Ploy", "Hello! Welcome to the dialog test! I'm Ploy. Try interacting with me! Tap to bounce, drag to move, long press to wiggle!", .happy, false, false),
        ("Ploy", "How are you feeling today? Choose an option that matches your mood!", .curious, true, false),
        ("Ploy", "I'd love to know your name! Please type it below.", .gentle, false, true),
        ("Ploy", "The dialog system supports different emotions! Watch my expressions and listen to my voice change!", .excited, false, false),
        ("Ploy", "Thanks for testing this feature! I hope you enjoyed our conversation!", .happy, false, false)
    ]
    
    var body: some View {
        GeometryReader { geo in
            let layout = ResponsiveLayout(
                width: geo.size.width,
                height: geo.size.height,
                safeAreaInsets: geo.safeAreaInsets
            )
            
            ZStack {
                // Background
                Image("507room")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                // Gradient overlay for text readability
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Main content
                if layout.isLandscape && (layout.isLarge || layout.isExtraLarge) {
                    // iPad Landscape: Side by side layout
                    HStack(spacing: 0) {
                        // Left: Character
                        characterSection(layout: layout, geo: geo)
                            .frame(width: geo.size.width * 0.5)
                        
                        // Right: Dialog
                        dialogSection(layout: layout)
                            .frame(width: geo.size.width * 0.5)
                            .padding(.bottom, layout.padding)
                    }
                } else {
                    // Portrait or iPhone: Stacked layout
                    VStack(spacing: 0) {
                        // Top: Character
                        characterSection(layout: layout, geo: geo)
                        
                        // Bottom: Dialog
                        dialogSection(layout: layout)
                    }
                }
            }
        }
        .onAppear {
            impactFeedback.prepare()
            startTyping()
        }
    }
    
    // MARK: - Character Section
    private func characterSection(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        // Calculate character height based on layout
        let characterHeight: CGFloat = {
            if layout.isLarge || layout.isExtraLarge {
                return layout.isLandscape ? geo.size.height * 0.55 : geo.size.height * 0.4
            }
            return layout.isLandscape ? geo.size.height * 0.5 : geo.size.height * 0.35
        }()
        
        return ZStack(alignment: .bottom) {
            // Character shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: layout.scaled(120), height: layout.scaled(32))
                .blur(radius: layout.scaled(8))
                .offset(y: -layout.scaled(8))
            
            // Character image with all interactions
            Image("char")
                .resizable()
                .scaledToFit()
                .frame(height: characterHeight)
                .scaleEffect(charScale * (isPressed ? 0.95 : 1.0))
                .offset(y: charOffset + (isPressed ? layout.scaled(8) : 0))
                .rotationEffect(.degrees(charRotation))
                .opacity(charOpacity)
                .shadow(color: getEmotionColor().opacity(0.3), radius: layout.scaled(16), x: 0, y: layout.scaled(8))
                .onTapGesture {
                    impactFeedback.impactOccurred()
                    triggerAnimation(.bounce)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            charOffset = value.translation.height * 0.4
                        }
                        .onEnded { _ in
                            withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
                                charOffset = 0
                            }
                            if abs(charOffset) > 30 {
                                triggerAnimation(.shake)
                            }
                        }
                )
                .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                    isPressed = pressing
                    if pressing {
                        impactFeedback.impactOccurred()
                        triggerAnimation(.wiggle)
                    }
                }, perform: {})
            
            // Character name & emotion badge
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: layout.elementSpacing / 2) {
                    Text("Ploy")
                        .font(.system(size: layout.bodyFontSize, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(getEmotionColor())
                            .frame(width: layout.scaled(6), height: layout.scaled(6))
                        Text(currentEmotion.rawValue.capitalized)
                            .font(.system(size: layout.captionFontSize, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, layout.scaled(12))
                .padding(.vertical, layout.scaled(8))
                .background(.ultraThinMaterial)
                .cornerRadius(layout.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.trailing, layout.padding)
            .padding(.bottom, layout.scaled(24))
            
            // Speech indicator
            if speechManager.isSpeaking {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<4) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.green)
                                .frame(width: layout.scaled(3), height: CGFloat.random(in: layout.scaled(6)...layout.scaled(16)))
                                .animation(
                                    .easeInOut(duration: 0.25)
                                    .repeatForever()
                                    .delay(Double(i) * 0.05),
                                    value: speechManager.isSpeaking
                                )
                        }
                    }
                    .frame(height: layout.scaled(20))
                    .padding(.horizontal, layout.scaled(10))
                    .padding(.vertical, layout.scaled(6))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .padding(.trailing, layout.padding)
                .padding(.bottom, layout.scaled(80))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Dialog Section
    private func dialogSection(layout: ResponsiveLayout) -> some View {
        VStack(spacing: 16) {
            // Top bar
            HStack {
                BackButtonCompact {
                    speechManager.stop()
                    dismiss()
                }
                
                Spacer()
                
                SpeechToggleButton(speechManager: speechManager)
            }
            .padding(.horizontal, layout.padding)
            
            Spacer()
            
            // Dialog box
            VStack(spacing: 12) {
                // Main text box
                DialogTextBox(
                    speaker: nodes[currentNode].speaker,
                    text: displayedText,
                    isTyping: isTyping,
                    layout: layout,
                    onTap: {
                        if isTyping {
                            skipTyping()
                        } else if !showChoices && !showTextInput {
                            advance()
                        }
                    }
                )
                
                // Choice buttons
                if showChoices {
                    VStack(spacing: layout.elementSpacing) {
                        ChoiceButtonEnhanced(
                            text: "I'm feeling great! 😊",
                            color: .green,
                            layout: layout,
                            action: { selectChoice("great", emotion: .happy) }
                        )
                        ChoiceButtonEnhanced(
                            text: "Just okay 🤔",
                            color: .yellow,
                            layout: layout,
                            action: { selectChoice("okay", emotion: .neutral) }
                        )
                        ChoiceButtonEnhanced(
                            text: "Not so good 😔",
                            color: .blue,
                            layout: layout,
                            action: { selectChoice("not good", emotion: .sad) }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Text input
                if showTextInput {
                    EnhancedTextInput(
                        text: $userInput,
                        layout: layout,
                        onSubmit: submitInput,
                        isEnabled: !userInput.isEmpty
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, layout.padding)
            .padding(.bottom, max(20, layout.padding - 10))
        }
    }
    
    // MARK: - Helper Methods
    private func getEmotionColor() -> Color {
        switch currentEmotion {
        case .happy: return .yellow
        case .excited: return .orange
        case .sad, .concerned: return .blue
        case .angry: return .red
        case .mysterious: return .purple
        case .surprised: return .pink
        case .gentle, .curious: return .mint
        case .neutral: return .cyan
        }
    }
    
    private func triggerAnimation(_ animation: CharacterAnimation) {
        currentAnimation = animation
        
        switch animation {
        case .bounce:
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                charScale = 1.2
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                    charScale = 1.0
                }
            }
            
        case .shake:
            withAnimation(.easeInOut(duration: 0.04).repeatCount(8, autoreverses: true)) {
                charRotation = 8
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                charRotation = 0
            }
            
        case .pulse:
            withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
                charScale = 1.08
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                charScale = 1.0
            }
            
        case .wiggle:
            withAnimation(.easeInOut(duration: 0.06).repeatCount(12, autoreverses: true)) {
                charRotation = -12
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 750_000_000)
                withAnimation { charRotation = 0 }
            }
            
        case .hop:
            withAnimation(.easeOut(duration: 0.25)) {
                charOffset = -50
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
                    charOffset = 0
                }
            }
            
        case .nod:
            withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
                charRotation = 5
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                charRotation = 0
            }
            
        case .idle:
            break
        }
    }
    
    private func startTyping() {
        let node = nodes[currentNode]
        displayedText = ""
        isTyping = true
        showChoices = false
        showTextInput = false
        currentEmotion = node.emotion
        
        speechManager.speak(node.text, emotion: node.emotion)
        
        let chars = Array(node.text)
        Task { @MainActor in
            for i in 0..<chars.count {
                displayedText.append(chars[i])
                let delay = ",.;!?".contains(chars[i]) ? 120_000_000 : 25_000_000
                try? await Task.sleep(nanoseconds: UInt64(delay))
            }
            isTyping = false
            showChoices = node.hasChoices
            showTextInput = node.hasInput
        }
    }
    
    private func skipTyping() {
        displayedText = nodes[currentNode].text
        isTyping = false
        showChoices = nodes[currentNode].hasChoices
        showTextInput = nodes[currentNode].hasInput
    }
    
    private func advance() {
        if currentNode < nodes.count - 1 {
            currentNode += 1
            startTyping()
        } else {
            dismiss()
        }
    }
    
    private func selectChoice(_ choice: String, emotion: Emotion) {
        showChoices = false
        currentEmotion = emotion
        let response = emotion == .happy ? "That's wonderful to hear!" :
                      emotion == .sad ? "I'm here for you." :
                      "I understand."
        speechManager.speak(response, emotion: emotion)
        triggerAnimation(emotion == .happy ? .bounce : emotion == .sad ? .nod : .pulse)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            advance()
        }
    }
    
    private func submitInput() {
        guard !userInput.isEmpty else { return }
        showTextInput = false
        speechManager.speak("Nice to meet you, \(userInput)!", emotion: .gentle)
        triggerAnimation(.bounce)
        userInput = ""
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            advance()
        }
    }
}

// MARK: - Dialog Text Box
struct DialogTextBox: View {
    let speaker: String
    let text: String
    let isTyping: Bool
    let layout: ResponsiveLayout
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack {
                Text(speaker)
                    .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, layout.scaled(12))
                    .padding(.vertical, layout.scaled(6))
                    .background(
                        Capsule()
                            .fill(Color.pink)
                    )
                
                Spacer()
                
                if isTyping {
                    EnhancedTypingIndicator(layout: layout)
                }
            }
            
            Text(text)
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white)
                .lineSpacing(layout.scaled(4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.1), value: text)
        }
        .padding(layout.padding)
        .background(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Enhanced Choice Button
struct ChoiceButtonEnhanced: View {
    let text: String
    let color: Color
    let layout: ResponsiveLayout
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: layout.bodyFontSize, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(color)
            }
            .padding(layout.padding)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - Enhanced Text Input
struct EnhancedTextInput: View {
    @Binding var text: String
    let layout: ResponsiveLayout
    let onSubmit: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: layout.elementSpacing) {
            TextField("Your name...", text: $text)
                .font(.system(size: layout.bodyFontSize))
                .padding(.horizontal, layout.padding)
                .padding(.vertical, layout.scaled(10))
                .background(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.cornerRadius)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundColor(.white)
                .accentColor(.pink)
                .submitLabel(.send)
                .onSubmit(onSubmit)
            
            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: layout.scaled(40)))
                    .foregroundColor(isEnabled ? .pink : .gray)
                    .scaleEffect(isEnabled ? 1.0 : 0.9)
            }
            .disabled(!isEnabled)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
    }
}

// MARK: - Back Button Compact
struct BackButtonCompact: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Speech Toggle Button
struct SpeechToggleButton: View {
    @ObservedObject var speechManager: SpeechManager
    
    var body: some View {
        Button(action: { speechManager.toggle() }) {
            Image(systemName: speechManager.speechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 16))
                .foregroundColor(speechManager.speechEnabled ? .green : .gray)
                .padding(10)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Enhanced Typing Indicator
struct EnhancedTypingIndicator: View {
    let layout: ResponsiveLayout
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: layout.elementSpacing / 2) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: layout.scaled(6), height: layout.scaled(6))
                    .offset(y: offset)
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever()
                        .delay(Double(i) * 0.12),
                        value: offset
                    )
            }
        }
        .onAppear { offset = -layout.scaled(4) }
    }
}

// MARK: - Press Events Modifier
struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Bounce Modifier (iOS 16 compatible)
struct BounceModifier: ViewModifier {
    @State private var isBouncing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBouncing = true
                }
            }
    }
}

// MARK: - Color Extension
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
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Sample Dialog Nodes
let sampleDialogNodes: [DialogNode] = [
    DialogNode(
        speaker: "Ploy",
        text: "Welcome to the new Responsive Dialog System! 👋 This has been completely redesigned to work beautifully on every device - from the smallest iPhone to the largest Mac desktop screen!",
        emotion: .excited,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "Try resizing the window if you're on Mac, or rotating your device on iPad/iPhone. Watch how the layout automatically adapts! On large screens, you get a side-by-side view. On phones, everything stacks perfectly.",
        emotion: .happy,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "How are you feeling about this new responsive design?",
        emotion: .curious,
        choices: [
            DialogChoice(
                text: "I love it! 😍",
                emotion: .excited,
                response: "That's wonderful to hear!",
                nextNodeIndex: nil,
                icon: "heart.fill"
            ),
            DialogChoice(
                text: "Looks great! 👍",
                emotion: .happy,
                response: "Glad you like it!",
                nextNodeIndex: nil,
                icon: "hand.thumbsup.fill"
            ),
            DialogChoice(
                text: "It's okay 🤔",
                emotion: .neutral,
                response: "I appreciate your honesty.",
                nextNodeIndex: nil,
                icon: "checkmark.circle.fill"
            ),
            DialogChoice(
                text: "Not my style 😕",
                emotion: .sad,
                response: "I'll keep working on it!",
                nextNodeIndex: nil,
                icon: "xmark.circle.fill"
            )
        ],
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "I'd love to know your name! The text input also scales beautifully - larger on big screens, compact on small devices.",
        emotion: .gentle,
        choices: nil,
        requiresInput: true,
        inputPlaceholder: "Enter your name...",
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "Notice the settings button in the top right? You can adjust typing speed and background brightness - these settings persist during your session and work across all device sizes!",
        emotion: .happy,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "The character animations respond to your interactions: tap to bounce, drag to move, long-press to wiggle. Try it out! These interactions work with mouse, trackpad, or touch.",
        emotion: .excited,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "This dialog system features four adaptive layout modes: Stacked for phones, Side-by-Side for landscape tablets, Floating for cinematic displays, and Split for ultrawide/desktop screens!",
        emotion: .mysterious,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "Typography automatically scales based on your device size - comfortable to read whether you're on a phone held close or a monitor across the room. Every element has been carefully considered!",
        emotion: .gentle,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    ),
    DialogNode(
        speaker: "Ploy",
        text: "Thank you for testing the new Responsive Dialog System! I hope you enjoyed seeing how it adapts to different screen sizes. The future of visual novels is here! 🎉",
        emotion: .happy,
        choices: nil,
        requiresInput: false,
        inputPlaceholder: nil,
        backgroundImage: "507room",
        characterImage: "char",
        onComplete: nil
    )
]

#Preview {
    FeatureTestingView()
        .preferredColorScheme(.dark)
}
