import SwiftUI
import AVFoundation
import Combine

// MARK: - Dialog Node Types
struct DialogNode: Identifiable, Sendable {
    let id: UUID
    let speaker: String
    let text: String
    let emotion: Emotion
    let choices: [DialogChoice]?
    let requiresInput: Bool
    let inputPlaceholder: String?
    let backgroundImage: String?
    let characterImage: String?
    let cutsceneTitle: String?
    let cutsceneSubtitle: String?
    let showcaseMedia: DialogShowcaseMedia?
    let eventPayload: DialogEventPayload?
    
    init(
        speaker: String,
        text: String,
        emotion: Emotion,
        choices: [DialogChoice]? = nil,
        requiresInput: Bool = false,
        inputPlaceholder: String? = nil,
        backgroundImage: String? = nil,
        characterImage: String? = nil,
        cutsceneTitle: String? = nil,
        cutsceneSubtitle: String? = nil,
        showcaseMedia: DialogShowcaseMedia? = nil,
        eventPayload: DialogEventPayload? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.id = UUID()
        self.speaker = speaker
        self.text = text
        self.emotion = emotion
        self.choices = choices
        self.requiresInput = requiresInput
        self.inputPlaceholder = inputPlaceholder
        self.backgroundImage = backgroundImage
        self.characterImage = characterImage
        self.cutsceneTitle = cutsceneTitle
        self.cutsceneSubtitle = cutsceneSubtitle
        self.showcaseMedia = showcaseMedia
        self.eventPayload = eventPayload
    }
}

struct DialogChoice: Identifiable, Sendable {
    let id: UUID
    let text: String
    let emotion: Emotion
    let response: String
    let nextNodeIndex: Int?
    let icon: String?
    
    init(
        text: String,
        emotion: Emotion,
        response: String,
        nextNodeIndex: Int? = nil,
        icon: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.emotion = emotion
        self.response = response
        self.nextNodeIndex = nextNodeIndex
        self.icon = icon
    }
}

// MARK: - Dialog ViewModel
@MainActor
final class DialogViewModel: ObservableObject {
    @Published var nodes: [DialogNode] = []
    @Published var currentNodeIndex = 0
    @Published var displayedText = ""
    @Published var isTyping = false
    @Published var showChoices = false
    @Published var showTextInput = false
    @Published var userInput = ""
    @Published var isCompleted = false
    @Published var typingSpeed: Double = 1.0
    
    private var typingTask: Task<Void, Never>?
    private var currentEmotion: Emotion = .neutral
    
    var currentNode: DialogNode? {
        guard currentNodeIndex < nodes.count else { return nil }
        return nodes[currentNodeIndex]
    }
    
    var canGoBack: Bool {
        currentNodeIndex > 0
    }
    
    var canGoForward: Bool {
        currentNodeIndex < nodes.count - 1 && !isTyping
    }
    
    func loadNodes(_ newNodes: [DialogNode]) {
        nodes = newNodes
        currentNodeIndex = 0
        isCompleted = false
        startTyping()
    }
    
    func startTyping() {
        guard let node = currentNode else { return }
        
        typingTask?.cancel()
        displayedText = ""
        isTyping = true
        showChoices = false
        showTextInput = false
        currentEmotion = node.emotion
        
        let fullText = node.text
        let chars = Array(fullText)
        
        typingTask = Task { @MainActor in
            for i in 0..<chars.count {
                guard !Task.isCancelled else { return }
                
                displayedText.append(chars[i])
                
                // Dynamic delay based on punctuation and typing speed
                var delayNanoseconds = UInt64(30_000_000 / typingSpeed)
                if ",.;:".contains(chars[i]) {
                    delayNanoseconds = UInt64(120_000_000 / typingSpeed)
                } else if "!?".contains(chars[i]) {
                    delayNanoseconds = UInt64(200_000_000 / typingSpeed)
                }
                
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            
            if !Task.isCancelled {
                isTyping = false
                showChoices = node.choices != nil && !node.choices!.isEmpty
                showTextInput = node.requiresInput
            }
        }
    }
    
    func skipTyping() {
        typingTask?.cancel()
        guard let node = currentNode else { return }
        displayedText = node.text
        isTyping = false
        showChoices = node.choices != nil && !node.choices!.isEmpty
        showTextInput = node.requiresInput
    }
    
    func advance() {
        guard !isTyping else {
            skipTyping()
            return
        }
        
        if currentNodeIndex < nodes.count - 1 {
            currentNodeIndex += 1
            startTyping()
        } else {
            isCompleted = true
        }
    }
    
    func goBack() {
        guard canGoBack && !isTyping else { return }
        currentNodeIndex -= 1
        startTyping()
    }
    
    func selectChoice(_ choice: DialogChoice) {
        showChoices = false
        currentEmotion = choice.emotion
        
        if let nextIndex = choice.nextNodeIndex {
            currentNodeIndex = nextIndex
            startTyping()
        } else {
            advance()
        }
    }
    
    func submitInput() {
        guard !userInput.isEmpty else { return }
        showTextInput = false
        userInput = ""
        advance()
    }
    
    func setTypingSpeed(_ speed: Double) {
        typingSpeed = max(0.5, min(3.0, speed))
    }
}

// MARK: - Adaptive Layout Engine
struct DialogAdaptiveLayout {
    let width: CGFloat
    let height: CGFloat
    let safeAreaInsets: EdgeInsets
    
    // Device Categories
    var isCompact: Bool { width < 400 }
    var isRegular: Bool { width >= 400 && width < 768 }
    var isLarge: Bool { width >= 768 && width < 1200 }
    var isExtraLarge: Bool { width >= 1200 }
    
    var isLandscape: Bool { width > height }
    var isPortrait: Bool { width <= height }
    
    // Aspect ratio categories
    var isUltrawide: Bool { width / height > 2.0 }
    var isCinema: Bool { width / height > 1.8 }
    
    // MARK: - Dialog Box Dimensions
    var dialogMaxWidth: CGFloat {
        switch true {
        case isCompact: return width - 32
        case isRegular: return min(width - 48, 500)
        case isLarge: return isLandscape ? 520 : min(width - 64, 550)
        case isExtraLarge: return isLandscape ? 600 : 550
        default: return width - 32
        }
    }
    
    var dialogPadding: CGFloat {
        switch true {
        case isCompact: return 16
        case isRegular: return 20
        case isLarge: return 24
        case isExtraLarge: return 28
        default: return 20
        }
    }
    
    var dialogCornerRadius: CGFloat {
        switch true {
        case isCompact: return 16
        case isRegular: return 20
        case isLarge: return 24
        case isExtraLarge: return 28
        default: return 20
        }
    }
    
