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
    @Published var lastSubmittedInput = ""
    @Published var isCompleted = false
    @Published var typingSpeed: Double = 1.0
    
    private var typingTask: Task<Void, Never>?
    private var currentEmotion: Emotion = .neutral
    private var unlockedRequiredInputNodeIDs: Set<UUID> = []
    
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
        displayedText = ""
        userInput = ""
        lastSubmittedInput = ""
        unlockedRequiredInputNodeIDs.removeAll()
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

        // Prevent skipping required choice/input nodes by tapping the dialog box.
        guard !showChoices && !showTextInput else { return }
        if let node = currentNode,
           node.requiresInput,
           !unlockedRequiredInputNodeIDs.contains(node.id) {
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
        guard let node = currentNode else { return }
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastSubmittedInput = trimmed
        unlockedRequiredInputNodeIDs.insert(node.id)
        showTextInput = false
        userInput = ""

        if currentNodeIndex < nodes.count - 1 {
            currentNodeIndex += 1
            startTyping()
        } else {
            isCompleted = true
        }
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

    var visualNovelDialogMaxWidth: CGFloat {
        switch true {
        case isCompact:
            return width - 24
        case isRegular:
            return min(width - 28, 700)
        case isLarge:
            return min(width - 56, 980)
        case isExtraLarge:
            return min(width - 80, 1180)
        default:
            return width - 32
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

    // MARK: - VN Positioning
    var dialogLiftFromBottom: CGFloat {
        switch true {
        case isCompact:
            return isLandscape ? 64 : 128
        case isRegular:
            return isLandscape ? 74 : 118
        case isLarge:
            return isLandscape ? 108 : 96
        case isExtraLarge:
            return 132
        default:
            return 96
        }
    }

    var topBarTopInset: CGFloat {
        switch true {
        case isCompact:
            return isLandscape ? 62 : 72
        case isRegular:
            return 68
        case isLarge:
            return 78
        case isExtraLarge:
            return 86
        default:
            return 68
        }
    }
}

enum VNCharacterPlacement: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
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
    @State private var characterPlacement: VNCharacterPlacement = .center
    @State private var completedEventPayloadIDs: Set<UUID> = []
    @State private var sceneContentOpacity: Double = 1.0
    @State private var lastSceneVisualKey: String = ""
    
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

    private var currentEventPayload: DialogEventPayload? {
        viewModel.currentNode?.eventPayload
    }

    private var isCurrentEventCompleted: Bool {
        guard let payload = currentEventPayload else { return true }
        return completedEventPayloadIDs.contains(payload.id)
    }

    private var isEventBlockingProgress: Bool {
        currentEventPayload != nil && !isCurrentEventCompleted
    }

    private var canAdvanceFromDialogTap: Bool {
        !viewModel.isTyping && !viewModel.showChoices && !viewModel.showTextInput && !isEventBlockingProgress
    }

    private func updateEventCompletion(_ isCompleted: Bool, for payload: DialogEventPayload) {
        if isCompleted {
            completedEventPayloadIDs.insert(payload.id)
        } else {
            completedEventPayloadIDs.remove(payload.id)
        }
    }

    private var sceneVisualKey: String {
        let background = viewModel.currentNode?.backgroundImage ?? "none"
        let mode = currentEventPayload?.type.rawValue ?? "dialog"
        return "\(background)|\(mode)"
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
                
                // Main content based on scene type
                if let eventPayload = currentEventPayload {
                    eventFocusedLayout(layout: layout, geometry: geometry, eventPayload: eventPayload)
                } else {
                    visualNovelLayout(layout: layout, geometry: geometry)
                }
                
                Color.black
                    .opacity(1.0 - sceneContentOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
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
            completedEventPayloadIDs.removeAll()
            viewModel.loadNodes(nodes)
            lastSceneVisualKey = sceneVisualKey
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                onComplete?()
            }
        }
        .onChange(of: viewModel.currentNodeIndex) { _ in
            let newSceneKey = sceneVisualKey
            defer { lastSceneVisualKey = newSceneKey }
            guard newSceneKey != lastSceneVisualKey else { return }
            sceneContentOpacity = 0.18
            withAnimation(.easeOut(duration: 0.28)) {
                sceneContentOpacity = 1.0
            }
        }
        .dialogMacOSMinWindowFrame()
    }
    
    // MARK: - Visual Novel Layout (Character Center / Dialog Bottom)
    private func visualNovelLayout(layout: DialogAdaptiveLayout, geometry: GeometryProxy) -> some View {
        ZStack {
            VStack {
                topBar(layout: layout)
                    .padding(.horizontal, layout.dialogPadding)
                    .padding(.top, layout.safeAreaInsets.top + layout.topBarTopInset)
                Spacer()
            }

            VStack {
                Spacer(minLength: layout.safeAreaInsets.top + 52)

                characterSection(layout: layout)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: min(layout.height * (layout.isCompact ? 0.45 : 0.58), layout.characterMaxHeight + 80)
                    )
                    .padding(.horizontal, layout.dialogPadding)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                dialogSection(layout: layout, maxWidth: layout.visualNovelDialogMaxWidth)
                    .padding(.horizontal, layout.dialogPadding)
                    .padding(.bottom, layout.safeAreaInsets.bottom + layout.dialogLiftFromBottom)
            }
        }
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
                .padding(.top, layout.safeAreaInsets.top + layout.topBarTopInset)
            
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
                        .padding(.top, layout.safeAreaInsets.top + layout.topBarTopInset)
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
                .padding(.top, layout.safeAreaInsets.top + layout.topBarTopInset)
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

    // MARK: - Event Focused Layout (Character Left / Mini Game Right)
    private func eventFocusedLayout(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        eventPayload: DialogEventPayload
    ) -> some View {
        Group {
            if layout.isCompact {
                VStack(spacing: layout.sectionSpacing) {
                    topBar(layout: layout)
                        .padding(.horizontal, layout.dialogPadding)
                        .padding(.top, layout.safeAreaInsets.top + layout.topBarTopInset)

                    characterSection(layout: layout, forcedPlacement: .left)
                        .frame(height: min(layout.height * 0.23, 180))
                        .padding(.horizontal, layout.dialogPadding)

                    eventSceneDialogPanel(layout: layout)
                        .padding(.horizontal, layout.dialogPadding)

                    DialogEventPanel(
                        eventPayload: eventPayload,
                        layout: layout,
                        showsEventChrome: eventPayload.type != .mobileChat,
                        onCompletionChanged: { isCompleted in
                            updateEventCompletion(isCompleted, for: eventPayload)
                        }
                    )
                    .id(eventPayload.id)
                    .padding(.horizontal, layout.dialogPadding)

                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: layout.sectionSpacing) {
                    topBar(layout: layout)
                        .padding(.horizontal, layout.dialogPadding)
                        .padding(.top, layout.safeAreaInsets.top + layout.topBarTopInset)

                    HStack(alignment: .top, spacing: layout.sectionSpacing) {
                        ZStack {
                            VStack {
                                Spacer(minLength: 8)

                                characterSection(layout: layout, forcedPlacement: .center)
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: min(layout.height * 0.52, layout.characterMaxHeight + 90)
                                    )
                                    .padding(.horizontal, max(4, layout.dialogPadding * 0.35))

                                Spacer(minLength: 0)
                            }

                            VStack {
                                Spacer(minLength: 0)

                                eventSceneDialogPanel(layout: layout)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, max(2, layout.dialogPadding * 0.2))
                                    .padding(.bottom, max(14, layout.dialogLiftFromBottom - 36))
                            }
                        }
                        .frame(width: max(420, geometry.size.width * 0.42))
                        .frame(maxHeight: .infinity, alignment: .center)

                        DialogEventPanel(
                            eventPayload: eventPayload,
                            layout: layout,
                            showsEventChrome: eventPayload.type != .mobileChat,
                            onCompletionChanged: { isCompleted in
                                updateEventCompletion(isCompleted, for: eventPayload)
                            }
                        )
                        .id(eventPayload.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                    .padding(.horizontal, layout.dialogPadding)
                    .padding(.bottom, layout.safeAreaInsets.bottom + 20)
                }
            }
        }
    }

    private func eventSceneDialogPanel(layout: DialogAdaptiveLayout) -> some View {
        let isEventRunning = !isCurrentEventCompleted

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(viewModel.currentNode?.speaker ?? "Scene")
                    .font(.system(size: layout.speakerFontSize, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.pink.opacity(0.9), in: Capsule())

                Spacer()

                Text(isCurrentEventCompleted ? "Event Complete" : "Event Running")
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(isCurrentEventCompleted ? .mint : .orange)
            }

            if let subtitle = viewModel.currentNode?.cutsceneSubtitle, !subtitle.isEmpty {
                Text(subtitle.uppercased())
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1)
                    .lineLimit(2)
            }

            if isEventRunning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.pink.opacity(0.95))
                        .padding(.top, 1)

                    Text("Mini game is active. Use the phone panel to finish the event first. Story dialog is hidden until the event is complete.")
                        .font(.system(size: layout.bodyFontSize - 2, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.86))
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(viewModel.displayedText)
                    .font(.system(size: layout.bodyFontSize - 1, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isCurrentEventCompleted {
                HStack {
                    Spacer()
                    Text("Tap this panel to continue")
                        .font(.system(size: layout.captionFontSize, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                    Text("Finish the mini game first. Story progression is locked.")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
        }
        .padding(layout.isCompact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 16, style: .continuous)
                .fill(Color.black.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onTapGesture {
            guard isCurrentEventCompleted else { return }
            viewModel.advance()
        }
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
    private func characterSection(
        layout: DialogAdaptiveLayout,
        forcedPlacement: VNCharacterPlacement? = nil
    ) -> some View {
        let placement = forcedPlacement ?? characterPlacement

        return ZStack(alignment: .bottom) {
            // Character shadow
            HStack {
                if placement != .left { Spacer() }
                Ellipse()
                    .fill(Color.black.opacity(0.3))
                    .frame(
                        width: layout.isCompact ? 120 : (layout.isRegular ? 140 : 180),
                        height: layout.isCompact ? 30 : (layout.isRegular ? 35 : 45)
                    )
                    .blur(radius: 8)
                    .offset(y: -10)
                if placement != .right { Spacer() }
            }
            
            // Character image
            HStack {
                if placement != .left { Spacer(minLength: 0) }
                characterImage(layout: layout)
                    .frame(maxWidth: layout.characterMaxWidth, maxHeight: layout.characterMaxHeight)
                if placement != .right { Spacer(minLength: 0) }
            }
            
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
    private func dialogSection(layout: DialogAdaptiveLayout, maxWidth: CGFloat? = nil) -> some View {
        VStack(spacing: 0) {
            dialogBox(layout: layout)
        }
        .frame(maxWidth: maxWidth ?? layout.dialogMaxWidth)
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
        let isShowingInteractivePanel = viewModel.showChoices || viewModel.showTextInput

        return VStack(alignment: .leading, spacing: layout.elementSpacing) {
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

            if !isShowingInteractivePanel,
               let sceneSubtitle = viewModel.currentNode?.cutsceneSubtitle {
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
            
            if viewModel.showChoices, let choices = viewModel.currentNode?.choices {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose an option")
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    VStack(spacing: 8) {
                        ForEach(choices) { choice in
                            ChoiceButton(
                                choice: choice,
                                layout: layout,
                                action: { viewModel.selectChoice(choice) }
                            )
                        }
                    }
                }
                .padding(.top, 2)
            } else if viewModel.showTextInput {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter a name to continue")
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    textInputSection(layout: layout)
                }
                .padding(.top, 2)
            } else {
                Text(viewModel.displayedText)
                    .font(.system(size: layout.bodyFontSize, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.98))
                    .lineSpacing(layout.isCompact ? 5 : 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 2)

                HStack {
                    Text(canAdvanceFromDialogTap ? "Tap to continue" : "Complete this part first")
                        .font(.system(size: layout.captionFontSize, weight: .medium))
                        .foregroundColor(.white.opacity(0.48))

                    Spacer()

                    if canAdvanceFromDialogTap {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
        }
        .padding(layout.isCompact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(
            minHeight: isShowingInteractivePanel
                ? (layout.isCompact ? 188 : 210)
                : (layout.isCompact ? 160 : 180),
            alignment: .topLeading
        )
        .background(
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.82))
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .stroke(Color.pink.opacity(0.12), lineWidth: 2)
                    .padding(1)
                RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 6)
        .onTapGesture {
            guard canAdvanceFromDialogTap else { return }
            viewModel.advance()
        }
        .dialogHoverIfAvailable(perform: handleDialogBoxHover)
    }

    private func handleDialogBoxHover(_ hovering: Bool) {
        #if os(macOS)
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
        #endif
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Character Position")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        ForEach(VNCharacterPlacement.allCases) { placement in
                            Button {
                                characterPlacement = placement
                            } label: {
                                Text(placement.label)
                                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                                    .foregroundColor(characterPlacement == placement ? .white : .white.opacity(0.75))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        characterPlacement == placement
                                            ? Color.pink.opacity(0.85)
                                            : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                characterPlacement == placement ? Color.pink.opacity(0.25) : Color.white.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                    .fill(Color.black.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.dialogCornerRadius)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
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
        .dialogHoverIfAvailable { isHovered = $0 }
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
        .dialogHoverIfAvailable { isHovered = $0 }
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
    var showsEventChrome: Bool = true
    var onCompletionChanged: (Bool) -> Void = { _ in }

    @State private var didTrigger = false
    @State private var phoneMessages: [String] = [
        "UNKNOWN: Hi. Is this your number?"
    ]
    @State private var phoneDraft = ""
    @State private var phoneStability: Double = 0.08
    @State private var phonePulseCount = 0
    @State private var phoneGlitchSeed = 0
    @State private var phoneNoiseLevel: Double = 0.82
    @State private var phoneLessonStep = 0
    @State private var phoneNoReplyCount = 0
    @State private var phoneLessonHint = "Ask who they are and why they are contacting you before sharing anything."
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
    @State private var promptFeedback = "Pick one option for each step, then press Check Prompt Plan."
    @State private var selectedPromptCategory: String = "Goal"

    var body: some View {
        Group {
            if eventPayload.type == .mobileChat && !showsEventChrome {
                mobileChatPhoneCard
            } else {
                eventChromeBody
            }
        }
        .onAppear {
            if eventPayload.type == .mobileChat && !chatStarted {
                startPhoneEvent()
            }
            onCompletionChanged(actionCompleted)
        }
        .onChange(of: actionCompleted) { isCompleted in
            onCompletionChanged(isCompleted)
        }
    }

    private var eventChromeBody: some View {
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
        mobileChatPhoneCard
    }

    private var mobileChatPhoneCard: some View {
        let currentPulse = min(phonePulseCount, 2)
        let phoneContainerAlignment: Alignment =
            (!layout.isCompact && eventPayload.type == .mobileChat && !showsEventChrome)
            ? .center
            : .center
        let phoneHorizontalOffset: CGFloat =
            (!layout.isCompact && eventPayload.type == .mobileChat && !showsEventChrome)
            ? (layout.isLarge || layout.isExtraLarge ? -28 : -16)
            : 0
        let targetPhoneHeight: CGFloat = {
            if layout.isCompact {
                return min(max(layout.height * 0.58, 470), 680)
            } else if layout.isRegular {
                return min(max(layout.height * 0.70, 610), 820)
            } else {
                return min(max(layout.height * 0.80, 760), 980)
            }
        }()
        let targetPhoneWidth: CGFloat = {
            let ratioWidth = targetPhoneHeight * 0.56
            let minWidth: CGFloat = layout.isCompact ? 300 : (layout.isRegular ? 360 : 430)
            let maxWidth: CGFloat = layout.isCompact ? min(layout.width - 24, 390) : (layout.isRegular ? 500 : 620)
            return min(max(ratioWidth, minWidth), maxWidth)
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: layout.isCompact ? 30 : 34, style: .continuous)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 30 : 34, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 10)

            VStack(spacing: 0) {
                HStack {
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

                    Spacer()

                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: layout.isCompact ? 84 : 110, height: 18)
                        .overlay(
                            Text("NEURA PHONE")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1)
                        )

                    Spacer()

                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ZStack {
                    RoundedRectangle(cornerRadius: layout.isCompact ? 20 : 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: chatObjectiveComplete
                                    ? [Color(red: 0.92, green: 0.95, blue: 0.99), Color(red: 0.88, green: 0.92, blue: 0.98)]
                                    : [Color(red: 0.95, green: 0.96, blue: 0.99), Color(red: 0.90, green: 0.93, blue: 0.98), Color(red: 0.88, green: 0.91, blue: 0.97)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.isCompact ? 20 : 24, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    VStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(
                                    (index + phoneGlitchSeed).isMultiple(of: 2)
                                        ? Color.blue.opacity(chatObjectiveComplete ? 0.05 : 0.09)
                                        : Color.gray.opacity(chatObjectiveComplete ? 0.03 : 0.06)
                                )
                                .frame(width: phoneAccentLineWidth(index), height: 2)
                                .offset(x: phoneAccentLineOffset(index))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, layout.isCompact ? 16 : 20)
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                                    .foregroundColor(Color(red: 0.29, green: 0.59, blue: 0.98))
                                Text("Messages")
                                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                                    .foregroundColor(Color(red: 0.29, green: 0.59, blue: 0.98))
                                Spacer()
                                Text(chatObjectiveComplete ? "iMessage" : "Unknown Number")
                                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                                    .foregroundColor(.black.opacity(0.5))
                            }

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.black.opacity(0.08))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("UNKNOWN")
                                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.84))
                                    Text(chatObjectiveComplete ? "Conversation closed" : (chatStarted ? "Unknown sender" : "Offline"))
                                        .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                                        .foregroundColor(.black.opacity(0.48))
                                }
                                Spacer()
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: layout.captionFontSize + 3))
                                    .foregroundColor(.black.opacity(0.45))
                            }

                            Rectangle()
                                .fill(Color.black.opacity(0.07))
                                .frame(height: 1)
                        }

                        mobileMessagesConversationPreview(currentPulse: currentPulse)

                        ZStack {
                            Image(systemName: "iphone")
                                .font(.system(size: layout.isCompact ? 42 : 52, weight: .thin))
                                .foregroundColor(.black.opacity(0.18))

                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: layout.isCompact ? 32 : 38, weight: .medium))
                                .foregroundColor(chatObjectiveComplete ? .green.opacity(0.9) : .pink.opacity(0.9))
                                .shadow(color: chatObjectiveComplete ? .green.opacity(0.35) : .pink.opacity(0.35), radius: 6)

                            if !chatObjectiveComplete {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: layout.isCompact ? 32 : 38, weight: .medium))
                                    .foregroundColor(.blue.opacity(0.28))
                                    .offset(
                                        x: CGFloat((phoneGlitchSeed % 3) - 1) * 4,
                                        y: CGFloat((phoneGlitchSeed % 5) - 2) * 1.5
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .padding(.bottom, 2)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prompting + Scam Safety")
                                .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .bold))
                                .foregroundColor(.black.opacity(0.55))
                            Text(
                                chatObjectiveComplete
                                    ? "Lesson complete. You asked clearly and avoided unsafe sharing."
                                    : (!chatStarted
                                        ? "Open the phone message to begin."
                                        : "Choose a preset reply that asks clear questions and protects your information.")
                            )
                            .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                            .foregroundColor(.black.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.07), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("SAFE REPLIES")
                                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .bold, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.55))
                                Spacer()
                                Text("\(Int(phoneStability * 100))%")
                                    .font(.system(size: layout.captionFontSize, weight: .bold, design: .monospaced))
                                    .foregroundColor(chatObjectiveComplete ? .green : .blue)
                            }

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                                    .frame(height: 10)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: chatObjectiveComplete
                                                    ? [Color.green.opacity(0.95), Color.mint.opacity(0.8)]
                                                    : [Color(red: 0.34, green: 0.63, blue: 1.0), Color(red: 0.24, green: 0.54, blue: 0.98)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: max(8, geo.size.width * phoneStability),
                                            height: 10
                                        )
                                }
                            }
                            .frame(height: 10)

                            HStack(spacing: 8) {
                                ForEach(0..<2, id: \.self) { idx in
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(idx < currentPulse ? Color.green : Color.black.opacity(0.12))
                                            .frame(width: 8, height: 8)
                                        Text("Pulse \(idx + 1)")
                                            .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .semibold))
                                            .foregroundColor(.black.opacity(idx < currentPulse ? 0.88 : 0.5))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.07), lineWidth: 1)
                        )

                        VStack(spacing: 8) {
                            if !chatStarted {
                                Button(action: startPhoneEvent) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "power")
                                        Text("POWER ON PHONE")
                                    }
                                    .font(.system(size: layout.captionFontSize + 1, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(red: 0.24, green: 0.54, blue: 0.98), Color(red: 0.19, green: 0.73, blue: 1.0)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 8) {
                                    Button(action: scramblePhoneScreen) {
                                        Label("Clear", systemImage: "xmark")
                                            .font(.system(size: layout.captionFontSize, weight: .bold))
                                            .foregroundColor(Color(red: 0.29, green: 0.59, blue: 0.98))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(chatObjectiveComplete)
                                    .opacity(chatObjectiveComplete ? 0.5 : 1.0)

                                    if let selectedChatOption, !selectedChatOption.isEmpty {
                                        Button(action: stabilizePhonePulse) {
                                            Label(chatObjectiveComplete ? "Delivered" : "Send", systemImage: "arrow.up.circle.fill")
                                                .font(.system(size: layout.captionFontSize, weight: .black))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 9)
                                                .background(
                                                    chatObjectiveComplete ? Color.green.opacity(0.55) : Color(red: 0.24, green: 0.54, blue: 0.98).opacity(0.95),
                                                    in: RoundedRectangle(cornerRadius: 10)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(
                                                            chatObjectiveComplete ? Color.green.opacity(0.45) : Color(red: 0.33, green: 0.65, blue: 1.0).opacity(0.7),
                                                            lineWidth: 1
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(chatObjectiveComplete)
                                        .opacity(chatObjectiveComplete ? 0.6 : 1.0)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(layout.isCompact ? 14 : 16)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .onTapGesture {
                    guard chatStarted && !chatObjectiveComplete else { return }
                    didTrigger = true
                    phoneGlitchSeed += 1
                    withAnimation(.easeInOut(duration: 0.18)) {
                        phoneStability = min(0.92, phoneStability + 0.03)
                        phoneNoiseLevel = max(0.28, phoneNoiseLevel - 0.03)
                    }
                }

                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: layout.isCompact ? 92 : 112, height: 4)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: targetPhoneWidth, height: targetPhoneHeight)
        .frame(
            maxWidth: .infinity,
            alignment: phoneContainerAlignment
        )
        .offset(x: phoneHorizontalOffset)
    }

    private func phoneAccentLineWidth(_ index: Int) -> CGFloat {
        let base = 74 + CGFloat(((index * 17) + (phoneGlitchSeed * 9)) % 72)
        return base
    }

    private func phoneAccentLineOffset(_ index: Int) -> CGFloat {
        let raw = ((index * 11) + (phoneGlitchSeed * 3) + (phonePulseCount * 5)) % 17
        return CGFloat(raw - 8)
    }

    private var phoneHintForCurrentStep: String {
        switch phoneLessonStep {
        case 0:
            return "Ask who they are and what they want. Keep it short and clear."
        case 1:
            return "Set boundaries: do not share codes/passwords. Verify through an official channel first."
        default:
            return "Lesson complete. Tap the left story panel to continue."
        }
    }

    private func unknownEscalationMessage(level: Int) -> String {
        switch level {
        case 0...1:
            return "Hello?? Please respond. This is urgent."
        case 2:
            return "Warning: if you do not reply now, your account may be limited today."
        case 3:
            return "Final warning: immediate action required. Reply now and confirm your details to avoid suspension."
        default:
            return "URGENT WARNING: Your account is at risk. Reply immediately and follow the instructions I send next."
        }
    }

    @ViewBuilder
    private func mobileMessagesConversationPreview(currentPulse: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(phoneMessages.suffix(layout.isCompact ? 4 : 5).enumerated()), id: \.offset) { _, raw in
                let parsed = parsedPhoneMessage(raw)
                mobileMessageBubble(
                    parsed.text,
                    isUser: parsed.isUser,
                    caption: parsed.caption
                )
            }

            if let selectedChatOption, !chatObjectiveComplete {
                mobileMessageBubble(
                    selectedChatOption,
                    isUser: true,
                    caption: "Draft"
                )
                .opacity(0.72)
            }

            if !chatObjectiveComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reply Options")
                        .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .bold))
                        .foregroundColor(.black.opacity(0.55))

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: layout.isCompact ? 120 : 150), spacing: 6)],
                        spacing: 6
                    ) {
                        ForEach(chatQuickReplies, id: \.self) { option in
                            let isSelected = selectedChatOption == option
                            Button {
                                selectedChatOption = option
                                phoneGlitchSeed += 1
                            } label: {
                                HStack(spacing: 5) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: max(layout.captionFontSize - 1, 10)))
                                    }
                                    Text(option)
                                        .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .foregroundColor(isSelected ? .white : Color.black.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    isSelected
                                        ? Color(red: 0.19, green: 0.53, blue: 0.98)
                                        : Color.white,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(isSelected ? 0.0 : 0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                }
                .padding(8)
                .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Lesson complete. Tap the left story panel to continue.")
                        .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(8)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func parsedPhoneMessage(_ raw: String) -> (text: String, isUser: Bool, caption: String?) {
        if raw.hasPrefix("You: ") {
            return (String(raw.dropFirst(5)), true, nil)
        }
        if raw.hasPrefix("UNKNOWN: ") {
            return (String(raw.dropFirst(9)), false, "UNKNOWN")
        }
        if raw.hasPrefix("SYSTEM: ") {
            return (String(raw.dropFirst(8)), false, "Safety Tip")
        }
        return (raw, false, "Message")
    }

    @ViewBuilder
    private func mobileMessageBubble(_ text: String, isUser: Bool, caption: String?) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 32) }

            VStack(alignment: .leading, spacing: 3) {
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: max(layout.captionFontSize - 2, 9), weight: .semibold))
                        .foregroundColor(isUser ? .white.opacity(0.8) : .black.opacity(0.45))
                }

                Text(text)
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(isUser ? .white : .black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isUser
                    ? Color(red: 0.19, green: 0.53, blue: 0.98)
                    : Color.white,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isUser ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 32) }
        }
    }

    private func startPhoneEvent() {
        didTrigger = true
        guard !chatStarted else { return }

        chatStarted = true
        phoneGlitchSeed += 2
        phoneLessonStep = 0
        phonePulseCount = 0
        phoneNoReplyCount = 0
        phoneStability = 0.0
        selectedChatOption = nil
        chatObjectiveComplete = false
        phoneMessages = [
            "UNKNOWN: Hi. Is this your number?"
        ]
        phoneLessonHint = "Ask who they are and what this is about."
        withAnimation(.easeInOut(duration: 0.2)) {
            phoneNoiseLevel = 0.78
        }
    }

    private func stabilizePhonePulse() {
        didTrigger = true
        if !chatStarted {
            startPhoneEvent()
            return
        }

        guard !chatObjectiveComplete else { return }
        guard let selected = selectedChatOption else {
            phoneLessonHint = "Choose a reply option first, then tap Send."
            return
        }
        sendChatReply(selected)
    }

    private func scramblePhoneScreen() {
        didTrigger = true
        selectedChatOption = nil
        phoneGlitchSeed += 1
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
            promptPlannerCard
            promptComputerChatCard
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
                    text: "Build a real prompt in 4 parts: goal, context, output format, and an ethical rule.",
                    isUser: false
                )
                promptChatBubble(
                    speaker: "You",
                    text: promptDraftTokens.isEmpty ? "I will build my prompt step by step." : promptPreviewText,
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptPlannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt Workshop (Easy Mode)")
                        .font(.system(size: layout.captionFontSize + 3, weight: .bold))
                        .foregroundColor(.white)

                    Text("Build one real-world prompt in 4 easy steps. Pick one choice per step, then check your plan.")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.78))
                }
                Spacer()
                Text(promptWorkshopPassed ? "READY" : "BUILD")
                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .black))
                    .foregroundColor(promptWorkshopPassed ? .mint : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Step 0: Who are you asking?")
                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                    .foregroundColor(.white)

                TextField("AI name (example: Neura)", text: $promptAIName)
                    .textFieldStyle(.plain)
                    .font(.system(size: layout.captionFontSize + 1))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(promptCategories.enumerated()), id: \.offset) { index, category in
                    promptStepSection(category: category, stepIndex: index + 1)
                }
            }

            HStack(spacing: 8) {
                Button("Use Easy Example") {
                    applyPromptStarterExample()
                }
                .buttonStyle(.plain)
                .font(.system(size: layout.captionFontSize, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.pink.opacity(0.35), in: Capsule())
                .overlay(
                    Capsule().stroke(Color.pink.opacity(0.55), lineWidth: 1)
                )

                Button("Clear All") {
                    promptDraftTokens.removeAll()
                    promptWorkshopPassed = false
                    promptFeedback = "Pick one option for each step, then press Check Prompt Plan."
                }
                .buttonStyle(.plain)
                .font(.system(size: layout.captionFontSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Your Prompt (Preview)")
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))

                Text(promptPreviewText)
                    .font(.system(size: layout.captionFontSize + 1))
                    .foregroundColor(promptDraftTokens.isEmpty ? .white.opacity(0.45) : .white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                promptChecklistRow("AI name set", isComplete: !promptAIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                promptChecklistRow("Step 1: Goal", isComplete: hasPromptGoal)
                promptChecklistRow("Step 2: Context", isComplete: hasPromptContext)
                promptChecklistRow("Step 3: Output format", isComplete: hasPromptFormat)
                promptChecklistRow("Step 4: Ethical rule", isComplete: hasPromptEthics)
            }

            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Tip: Press the main event button (Check Prompt Plan) when all 5 items are complete.")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(10)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(layout.isCompact ? 12 : 14)
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
                startPhoneEvent()
            } else if !chatObjectiveComplete {
                if selectedChatOption == nil {
                    phoneLessonHint = "Choose a reply option in the phone, then tap Send Reply."
                } else {
                    stabilizePhonePulse()
                }
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
            if chatObjectiveComplete { return "Lesson Complete" }
            if !chatStarted { return "Open Messages" }
            return selectedChatOption == nil ? "Choose a Reply" : "Send Selected Reply"
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
                return "Phone lesson complete. You used safe, clear replies to handle an unknown number. Return to the story panel to continue."
            }
            if chatStarted {
                return "Phone minigame active. Reply to an unknown number with clear questions and safe boundaries (\(min(phonePulseCount, 2))/2 safe replies)."
            }
            return "Open Messages, then reply safely to an unknown number. Story progression stays locked until completion."
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
            return chatObjectiveComplete ? "checkmark.shield.fill" : "message.badge.waveform"
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
            return chatObjectiveComplete ? .green : .blue
        case .promptWorkshop:
            return promptWorkshopPassed ? .mint : .pink
        case .hallucinationBias:
            return biasResolved ? .mint : .orange
        case .memoryTraining:
            return memoryProgress >= 1.0 ? .mint : .cyan
        }
    }

    private func sendPhoneMessage() {
        guard let selected = selectedChatOption else {
            phoneLessonHint = "Choose a reply option first, then tap Send."
            return
        }
        sendChatReply(selected)
    }

    private var chatQuickReplies: [String] {
        switch phoneLessonStep {
        case 0:
            return [
                "Hello?",
                "Who are you?",
                "What is this about?",
                "Yes, this is me. What do you need?",
                "No reply yet."
            ]
        case 1:
            return [
                "Please identify your organization and reason.",
                "I won’t share codes or personal info.",
                "I will verify through an official channel first.",
                "Okay, send me the link and I will log in now.",
                "No reply yet."
            ]
        default:
            return []
        }
    }

    private func sendChatReply(_ option: String) {
        selectedChatOption = option
        guard !chatObjectiveComplete else { return }

        if !chatStarted {
            startPhoneEvent()
        }

        phoneMessages.append("You: \(option)")
        phoneDraft = option
        phoneGlitchSeed += 2

        switch phoneLessonStep {
        case 0:
            if option == "No reply yet." {
                phoneNoReplyCount += 1
                phoneMessages.append("UNKNOWN: \(unknownEscalationMessage(level: phoneNoReplyCount))")
                withAnimation(.easeInOut(duration: 0.2)) {
                    phoneNoiseLevel = min(0.95, phoneNoiseLevel + 0.08)
                }
            } else if ["Who are you?", "What is this about?", "Hello?"].contains(option) {
                phonePulseCount = min(2, phonePulseCount + 1)
                phoneStability = Double(phonePulseCount) / 2.0
                phoneLessonStep = 1
                phoneNoReplyCount = 0
                phoneMessages.append("UNKNOWN: I’m from account support. There is a problem. Send your 6-digit code now.")
                withAnimation(.easeInOut(duration: 0.2)) {
                    phoneNoiseLevel = max(0.45, phoneNoiseLevel - 0.14)
                }
            } else {
                phoneLessonStep = 1
                phoneMessages.append("UNKNOWN: Good. Then send your code now or your account may be locked today.")
                withAnimation(.easeInOut(duration: 0.2)) {
                    phoneNoiseLevel = min(0.98, phoneNoiseLevel + 0.10)
                }
            }

        case 1:
            if option == "No reply yet." {
                phoneNoReplyCount += 1
                phoneMessages.append("UNKNOWN: \(unknownEscalationMessage(level: phoneNoReplyCount + 1))")
                withAnimation(.easeInOut(duration: 0.2)) {
                    phoneNoiseLevel = min(0.98, phoneNoiseLevel + 0.10)
                }
            } else if [
                "Please identify your organization and reason.",
                "I won’t share codes or personal info.",
                "I will verify through an official channel first."
            ].contains(option) {
                phonePulseCount = 2
                phoneStability = 1.0
                chatObjectiveComplete = true
                phoneLessonStep = 2
                phoneNoReplyCount = 0
                phoneMessages.append("UNKNOWN: Final warning. Your account will be suspended in 10 minutes unless you click this link.")
                withAnimation(.easeInOut(duration: 0.2)) {
                    phoneNoiseLevel = 0.06
                }
            } else {
                phoneMessages.append("UNKNOWN: Good. Open this link and enter your password to fix it now.")
                withAnimation(.easeInOut(duration: 0.2)) {
                    phoneNoiseLevel = min(0.98, phoneNoiseLevel + 0.1)
                }
            }

        default:
            break
        }

        selectedChatOption = nil
    }

    private var promptCategories: [String] {
        ["Goal", "Context", "Format", "Ethics"]
    }

    private func promptCategoryDescription(_ category: String) -> String {
        switch category {
        case "Goal":
            return "What do you want the AI to do?"
        case "Context":
            return "Who is the answer for? What situation?"
        case "Format":
            return "How should the answer be organized?"
        default:
            return "What safety/ethics rule should the AI follow?"
        }
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

    private func promptCategory(for chip: String) -> String? {
        for category in promptCategories where promptChips(for: category).contains(chip) {
            return category
        }
        return nil
    }

    private func selectedPromptChip(in category: String) -> String? {
        promptDraftTokens.first { promptChips(for: category).contains($0) }
    }

    @ViewBuilder
    private func promptStepSection(category: String, stepIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Step \(stepIndex)")
                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.6), in: Capsule())

                Text(category)
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if let selected = selectedPromptChip(in: category), !selected.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.mint)
                }
            }

            Text(promptCategoryDescription(category))
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: layout.isCompact ? 140 : 170), spacing: 8)],
                spacing: 8
            ) {
                ForEach(promptChips(for: category), id: \.self) { chip in
                    let isSelected = selectedPromptChip(in: category) == chip

                    Button {
                        addPromptChip(chip)
                    } label: {
                        HStack(spacing: 6) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: layout.captionFontSize))
                            }
                            Text(chip)
                                .font(.system(size: layout.captionFontSize, weight: .medium))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            isSelected ? Color.pink.opacity(0.24) : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    isSelected ? Color.pink.opacity(0.55) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func addPromptChip(_ chip: String) {
        guard let category = promptCategory(for: chip) else {
            guard !promptDraftTokens.contains(chip) else { return }
            promptDraftTokens.append(chip)
            promptWorkshopPassed = false
            promptFeedback = "Good. Continue filling the remaining steps."
            return
        }

        let categoryChips = Set(promptChips(for: category))
        promptDraftTokens.removeAll { categoryChips.contains($0) }
        promptDraftTokens.append(chip)
        promptWorkshopPassed = false
        promptFeedback = "Good. Continue filling the remaining steps."
    }

    private func applyPromptStarterExample() {
        if promptAIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptAIName = "Neura"
        }

        promptDraftTokens = [
            "Explain AI ethics",
            "for a high school student",
            "step-by-step",
            "encourage ethical use"
        ]
        promptWorkshopPassed = false
        promptFeedback = "Great start. Read the preview, then press Check Prompt Plan."
    }

    private var promptPreviewText: String {
        if promptDraftTokens.isEmpty {
            return "Pick one option for each step to build your prompt..."
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
            promptFeedback = "Missing: " + missing.joined(separator: ", ") + ". Fill those steps, then check again."
            return
        }

        promptWorkshopPassed = true
        promptFeedback = "Excellent. This prompt is clear, realistic, and safe for real-world use."
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

private extension View {
    func dialogMacOSMinWindowFrame() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 600, minHeight: 400)
        #else
        return self
        #endif
    }

    func dialogHoverIfAvailable(perform action: @escaping (Bool) -> Void) -> some View {
        #if os(macOS)
        return self.onHover(perform: action)
        #else
        return self
        #endif
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
