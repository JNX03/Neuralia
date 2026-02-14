import SwiftUI
import AVFoundation

// MARK: - Speech Manager
@MainActor
final class SpeechManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var speechEnabled = true
    private var voice: AVSpeechSynthesisVoice?
    
    init() {
        voice = AVSpeechSynthesisVoice(language: "en-US")
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio setup error: \(error)")
        }
    }
    
    func speak(_ text: String) {
        guard speechEnabled && !text.isEmpty else { return }
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.pitchMultiplier = 1.1
        utterance.rate = 0.5
        
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

// MARK: - Feature Testing Menu
struct FeatureTestingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDialogTest = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "testtube.2")
                                .font(.system(size: 60))
                                .foregroundColor(.pink)
                            
                            Text("Feature Testing")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Developer Tools & Prototypes")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 50)
                        
                        // Menu Cards
                        VStack(spacing: 16) {
                            MenuCard(
                                title: "Visual Novel Dialog",
                                subtitle: "Test dialog with Ploy - includes voice, choices, and interactions",
                                icon: "bubble.left.and.bubble.right.fill",
                                color: .pink
                            ) {
                                showDialogTest = true
                            }
                            
                            MenuCard(
                                title: "Animation Tests",
                                subtitle: "Character animations and effects",
                                icon: "film.fill",
                                color: .blue,
                                disabled: true,
                                action: {}
                            )
                            
                            MenuCard(
                                title: "Audio Tests",
                                subtitle: "Sound effects and music",
                                icon: "speaker.wave.2.fill",
                                color: .green,
                                disabled: true,
                                action: {}
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                        
                        // Back Button
                        Button(action: { dismiss() }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back to Main Menu")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationDestination(isPresented: $showDialogTest) {
                VisualNovelDialogView()
            }
        }
    }
}

// MARK: - Menu Card
struct MenuCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(disabled ? .gray : color)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(disabled ? 0.1 : 0.2))
                    .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(disabled ? .gray : .white)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(disabled ? 0.3 : 0.6))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(disabled ? 0 : 0.3), lineWidth: 1)
            )
        }
        .disabled(disabled)
    }
}