    // MARK: - Character/Image Dimensions
    var characterMaxHeight: CGFloat {
        let availableHeight = height - dialogHeight - safeAreaInsets.top - safeAreaInsets.bottom - 40
        
        switch true {
        case isCompact:
            return isLandscape ? min(height * 0.55, availableHeight) : min(height * 0.35, availableHeight)
        case isRegular:
            return isLandscape ? min(height * 0.5, availableHeight) : min(height * 0.38, availableHeight)
        case isLarge:
            return isLandscape ? min(height * 0.6, availableHeight) : min(height * 0.42, availableHeight)
        case isExtraLarge:
            return isLandscape ? min(height * 0.65, availableHeight) : min(height * 0.45, availableHeight)
        default:
            return height * 0.35
        }
    }
    
    var characterMaxWidth: CGFloat {
        switch true {
        case isCompact: return isLandscape ? width * 0.35 : width * 0.7
        case isRegular: return isLandscape ? width * 0.4 : width * 0.75
        case isLarge: return isLandscape ? width * 0.3 : width * 0.6
        case isExtraLarge: return isLandscape ? width * 0.25 : width * 0.5
        default: return width * 0.7
        }
    }
    
    // MARK: - Typography
    var speakerFontSize: CGFloat {
        switch true {
        case isCompact: return 13
        case isRegular: return 14
        case isLarge: return 15
        case isExtraLarge: return 16
        default: return 14
        }
    }
    
    var bodyFontSize: CGFloat {
        switch true {
        case isCompact: return 15
        case isRegular: return 17
        case isLarge: return 19
        case isExtraLarge: return 21
        default: return 17
        }
    }
    
    var choiceFontSize: CGFloat {
        switch true {
        case isCompact: return 14
        case isRegular: return 15
        case isLarge: return 16
        case isExtraLarge: return 17
        default: return 15
        }
    }
    
    var captionFontSize: CGFloat {
        switch true {
        case isCompact: return 11
        case isRegular: return 12
        case isLarge: return 13
        case isExtraLarge: return 14
        default: return 12
        }
    }
    
    // MARK: - Layout Calculations
    var dialogHeight: CGFloat {
        let baseHeight: CGFloat = isCompact ? 180 : 200
        let choiceHeight: CGFloat = showChoices ? CGFloat(choiceCount) * choiceHeight + (CGFloat(choiceCount - 1) * choiceSpacing) : 0
        return baseHeight + choiceHeight
    }
    
    var choiceCount = 0
    var showChoices = false
    var choiceHeight: CGFloat { isCompact ? 50 : 56 }
    var choiceSpacing: CGFloat { isCompact ? 8 : 12 }
    
    // MARK: - Spacing
    var sectionSpacing: CGFloat {
        switch true {
        case isCompact: return 12
        case isRegular: return 16
        case isLarge: return 20
        case isExtraLarge: return 24
        default: return 16
        }
    }
    
    var elementSpacing: CGFloat {
        switch true {
        case isCompact: return 8
        case isRegular: return 10
        case isLarge: return 12
        case isExtraLarge: return 14
        default: return 10
        }
    }
    
    // MARK: - Layout Mode
    enum LayoutMode {
        case stacked          // Character on top, dialog below (portrait phones)
        case sideBySide       // Character left, dialog right (landscape iPad/Mac)
        case floating         // Floating dialog over character (cinematic)
        case split            // 50/50 split (ultrawide monitors)
    }
    
    var layoutMode: LayoutMode {
        if isUltrawide || (isExtraLarge && isLandscape) {
            return .split
        } else if isLarge && isLandscape {
            return .sideBySide
        } else if isCinema && isLandscape {
            return .floating
        } else {
            return .stacked
        }
    }
    
    // MARK: - Choice Grid
    var choiceColumns: Int {
        switch true {
        case isCompact: return 1
        case isRegular && isLandscape: return 2
        case isLarge, isExtraLarge: return isLandscape ? 2 : 1
        default: return 1
        }
    }
}

// MARK: - Responsive Dialog View
struct ResponsiveDialogView: View {
    @StateObject private var viewModel = DialogViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Configuration
    let nodes: [DialogNode]
    let showBackButton: Bool
    let showSettings: Bool
    let onComplete: (() -> Void)?
    
    // Animation states
    @State private var characterScale: CGFloat = 1.0
    @State private var characterOffset: CGFloat = 0
    @State private var characterRotation: Double = 0
    @State private var isCharacterPressed = false
    @State private var showSettingsPanel = false
    @State private var backgroundOpacity: Double = 1.0
    
    init(
        nodes: [DialogNode],
        showBackButton: Bool = true,
        showSettings: Bool = true,
        onComplete: (() -> Void)? = nil
    ) {
        self.nodes = nodes
        self.showBackButton = showBackButton
        self.showSettings = showSettings
        self.onComplete = onComplete
    }
    
    var body: some View {
        GeometryReader { geometry in
            let layout = DialogAdaptiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                // Background
                backgroundLayer(layout: layout)
                
                // Main content based on layout mode
                switch layout.layoutMode {
                case .stacked:
                    stackedLayout(layout: layout, geometry: geometry)
                case .sideBySide:
                    sideBySideLayout(layout: layout, geometry: geometry)
                case .floating:
                    floatingLayout(layout: layout, geometry: geometry)
                case .split:
                    splitLayout(layout: layout, geometry: geometry)
                }
                
                // Settings overlay
                if showSettingsPanel {
                    settingsPanel(layout: layout)
                }
                
                // Completion overlay
                if viewModel.isCompleted {
                    completionOverlay(layout: layout)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            viewModel.loadNodes(nodes)
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                onComplete?()
            }
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
    
    // MARK: - Background Layer
    private func backgroundLayer(layout: DialogAdaptiveLayout) -> some View {
        ZStack {
            // Base background image or color
            if let backgroundImage = viewModel.currentNode?.backgroundImage,
               !backgroundImage.isEmpty {
                Image(backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.5)],
                center: .center,
                startRadius: 80,
                endRadius: max(layout.width, layout.height)
            )
            .ignoresSafeArea()
        }
        .opacity(backgroundOpacity)
    }
    
    // MARK: - Stacked Layout (Portrait/Default)
    private func stackedLayout(layout: DialogAdaptiveLayout, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top bar
            topBar(layout: layout)
                .padding(.horizontal, layout.dialogPadding)
                .padding(.top, layout.safeAreaInsets.top + 10)
            
            // Character section
            characterSection(layout: layout)
                .frame(maxHeight: layout.characterMaxHeight)
                .padding(.horizontal, layout.dialogPadding)
            
            Spacer()
            
            // Dialog section
            dialogSection(layout: layout)
                .padding(.horizontal, layout.dialogPadding)
                .padding(.bottom, layout.safeAreaInsets.bottom + 20)
        }
    }
    
    // MARK: - Side by Side Layout (Landscape iPad)
    private func sideBySideLayout(layout: DialogAdaptiveLayout, geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left: Character
            ZStack {
                characterSection(layout: layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Back button overlay
                if showBackButton {
                    VStack {
                        HStack {
                            backButton(layout: layout)
                            Spacer()
                            if showSettings {
                                pauseButton(layout: layout)
                            }
                        }
                        .padding(.horizontal, layout.dialogPadding)
                        .padding(.top, layout.safeAreaInsets.top + 10)
                        Spacer()
                    }
                }
            }
            .frame(width: geometry.size.width * 0.45)
            
            // Right: Dialog
            dialogSection(layout: layout)
                .frame(width: geometry.size.width * 0.55)
                .padding(.horizontal, layout.dialogPadding)
                .padding(.vertical, layout.safeAreaInsets.top + 20)
        }
    }
    
    // MARK: - Floating Layout (Cinematic)
    private func floatingLayout(layout: DialogAdaptiveLayout, geometry: GeometryProxy) -> some View {
        ZStack {
            // Full screen character
            characterSection(layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating dialog at bottom
            VStack {
                Spacer()
                dialogSection(layout: layout)
                    .padding(.horizontal, max(layout.dialogPadding, (layout.width - layout.dialogMaxWidth) / 2))
                    .padding(.bottom, layout.safeAreaInsets.bottom + 30)
            }
            
            // Top controls
            topBar(layout: layout)
                .padding(.horizontal, layout.dialogPadding)
                .padding(.top, layout.safeAreaInsets.top + 10)
        }
    }
    
    // MARK: - Split Layout (Ultrawide/Desktop)
    private func splitLayout(layout: DialogAdaptiveLayout, geometry: GeometryProxy) -> some View {
        HStack(spacing: layout.sectionSpacing * 2) {
            // Left panel: Character info & visual
            VStack {
                topBar(layout: layout)
                
                Spacer()
                
                characterSection(layout: layout)
                    .frame(maxHeight: layout.height * 0.7)
                
                Spacer()
            }
            .frame(width: geometry.size.width * 0.4)
            .padding(.horizontal, layout.dialogPadding)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
            
            // Right panel: Dialog
            VStack {
                Spacer()
                dialogSection(layout: layout)
                    .frame(maxWidth: 700)
                Spacer()
            }
            .frame(width: geometry.size.width * 0.6)
            .padding(.horizontal, layout.dialogPadding)
        }
        .padding(.vertical, layout.safeAreaInsets.top + 20)
    }
    
    // MARK: - Top Bar
    private func topBar(layout: DialogAdaptiveLayout) -> some View {
        HStack {
            if showBackButton {
                backButton(layout: layout)
            }
            
            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.currentNode?.cutsceneTitle ?? "Story")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Line \(min(viewModel.currentNodeIndex + 1, max(viewModel.nodes.count, 1))) / \(max(viewModel.nodes.count, 1))")
                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                    .foregroundColor(.white.opacity(0.68))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.42), in: Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            Spacer()
            
            HStack(spacing: layout.elementSpacing) {
                // History button (only on larger screens)
                if layout.isLarge || layout.isExtraLarge {
                    historyButton(layout: layout)
                }
                
                if showSettings {
                    pauseButton(layout: layout)
                }
            }
        }
    }
    
    private func backButton(layout: DialogAdaptiveLayout) -> some View {
        DialogControlButton(
            icon: "xmark",
            title: layout.isCompact ? nil : "Exit",
            action: { dismiss() },
            layout: layout
        )
    }
    
    private func pauseButton(layout: DialogAdaptiveLayout) -> some View {
        DialogControlButton(
            icon: "pause.fill",
            title: layout.isCompact ? nil : "Pause",
            action: { withAnimation(.spring()) { showSettingsPanel.toggle() } },
            layout: layout
        )
    }
    
    private func historyButton(layout: DialogAdaptiveLayout) -> some View {
        DialogControlButton(
            icon: "clock.arrow.circlepath",
            title: nil as String?,
            action: { /* Show history */ },
            layout: layout
        )
    }
    