// MARK: - Visual Novel Dialog View
struct VisualNovelDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechManager = SpeechManager()
    
    @State private var currentNode = 0
    @State private var displayedText = ""
    @State private var isTyping = false
    @State private var showChoices = false
    @State private var showTextInput = false
    @State private var userInput = ""
    
    // Character animation states
    @State private var charScale: CGFloat = 1.0
    @State private var charOffset: CGFloat = 0
    @State private var charRotation: Double = 0
    @State private var isPressed = false
    
    let nodes: [(speaker: String, text: String, hasChoices: Bool, hasInput: Bool)] = [
        ("Ploy", "Hello! Welcome to the dialog test! I'm Ploy. Tap me to bounce, or drag me around!", false, false),
        ("Ploy", "How are you feeling today? Choose an option below!", true, false),
        ("Ploy", "What's your name? I'd love to know!", false, true),
        ("Ploy", "Thanks for trying out this dialog system!", false, false)
    ]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Image("507room")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                Color.black.opacity(0.5).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: backAction) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Speech Toggle
                        Button(action: { speechManager.toggle() }) {
                            Image(systemName: speechManager.speechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .foregroundColor(speechManager.speechEnabled ? .green : .gray)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Character Area
                    ZStack(alignment: .bottom) {
                        Image("char")
                            .resizable()
                            .scaledToFit()
                            .frame(height: geo.size.height * 0.45)
                            .scaleEffect(charScale * (isPressed ? 0.95 : 1.0))
                            .offset(y: charOffset + (isPressed ? 10 : 0))
                            .rotationEffect(.degrees(charRotation))
                            .onTapGesture(perform: bounceAnimation)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        charOffset = value.translation.height * 0.3
                                    }
                                    .onEnded { _ in
                                        withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
                                            charOffset = 0
                                        }
                                        if abs(charOffset) > 25 {
                                            shakeAnimation()
                                        }
                                    }
                            )
                            .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                                isPressed = pressing
                                if pressing { wiggleAnimation() }
                            }, perform: {})
                        
                        // Name Tag
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Ploy")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Happy")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.pink.opacity(0.8))
                            .cornerRadius(10)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        
                        // Speech Indicator
                        if speechManager.isSpeaking {
                            HStack {
                                Spacer()
                                HStack(spacing: 3) {
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 4, height: 4)
                                            .modifier(SoundWaveModifier(delay: Double(i) * 0.1))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 80)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Dialog Box
                    VStack(spacing: 12) {
                        // Text Display
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(nodes[currentNode].speaker)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.pink)
                                    .cornerRadius(20)
                                
                                Spacer()
                                
                                if isTyping {
                                    TypingIndicator()
                                }
                            }
                            
                            Text(displayedText)
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(16)
                        .onTapGesture {
                            if isTyping { skipTyping() }
                            else if !showChoices && !showTextInput { advance() }
                        }
                        
                        // Choice Buttons
                        if showChoices {
                            VStack(spacing: 8) {
                                ChoiceButton(text: "I'm feeling great! 😊") { selectChoice("great") }
                                ChoiceButton(text: "Just okay 🤔") { selectChoice("okay") }
                                ChoiceButton(text: "Not so good 😔") { selectChoice("not good") }
                            }
                        }
                        
                        // Text Input
                        if showTextInput {
                            HStack(spacing: 10) {
                                TextField("Your name...", text: $userInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .submitLabel(.send)
                                    .onSubmit(submitInput)
                                
                                Button(action: submitInput) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(userInput.isEmpty ? .gray : .pink)
                                }
                                .disabled(userInput.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear(perform: startTyping)
    }
    
    // MARK: - Actions
    private func backAction() {
        speechManager.stop()
        dismiss()
    }
    
    private func startTyping() {
        let text = nodes[currentNode].text
        displayedText = ""
        isTyping = true
        showChoices = false
        showTextInput = false
        
        speechManager.speak(text)
        
        let chars = Array(text)
        
        Task { @MainActor in
            for index in 0..<chars.count {
                displayedText.append(chars[index])
                try? await Task.sleep(nanoseconds: 30_000_000) // 0.03 seconds
            }
            isTyping = false
            showChoices = nodes[currentNode].hasChoices
            showTextInput = nodes[currentNode].hasInput
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
    
    private func selectChoice(_ choice: String) {
        showChoices = false
        speechManager.speak("You chose \(choice)!")
        Task { @MainActor in try? await Task.sleep(nanoseconds: 1_500_000_000); advance() }
    }
    
    private func submitInput() {
        guard !userInput.isEmpty else { return }
        showTextInput = false
        speechManager.speak("Nice to meet you, \(userInput)!")
        userInput = ""
        Task { @MainActor in try? await Task.sleep(nanoseconds: 1_500_000_000); advance() }
    }
    
    // MARK: - Animations
    private func bounceAnimation() {
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 10)) {
            charScale = 1.15
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 10)) {
                charScale = 1.0
            }
        }
    }
    
    private func shakeAnimation() {
        withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
            charRotation = 6
        }
        Task { @MainActor in try? await Task.sleep(nanoseconds: 300_000_000); charRotation = 0 }
    }
    
    private func wiggleAnimation() {
        withAnimation(.easeInOut(duration: 0.08).repeatCount(10, autoreverses: true)) {
            charRotation = -10
        }
        Task { @MainActor in try? await Task.sleep(nanoseconds: 800_000_000); withAnimation { charRotation = 0 } }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .offset(y: offset)
                    .animation(.easeInOut(duration: 0.3).repeatForever().delay(Double(i) * 0.1), value: offset)
            }
        }
        .onAppear { offset = -3 }
    }
}

// MARK: - Sound Wave Modifier
struct SoundWaveModifier: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.3).repeatForever().delay(delay), value: scale)
            .onAppear { scale = 1.5 }
    }
}

// MARK: - Choice Button
struct ChoiceButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
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

#Preview {
    FeatureTestingView()
        .preferredColorScheme(.dark)
}