    // MARK: - Character Section
    private func characterSection(layout: DialogAdaptiveLayout) -> some View {
        ZStack(alignment: .bottom) {
            // Character shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(
                    width: layout.isCompact ? 120 : (layout.isRegular ? 140 : 180),
                    height: layout.isCompact ? 30 : (layout.isRegular ? 35 : 45)
                )
                .blur(radius: 8)
                .offset(y: -10)
            
            // Character image
            characterImage(layout: layout)
                .frame(maxWidth: layout.characterMaxWidth, maxHeight: layout.characterMaxHeight)
            
            // Character info badge
            characterInfoBadge(layout: layout)
                .padding(.trailing, layout.isCompact ? 16 : 24)
                .padding(.bottom, layout.isCompact ? 20 : 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func characterImage(layout: DialogAdaptiveLayout) -> some View {
        let imageName =
            viewModel.currentNode?.characterImage ??
            "char_\(viewModel.currentNode?.emotion.rawValue ?? Emotion.neutral.rawValue)"
        
        return Image(imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(characterScale * (isCharacterPressed ? 0.97 : 1.0))
            .offset(y: characterOffset + (isCharacterPressed ? 5 : 0))
            .rotationEffect(.degrees(characterRotation))
            .shadow(
                color: getEmotionColor(viewModel.currentNode?.emotion ?? .neutral).opacity(0.3),
                radius: layout.isCompact ? 15 : 25,
                x: 0,
                y: layout.isCompact ? 8 : 12
            )
            .onTapGesture {
                triggerBounceAnimation()
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        characterOffset = value.translation.height * 0.3
                    }
                    .onEnded { _ in
                        withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
                            characterOffset = 0
                        }
                    }
            )
            .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                isCharacterPressed = pressing
                if pressing {
                    triggerWiggleAnimation()
                }
            }, perform: {})
    }
    
    private func characterInfoBadge(layout: DialogAdaptiveLayout) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: layout.elementSpacing / 2) {
                Text(viewModel.currentNode?.speaker ?? "Unknown")
                    .font(.system(size: layout.speakerFontSize + 2, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(getEmotionColor(viewModel.currentNode?.emotion ?? .neutral))
                        .frame(width: layout.isCompact ? 5 : 6, height: layout.isCompact ? 5 : 6)
                    Text(viewModel.currentNode?.emotion.rawValue.capitalized ?? "Neutral")
                        .font(.system(size: layout.captionFontSize, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, layout.isCompact ? 10 : 14)
            .padding(.vertical, layout.isCompact ? 8 : 10)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 12, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Dialog Section
    private func dialogSection(layout: DialogAdaptiveLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            // Progress indicator
            if layout.isLarge || layout.isExtraLarge {
                progressIndicator(layout: layout)
            }

            if let node = viewModel.currentNode,
               (node.cutsceneTitle != nil || node.cutsceneSubtitle != nil) {
                DialogCutsceneBanner(
                    title: node.cutsceneTitle ?? "Scene",
                    subtitle: node.cutsceneSubtitle,
                    layout: layout
                )
            }

            if let showcase = viewModel.currentNode?.showcaseMedia {
                DialogShowcaseCard(showcase: showcase, layout: layout)
                    .id(showcase.imageName + (showcase.badge ?? ""))
            }

            if let eventPayload = viewModel.currentNode?.eventPayload {
                DialogEventPanel(eventPayload: eventPayload, layout: layout)
                    .id(eventPayload.id)
            }
            
            // Main dialog box
            dialogBox(layout: layout)
            
            // Choice buttons
            if viewModel.showChoices, let choices = viewModel.currentNode?.choices {
                choicesGrid(choices: choices, layout: layout)
            }
            
            // Text input
            if viewModel.showTextInput {
                textInputSection(layout: layout)
            }
            
            // Navigation hint
            if !viewModel.showChoices && !viewModel.showTextInput && !viewModel.isTyping {
                navigationHint(layout: layout)
            }
        }
        .frame(maxWidth: layout.dialogMaxWidth)
    }
    
    private func progressIndicator(layout: DialogAdaptiveLayout) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.nodes.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index <= viewModel.currentNodeIndex ? Color.pink.opacity(0.95) : Color.white.opacity(0.14))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentNodeIndex)
            }
        }
        .frame(maxWidth: 260)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.35), in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func dialogBox(layout: DialogAdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack(alignment: .center) {
                Text(viewModel.currentNode?.speaker ?? "")
                    .font(.system(size: layout.speakerFontSize + 1, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, layout.isCompact ? 12 : 14)
                    .padding(.vertical, layout.isCompact ? 6 : 7)
                    .background(Color.pink.opacity(0.95), in: Capsule())

                Spacer()

                if viewModel.isTyping {
                    TypingIndicator(layout: layout)
                }

                if viewModel.isTyping {
                    Button(action: { viewModel.skipTyping() }) {
                        Text("Skip")
                            .font(.system(size: layout.captionFontSize, weight: .bold))
                            .foregroundColor(.white.opacity(0.82))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let sceneSubtitle = viewModel.currentNode?.cutsceneSubtitle {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.pink.opacity(0.7))
                        .frame(width: 2, height: 12)
                    Text(sceneSubtitle.uppercased())
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(1.0)
                        .lineLimit(1)
                    Spacer()
                }
            }
            
            Text(viewModel.displayedText)
                .font(.system(size: layout.bodyFontSize, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.98))
                .lineSpacing(layout.isCompact ? 5 : 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
                .padding(.top, 2)

            HStack {
                Text(viewModel.showChoices ? "Choose an option" : (viewModel.showTextInput ? "Write your answer" : "Tap to continue"))
                    .font(.system(size: layout.captionFontSize, weight: .medium))
                    .foregroundColor(.white.opacity(0.48))

                Spacer()

                if !viewModel.isTyping && !viewModel.showChoices && !viewModel.showTextInput {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.45))
                }
            }
        }
        .padding(layout.isCompact ? 14 : 18)
        .background(
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.04), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 6)
        .onTapGesture {
            viewModel.advance()
        }
        .onHover { hovering in
            #if os(macOS)
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
    }
    
    private func choicesGrid(choices: [DialogChoice], layout: DialogAdaptiveLayout) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: layout.choiceSpacing), count: layout.choiceColumns)
        
        return LazyVGrid(columns: columns, spacing: layout.choiceSpacing) {
            ForEach(choices) { choice in
                ChoiceButton(
                    choice: choice,
                    layout: layout,
                    action: { viewModel.selectChoice(choice) }
                )
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func textInputSection(layout: DialogAdaptiveLayout) -> some View {
        HStack(spacing: layout.elementSpacing) {
            TextField(
                viewModel.currentNode?.inputPlaceholder ?? "Type here...",
                text: $viewModel.userInput
            )
            .font(.system(size: layout.bodyFontSize))
            .padding(.horizontal, layout.isCompact ? 12 : 16)
            .padding(.vertical, layout.isCompact ? 10 : 12)
            .background(
                RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 12)
                    .fill(Color.black.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 12)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .accentColor(.pink)
            .submitLabel(.send)
            .onSubmit { viewModel.submitInput() }
            
            Button(action: { viewModel.submitInput() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: layout.isCompact ? 36 : 44))
                    .foregroundColor(!viewModel.userInput.isEmpty ? .pink : .gray)
            }
            .disabled(viewModel.userInput.isEmpty)
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: layout.isCompact ? 12 : 14))
        .overlay(
            RoundedRectangle(cornerRadius: layout.isCompact ? 12 : 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func navigationHint(layout: DialogAdaptiveLayout) -> some View {
        HStack {
            Spacer()
            Text("Tap to continue story")
                .font(.system(size: layout.captionFontSize, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35), in: Capsule())
            Spacer()
        }
    }
    
    // MARK: - Settings Panel
    private func settingsPanel(layout: DialogAdaptiveLayout) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) { showSettingsPanel = false }
                }
            
            VStack(spacing: layout.sectionSpacing) {
                Text("Paused")
                    .font(.system(size: layout.bodyFontSize + 2, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Chapter is paused. Resume, adjust settings, or exit.")
                    .font(.system(size: layout.captionFontSize + 1))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)

                Divider()
                    .background(Color.white.opacity(0.2))

                HStack(spacing: 10) {
                    Button(action: { showSettingsPanel = false }) {
                        Text("Resume")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.pink)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button(action: { dismiss() }) {
                        Text("Exit Chapter")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.14))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Typing speed
                VStack(alignment: .leading, spacing: 8) {
                    Text("Typing Speed")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white)
                    
                    HStack {
                        Text("Slow")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Slider(value: $viewModel.typingSpeed, in: 0.5...3.0, step: 0.5)
                        
                        Text("Fast")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Background opacity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background Brightness")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white)
                    
                    Slider(value: $backgroundOpacity, in: 0.3...1.0)
                }
                
                Button(action: { showSettingsPanel = false }) {
                    Text("Close Pause Menu")
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(layout.dialogPadding)
            .background(
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.dialogCornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: min(layout.dialogMaxWidth, 400))
            .padding(.horizontal, layout.dialogPadding)
        }
    }
    
    // MARK: - Completion Overlay
    private func completionOverlay(layout: DialogAdaptiveLayout) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: layout.sectionSpacing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: layout.isCompact ? 48 : 64))
                    .foregroundColor(.green)
                
                Text("Dialog Complete")
                    .font(.system(size: layout.bodyFontSize + 4, weight: .bold))
                    .foregroundColor(.white)
                
                Text("You've reached the end of this conversation.")
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: layout.sectionSpacing) {
                    Button(action: { viewModel.currentNodeIndex = 0; viewModel.isCompleted = false; viewModel.startTyping() }) {
                        Text("Restart")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, layout.dialogPadding)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, layout.dialogPadding)
                            .padding(.vertical, 12)
                            .background(Color.pink)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(layout.dialogPadding * 1.5)
            .background(
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, layout.dialogPadding)
        }
    }
    
    // MARK: - Animations
    private func triggerBounceAnimation() {
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
            characterScale = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                characterScale = 1.0
            }
        }
    }
    
    private func triggerWiggleAnimation() {
        withAnimation(.easeInOut(duration: 0.05).repeatCount(10, autoreverses: true)) {
            characterRotation = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            characterRotation = 0
        }
    }
    
    private func getEmotionColor(_ emotion: Emotion) -> Color {
        switch emotion {
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
}

// MARK: - Supporting Views
struct DialogControlButton: View {
    let icon: String
    let title: String?
    let action: () -> Void
    let layout: DialogAdaptiveLayout
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .medium))
                
                if let title = title {
                    Text(title)
                        .font(.system(size: layout.captionFontSize + 2, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, title != nil ? (layout.isCompact ? 10 : 14) : (layout.isCompact ? 8 : 10))
            .padding(.vertical, title != nil ? (layout.isCompact ? 6 : 8) : (layout.isCompact ? 8 : 10))
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isHovered ? 0.28 : 0.14), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct ChoiceButton: View {
    let choice: DialogChoice
    let layout: DialogAdaptiveLayout
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.elementSpacing) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(getEmotionColor(choice.emotion))
                    .frame(width: 4, height: layout.isCompact ? 28 : 34)

                // Icon if available
                if let icon = choice.icon {
                    Image(systemName: icon)
                        .font(.system(size: layout.choiceFontSize))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: layout.isCompact ? 24 : 28)
                }
                
                Text(choice.text)
                    .font(.system(size: layout.choiceFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(getEmotionColor(choice.emotion).opacity(0.7))
            }
            .padding(.horizontal, layout.isCompact ? 12 : 16)
            .padding(.vertical, layout.isCompact ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: layout.isCompact ? 12 : 14, style: .continuous)
                    .fill(Color.black.opacity(isHovered ? 0.78 : 0.68))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.isCompact ? 12 : 14, style: .continuous)
                            .stroke(getEmotionColor(choice.emotion).opacity(isHovered ? 0.55 : 0.3), lineWidth: 1.2)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { isHovered = $0 }
        #endif
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    private func getEmotionColor(_ emotion: Emotion) -> Color {
        switch emotion {
        case .happy: return .green
        case .excited: return .orange
        case .sad, .concerned: return .blue
        case .angry: return .red
        case .mysterious: return .purple
        case .surprised: return .pink
        case .gentle, .curious: return .mint
        case .neutral: return .cyan
        }
    }
}

struct TypingIndicator: View {
    let layout: DialogAdaptiveLayout
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: layout.isCompact ? 3 : 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: layout.isCompact ? 5 : 6, height: layout.isCompact ? 5 : 6)
                    .offset(y: offset)
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever()
                        .delay(Double(i) * 0.12),
                        value: offset
                    )
            }
        }
        .onAppear { offset = -4 }
    }
}

struct DialogCutsceneBanner: View {
    let title: String
    let subtitle: String?
    let layout: DialogAdaptiveLayout

    var body: some View {
        HStack(alignment: .center, spacing: layout.elementSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: layout.captionFontSize + 1, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(1.2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "film.stack.fill")
                .font(.system(size: layout.captionFontSize + 8))
                .foregroundColor(.pink.opacity(0.85))
        }
        .padding(layout.isCompact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 16)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct DialogShowcaseCard: View {
    let showcase: DialogShowcaseMedia
    let layout: DialogAdaptiveLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            ZStack(alignment: .topLeading) {
                Image(showcase.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: layout.isCompact ? 140 : 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if let badge = showcase.badge {
                    Text(badge)
                        .font(.system(size: layout.captionFontSize, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(showcase.title)
                    .font(.system(size: layout.bodyFontSize, weight: .bold))
                    .foregroundColor(.white)
                Text(showcase.subtitle)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(2)
            }
        }
        .padding(layout.isCompact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct DialogEventPanel: View {
    let eventPayload: DialogEventPayload
    let layout: DialogAdaptiveLayout

    @State private var didTrigger = false
    @State private var phoneMessages: [String] = [
        "Unknown: ...you there?",
        "Ploy: Link is noisy. Say something simple."
    ]
    @State private var phoneDraft = ""
    @State private var memoryProgress: Double = 0.18
    @State private var selectedBiasCard = 0
    @State private var chatStarted = false
    @State private var chatObjectiveComplete = false
    @State private var reviewedBiasCards: Set<Int> = []
    @State private var biasPressure: Double = 0.72
    @State private var biasResolved = false
    @State private var memoryEpoch = 0
    @State private var memoryStepCount = 0
    @State private var selectedChatOption: String? = nil
    @State private var promptDraftTokens: [String] = []
    @State private var promptAIName = ""
    @State private var promptWorkshopPassed = false
    @State private var promptFeedback = "Build a prompt with goal, context, output format, and an ethical rule."
    @State private var selectedPromptCategory: String = "Goal"

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack(alignment: .top, spacing: layout.elementSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eventPayload.title)
                        .font(.system(size: layout.bodyFontSize, weight: .bold))
                        .foregroundColor(.white)
                    Text(eventPayload.subtitle)
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.72))
                }
                Spacer()
                Text(eventPayload.type.rawValue.uppercased())
                    .font(.system(size: layout.captionFontSize - 1, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }

            eventContent

            statusBanner

            if !eventPayload.metrics.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: layout.choiceSpacing
                ) {
                    ForEach(eventPayload.metrics) { metric in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.label.uppercased())
                                .font(.system(size: max(layout.captionFontSize - 2, 9), weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                            Text(metric.value)
                                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                                .foregroundColor(metric.accentHex.map { Color(hex: $0) } ?? .white)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }

            if !eventPayload.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(eventPayload.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: layout.captionFontSize, weight: .semibold))
                                .foregroundColor(.white.opacity(0.82))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.06), in: Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: triggerEventHook) {
                    HStack(spacing: 8) {
                        Image(systemName: actionButtonIcon)
                        Text(actionButtonLabel)
                            .lineLimit(1)
                    }
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: didTrigger
                                ? [actionAccent.opacity(0.95), actionAccent.opacity(0.65)]
                                : [Color.pink.opacity(0.95), Color.orange.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .disabled(actionCompleted)
                .opacity(actionCompleted ? 0.92 : 1.0)

                Text(eventPayload.hookName)
                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.68))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(layout.isCompact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18)
                .fill(
                    LinearGradient(
                        colors: eventPayload.type == .mobileChat
                            ? [
                                Color(red: 0.09, green: 0.10, blue: 0.13),
                                Color(red: 0.07, green: 0.08, blue: 0.11)
                            ]
                            : eventPayload.type == .promptWorkshop
                                ? [
                                    Color(red: 0.10, green: 0.10, blue: 0.14),
                                    Color(red: 0.08, green: 0.08, blue: 0.11)
                                ]
                                : [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18)
                        .stroke(
                            (eventPayload.type == .mobileChat || eventPayload.type == .promptWorkshop)
                                ? Color.white.opacity(0.10)
                                : Color.white.opacity(0.14),
                            lineWidth: 1
                        )
                )
        )
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: layout.captionFontSize, weight: .bold))
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var eventContent: some View {
        switch eventPayload.type {
        case .mobileChat:
            mobileChatPreview
        case .promptWorkshop:
            promptWorkshopPreview
        case .hallucinationBias:
            hallucinationBiasPreview
        case .memoryTraining:
            memoryTrainingPreview
        }
    }

    private var mobileChatPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if layout.isCompact {
                    VStack(spacing: 10) {
                        mobileChatPhoneCard
                        mobileChatHelpCard
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        mobileChatPhoneCard
                            .frame(maxWidth: 290)
                        mobileChatHelpCard
                    }
                }
            }
        }
    }

    private var mobileChatPhoneCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 8)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 60, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(chatObjectiveComplete ? Color.green : (chatStarted ? Color.yellow : Color.gray))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ploy (Secure)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(chatObjectiveComplete ? "Link stable" : (chatStarted ? "Handshake in progress" : "Offline"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.cyan)
                        Image(systemName: "wifi")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.12, green: 0.13, blue: 0.17))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(phoneMessages.indices, id: \.self) { index in
                                let message = phoneMessages[index]
                                let isUser = message.hasPrefix("You:")

                                HStack {
                                    if isUser { Spacer(minLength: 24) }

                                    VStack(alignment: .leading, spacing: 3) {
                                        if !isUser {
                                            Text("Ploy")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(Color(red: 0.32, green: 0.44, blue: 0.72))
                                        }
                                        Text(message.replacingOccurrences(of: "You: ", with: ""))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(isUser ? .white : Color.black.opacity(0.85))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        isUser
                                        ? Color(red: 0.93, green: 0.33, blue: 0.55)
                                        : Color(red: 0.94, green: 0.95, blue: 0.98),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isUser ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                                    )

                                    if !isUser { Spacer(minLength: 24) }
                                }
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.isCompact ? 150 : 175)
                    .background(Color(red: 0.90, green: 0.92, blue: 0.96))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Reply Options")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.top, 10)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chatQuickReplies, id: \.self) { option in
                                    Button {
                                        sendChatReply(option)
                                    } label: {
                                        HStack(spacing: 6) {
                                            if selectedChatOption == option {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                            Text(option)
                                                .font(.system(size: 10, weight: .semibold))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(selectedChatOption == option ? .white : .white.opacity(0.9))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            selectedChatOption == option
                                            ? Color.cyan.opacity(0.4)
                                            : Color.white.opacity(0.09),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    selectedChatOption == option ? Color.cyan.opacity(0.75) : Color.white.opacity(0.12),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }

                        HStack(spacing: 6) {
                            TextField("Type a custom reply...", text: $phoneDraft)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.12, green: 0.13, blue: 0.16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )

                            Button(action: {
                                selectedChatOption = nil
                                sendPhoneMessage()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color(red: 0.93, green: 0.33, blue: 0.55), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(phoneDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(phoneDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .background(Color(red: 0.10, green: 0.11, blue: 0.14))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var mobileChatHelpCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mobile Chat (Chapter 1)")
                .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                .foregroundColor(.white)

            Text("Looks like a phone chat now: solid screen, real message bubbles, quick-reply choices, and custom text input.")
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.75))

            VStack(alignment: .leading, spacing: 6) {
                Label("Tap a quick option to reply instantly", systemImage: "list.bullet.rectangle.portrait.fill")
                Label("Or type your own message", systemImage: "keyboard")
                Label("Complete 2 replies to finish the handshake", systemImage: "checkmark.shield.fill")
            }
            .font(.system(size: layout.captionFontSize))
            .foregroundColor(.white.opacity(0.84))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var promptWorkshopPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if layout.isCompact {
                VStack(spacing: 10) {
                    promptComputerChatCard
                    promptPlannerCard
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    promptComputerChatCard
                    promptPlannerCard
                }
            }
        }
    }

    private var promptComputerChatCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                }
                Spacer()
                Text("Computer Chat")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.12, green: 0.13, blue: 0.17))

            VStack(alignment: .leading, spacing: 8) {
                promptChatBubble(
                    speaker: "AI Friend",
                    text: "If you ask better, I can help better. Give me goal, context, and limits.",
                    isUser: false
                )
                promptChatBubble(
                    speaker: "You",
                    text: promptDraftTokens.isEmpty ? "..." : promptPreviewText,
                    isUser: true
                )
                promptChatBubble(
                    speaker: "AI Friend",
                    text: promptFeedback,
                    isUser: false,
                    compact: true
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.92, green: 0.94, blue: 0.97))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: layout.isCompact ? .infinity : 300, alignment: .leading)
    }

    private var promptPlannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prompt Planner (Tap to Build)")
                .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                .foregroundColor(.white)

            Text("Learn prompt writing by planning the request in parts: goal, context, format, and ethics. Tap chips to assemble a strong prompt.")
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.74))

            HStack(spacing: 8) {
                Text("AI Name")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                TextField("Name the AI", text: $promptAIName)
                    .textFieldStyle(.plain)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(promptCategories, id: \.self) { category in
                        Button {
                            selectedPromptCategory = category
                        } label: {
                            Text(category)
                                .font(.system(size: layout.captionFontSize, weight: .bold))
                                .foregroundColor(selectedPromptCategory == category ? .white : .white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedPromptCategory == category
                                    ? Color.pink.opacity(0.35)
                                    : Color.white.opacity(0.05),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(
                                        selectedPromptCategory == category ? Color.pink.opacity(0.7) : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.isCompact ? 130 : 150), spacing: 8)], spacing: 8) {
                ForEach(promptChips(for: selectedPromptCategory), id: \.self) { chip in
                    Button {
                        addPromptChip(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: layout.captionFontSize, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Prompt Draft")
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Text(promptPreviewText)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(promptDraftTokens.isEmpty ? .white.opacity(0.45) : .white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                promptChecklistRow("Goal included", isComplete: hasPromptGoal)
                promptChecklistRow("Context included", isComplete: hasPromptContext)
                promptChecklistRow("Output format included", isComplete: hasPromptFormat)
                promptChecklistRow("Ethical rule included", isComplete: hasPromptEthics)
                promptChecklistRow("AI name set", isComplete: !promptAIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 8) {
                Button("Undo") {
                    guard !promptDraftTokens.isEmpty else { return }
                    promptDraftTokens.removeLast()
                }
                .buttonStyle(.plain)
                .font(.system(size: layout.captionFontSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule())

                Button("Clear") {
                    promptDraftTokens.removeAll()
                    promptWorkshopPassed = false
                    promptFeedback = "Build a prompt with goal, context, output format, and an ethical rule."
                }
                .buttonStyle(.plain)
                .font(.system(size: layout.captionFontSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var hallucinationBiasPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageName = eventPayload.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: layout.isCompact ? 120 : 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                ForEach(Array(["Prediction", "Ground Truth", "Bias Source"].enumerated()), id: \.offset) { index, title in
                    let selected = selectedBiasCard == index
                    let reviewed = reviewedBiasCards.contains(index)
                    Button {
                        selectBiasCard(index)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(title)
                                    .font(.system(size: layout.captionFontSize, weight: .bold))
                                    .foregroundColor(.white)
                                if reviewed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: layout.captionFontSize))
                                        .foregroundColor(.mint)
                                }
                            }
                            Text(biasCardValue(index))
                                .font(.system(size: layout.captionFontSize))
                                .foregroundColor(.white.opacity(0.74))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(selected ? 0.12 : 0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selected ? Color.purple.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(layout.dialogMaxWidth - 32, 120) * biasPressure, height: 10)
            }
            Text("Bias pressure: \(Int(biasPressure * 100))%")
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.68))
        }
    }

    private var memoryTrainingPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Replay Queue")
                        .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(0..<4, id: \.self) { row in
                        HStack {
                            Circle()
                                .fill(memoryRowDotColor(row))
                                .frame(width: 6, height: 6)
                            Text("Memory sample #\(row + 1)")
                                .font(.system(size: layout.captionFontSize))
                                .foregroundColor(.white.opacity(0.75))
                            Spacer()
                            Text(memoryRowStatus(row))
                                .font(.system(size: layout.captionFontSize - 1, weight: .bold))
                                .foregroundColor(memoryRowStatusColor(row))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Trainer")
                        .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                        .foregroundColor(.white)
                    Text("Progress")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.65))
                    ProgressView(value: memoryProgress)
                        .tint(.cyan)
                    Text("\(Int(memoryProgress * 100))% • Epoch \(max(memoryEpoch, 0))/3")
                        .font(.system(size: layout.captionFontSize, weight: .bold))
                        .foregroundColor(.cyan)
                    Button("Train Batch") { runMemoryStep() }
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.22), in: Capsule())
                    .buttonStyle(.plain)
                    .disabled(memoryProgress >= 1.0)
                    .opacity(memoryProgress >= 1.0 ? 0.6 : 1.0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func triggerEventHook() {
        switch eventPayload.type {
        case .mobileChat:
            didTrigger = true
            if !chatStarted {
                chatStarted = true
                phoneMessages.append("Ploy: Handshake window is open. Send your first reply.")
            } else if !chatObjectiveComplete {
                phoneMessages.append("System: Link unstable. Send another short reply to stabilize.")
            }
        case .promptWorkshop:
            didTrigger = true
            evaluatePromptWorkshop()
        case .hallucinationBias:
            didTrigger = true
            applyBiasCorrection()
        case .memoryTraining:
            didTrigger = true
            runMemoryStep(increment: 0.18)
        }
    }

    private var actionCompleted: Bool {
        switch eventPayload.type {
        case .mobileChat:
            return chatObjectiveComplete
        case .promptWorkshop:
            return promptWorkshopPassed
        case .hallucinationBias:
            return biasResolved
        case .memoryTraining:
            return memoryProgress >= 1.0
        }
    }

    private var actionButtonLabel: String {
        switch eventPayload.type {
        case .mobileChat:
            if chatObjectiveComplete { return "Handshake Complete" }
            if !chatStarted { return eventPayload.ctaTitle }
            return "Nudge Link"
        case .promptWorkshop:
            return promptWorkshopPassed ? "Prompt Plan Ready" : eventPayload.ctaTitle
        case .hallucinationBias:
            if biasResolved { return "Correction Applied" }
            if reviewedBiasCards.count < 3 { return "Review Evidence" }
            return eventPayload.ctaTitle
        case .memoryTraining:
            return memoryProgress >= 1.0 ? "Training Complete" : eventPayload.ctaTitle
        }
    }

    private var actionButtonIcon: String {
        actionCompleted ? "checkmark.circle.fill" : "play.circle.fill"
    }

    private var actionAccent: Color {
        switch eventPayload.type {
        case .mobileChat: return .green
        case .promptWorkshop: return .pink
        case .hallucinationBias: return .purple
        case .memoryTraining: return .cyan
        }
    }

    private var statusText: String {
        switch eventPayload.type {
        case .mobileChat:
            if chatObjectiveComplete {
                return "Handshake complete. Secure chat link is stable and ready for the next scene."
            }
            if chatStarted {
                let replyCount = phoneMessages.filter { $0.hasPrefix("You:") }.count
                return "Chat active. Send replies to stabilize the link (\(replyCount)/2 sent)."
            }
            return "Tap the action button to open the secure chat session."
        case .promptWorkshop:
            if promptWorkshopPassed {
                return "Prompt plan is complete. You included goal, context, format, and an ethical rule."
            }
            return promptFeedback
        case .hallucinationBias:
            if biasResolved {
                return "Bias source isolated. Correction plan applied and pressure reduced."
            }
            if reviewedBiasCards.count < 3 {
                return "Inspect all evidence cards before applying a correction (\(reviewedBiasCards.count)/3)."
            }
            if selectedBiasCard != 2 {
                return "Select the Bias Source card, then apply correction."
            }
            return "Ready to apply correction to the biased prediction."
        case .memoryTraining:
            if memoryProgress >= 1.0 {
                return "Replay training complete. Queue processed and validation can begin."
            }
            if memoryStepCount > 0 {
                return "Training in progress. Run more steps to finish the replay queue."
            }
            return "Tap Run Training Step to begin replay-based corrective training."
        }
    }

    private var statusIcon: String {
        switch eventPayload.type {
        case .mobileChat:
            return chatObjectiveComplete ? "checkmark.shield.fill" : "message.fill"
        case .promptWorkshop:
            return promptWorkshopPassed ? "checkmark.seal.fill" : "text.badge.plus"
        case .hallucinationBias:
            return biasResolved ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        case .memoryTraining:
            return memoryProgress >= 1.0 ? "brain.head.profile" : "cpu.fill"
        }
    }

    private var statusColor: Color {
        switch eventPayload.type {
        case .mobileChat:
            return chatObjectiveComplete ? .green : .pink
        case .promptWorkshop:
            return promptWorkshopPassed ? .mint : .pink
        case .hallucinationBias:
            return biasResolved ? .mint : .orange
        case .memoryTraining:
            return memoryProgress >= 1.0 ? .mint : .cyan
        }
    }

    private func sendPhoneMessage() {
        let trimmed = phoneDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        didTrigger = true

        if !chatStarted {
            chatStarted = true
            phoneMessages.append("Ploy: Handshake window is open. Send your first reply.")
        }

        phoneMessages.append("You: \(trimmed)")
        phoneDraft = ""

        let userReplyCount = phoneMessages.filter { $0.hasPrefix("You:") }.count
        switch userReplyCount {
        case 1:
            phoneMessages.append("Ploy: Good. Keep it short. One more reply to confirm signal stability.")
        case 2:
            phoneMessages.append("Ploy: Link stabilized. Identity confirmed. Proceeding to visual test.")
            chatObjectiveComplete = true
        default:
            phoneMessages.append("System: Secure channel remains stable.")
        }
    }

    private var chatQuickReplies: [String] {
        [
            "I'm here.",
            "Signal received.",
            "Who is this?",
            "Channel looks unstable."
        ]
    }

    private func sendChatReply(_ option: String) {
        selectedChatOption = option
        phoneDraft = option
        sendPhoneMessage()
    }

    private var promptCategories: [String] {
        ["Goal", "Context", "Format", "Ethics"]
    }

    private func promptChips(for category: String) -> [String] {
        switch category {
        case "Goal":
            return [
                "Explain AI ethics",
                "Teach prompt writing",
                "Compare good vs bad prompts",
                "Give a beginner example"
            ]
        case "Context":
            return [
                "for a high school student",
                "using simple English",
                "in a classroom setting",
                "with one real-life example"
            ]
        case "Format":
            return [
                "step-by-step",
                "bullet points",
                "short summary at the end",
                "include one practice exercise"
            ]
        default:
            return [
                "be respectful",
                "do not pretend to be human",
                "protect privacy",
                "encourage ethical use"
            ]
        }
    }

    private func addPromptChip(_ chip: String) {
        guard !promptDraftTokens.contains(chip) else { return }
        promptDraftTokens.append(chip)
        promptWorkshopPassed = false
        promptFeedback = "Good. Keep building the prompt plan before checking it."
    }

    private var promptPreviewText: String {
        if promptDraftTokens.isEmpty {
            return "Tap prompt chips to build your prompt..."
        }

        let aiName = promptAIName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = aiName.isEmpty ? "AI assistant," : "\(aiName),"
        return ([prefix] + promptDraftTokens).joined(separator: " ")
    }

    private var hasPromptGoal: Bool {
        promptDraftTokens.contains { promptChips(for: "Goal").contains($0) }
    }

    private var hasPromptContext: Bool {
        promptDraftTokens.contains { promptChips(for: "Context").contains($0) }
    }

    private var hasPromptFormat: Bool {
        promptDraftTokens.contains { promptChips(for: "Format").contains($0) }
    }

    private var hasPromptEthics: Bool {
        promptDraftTokens.contains { promptChips(for: "Ethics").contains($0) }
    }

    private func evaluatePromptWorkshop() {
        let hasName = !promptAIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let missing = [
            hasPromptGoal ? nil : "goal",
            hasPromptContext ? nil : "context",
            hasPromptFormat ? nil : "format",
            hasPromptEthics ? nil : "ethical rule",
            hasName ? nil : "AI name"
        ].compactMap { $0 }

        guard missing.isEmpty else {
            promptWorkshopPassed = false
            promptFeedback = "Missing: " + missing.joined(separator: ", ") + ". Add those parts and check again."
            return
        }

        promptWorkshopPassed = true
        promptFeedback = "Excellent prompt plan. It teaches clearly, sets context, defines output, and includes ethical boundaries."
    }

    @ViewBuilder
    private func promptChecklistRow(_ title: String, isComplete: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(isComplete ? .mint : .white.opacity(0.35))
            Text(title)
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(isComplete ? 0.9 : 0.65))
            Spacer()
        }
    }

    private func promptChatBubble(speaker: String, text: String, isUser: Bool, compact: Bool = false) -> some View {
        HStack {
            if isUser { Spacer(minLength: 20) }
            VStack(alignment: .leading, spacing: 2) {
                Text(speaker)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isUser ? .white.opacity(0.85) : Color(red: 0.30, green: 0.42, blue: 0.68))
                Text(text)
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundColor(isUser ? .white : Color.black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, compact ? 6 : 8)
            .background(
                isUser
                    ? Color(red: 0.27, green: 0.52, blue: 0.95)
                    : Color.white,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isUser ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
            )
            if !isUser { Spacer(minLength: 20) }
        }
    }

    private func selectBiasCard(_ index: Int) {
        selectedBiasCard = index
        reviewedBiasCards.insert(index)

        withAnimation(.easeInOut(duration: 0.2)) {
            if index == 2 {
                biasPressure = max(0.55, biasPressure - 0.05)
            }
        }
    }

    private func applyBiasCorrection() {
        guard reviewedBiasCards.count >= 3 else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            if selectedBiasCard == 2 {
                biasPressure = max(0.18, biasPressure - 0.34)
                biasResolved = true
            } else {
                biasPressure = min(0.92, biasPressure + 0.04)
            }
        }
    }

    private func runMemoryStep(increment: Double = 0.12) {
        guard memoryProgress < 1.0 else { return }

        didTrigger = true
        memoryStepCount += 1
        memoryEpoch = min(3, max(memoryEpoch, 1) + (memoryStepCount.isMultiple(of: 2) ? 1 : 0))

        withAnimation(.easeInOut(duration: 0.25)) {
            memoryProgress = min(1.0, memoryProgress + increment)
        }
    }

    private func memoryRowStatus(_ row: Int) -> String {
        let thresholds: [Double] = [0.28, 0.45, 0.68, 0.9]
        if memoryProgress >= thresholds[row] { return "trained" }
        if memoryProgress + 0.12 >= thresholds[row] { return "loading" }
        return "queued"
    }

    private func memoryRowStatusColor(_ row: Int) -> Color {
        switch memoryRowStatus(row) {
        case "trained": return .mint
        case "loading": return .cyan
        default: return .white.opacity(0.45)
        }
    }

    private func memoryRowDotColor(_ row: Int) -> Color {
        switch memoryRowStatus(row) {
        case "trained": return .mint
        case "loading": return .cyan
        default: return .white.opacity(0.3)
        }
    }

    private func biasCardValue(_ index: Int) -> String {
        switch index {
        case 0:
            return biasResolved ? "University Gate (corrected)" : "Ancient Temple (92%)"
        case 1:
            return "University Gate"
        default:
            return biasResolved ? "Dataset rebalance queued" : "Temple-heavy labels"
        }
    }
}



// MARK: - Preview
#Preview {
    ResponsiveDialogView(
        nodes: [
            DialogNode(
                speaker: "Ploy",
                text: "Welcome to the new responsive dialog system! This works on all devices including iPhone, iPad, and Mac.",
                emotion: .happy,
                choices: nil,
                requiresInput: false,
                inputPlaceholder: nil,
                backgroundImage: nil,
                characterImage: "char",
                onComplete: nil
            ),
            DialogNode(
                speaker: "Ploy",
                text: "How does this look on your device? The layout automatically adapts to your screen size!",
                emotion: .curious,
                choices: [
                    DialogChoice(text: "It looks great!", emotion: .happy, response: "", nextNodeIndex: nil, icon: "hand.thumbsup.fill"),
                    DialogChoice(text: "Pretty good", emotion: .neutral, response: "", nextNodeIndex: nil, icon: "checkmark.circle.fill"),
                    DialogChoice(text: "Could be better", emotion: .sad, response: "", nextNodeIndex: nil, icon: "exclamationmark.triangle.fill")
                ],
                requiresInput: false,
                inputPlaceholder: nil,
                backgroundImage: nil,
                characterImage: "char",
                onComplete: nil
            )
        ]
    )
    .preferredColorScheme(.dark)
}
