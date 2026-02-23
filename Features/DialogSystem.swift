import SwiftUI
import AVKit

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
    let inputVariableKey: String?
    let inputDefaultValue: String?
    let inlineActivity: DialogInlineActivity?
    
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
        inputVariableKey: String? = nil,
        inputDefaultValue: String? = nil,
        inlineActivity: DialogInlineActivity? = nil,
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
        self.inputVariableKey = inputVariableKey
        self.inputDefaultValue = inputDefaultValue
        self.inlineActivity = inlineActivity
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
    @Published private(set) var completedInlineActivityNodeIDs: Set<UUID> = []
    @Published private(set) var inlineActivityResultByNodeID: [UUID: String] = [:]
    @Published private(set) var storyVariables: [String: String] = ["ai_name": "Ploy"]
    
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
        completedInlineActivityNodeIDs.removeAll()
        inlineActivityResultByNodeID.removeAll()
        storyVariables = ["ai_name": "Ploy"]
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
        let chars = Array(renderTemplate(fullText))
        
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
                if node.requiresInput {
                    userInput = node.inputDefaultValue ?? ""
                }
            }
        }
    }
    
    func skipTyping() {
        typingTask?.cancel()
        guard let node = currentNode else { return }
        displayedText = renderTemplate(node.text)
        isTyping = false
        showChoices = node.choices != nil && !node.choices!.isEmpty
        showTextInput = node.requiresInput
        if node.requiresInput {
            userInput = node.inputDefaultValue ?? ""
        }
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
        if let node = currentNode,
           node.inlineActivity != nil,
           !completedInlineActivityNodeIDs.contains(node.id) {
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

        if !choice.response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayedText = renderTemplate(choice.response)
            isTyping = false
            showTextInput = false
            return
        }

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
        let finalInput = trimmed.isEmpty ? (node.inputDefaultValue ?? "") : trimmed
        guard !finalInput.isEmpty else { return }

        lastSubmittedInput = finalInput
        storyVariables["last_input"] = finalInput
        if let key = node.inputVariableKey, !key.isEmpty {
            storyVariables[key] = finalInput
        }
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

    func isInlineActivityCompleted(for nodeID: UUID) -> Bool {
        completedInlineActivityNodeIDs.contains(nodeID)
    }

    func inlineActivityResult(for nodeID: UUID) -> String? {
        inlineActivityResultByNodeID[nodeID]
    }

    func completeInlineActivity(for nodeID: UUID, result: String) {
        completedInlineActivityNodeIDs.insert(nodeID)
        inlineActivityResultByNodeID[nodeID] = result
    }

    func renderTemplate(_ template: String) -> String {
        guard !template.isEmpty else { return template }
        var rendered = template
        for (key, value) in storyVariables {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return rendered
    }

    func resolvedSpeaker(for node: DialogNode?) -> String {
        renderTemplate(node?.speaker ?? "")
    }

    func resolvedText(for node: DialogNode?) -> String {
        renderTemplate(node?.text ?? "")
    }

    func resolvedCutsceneTitle(for node: DialogNode?) -> String? {
        guard let value = node?.cutsceneTitle else { return nil }
        return renderTemplate(value)
    }

    func resolvedCutsceneSubtitle(for node: DialogNode?) -> String? {
        guard let value = node?.cutsceneSubtitle else { return nil }
        return renderTemplate(value)
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

    var shouldWrapTopBar: Bool {
        width < 520 || (isLandscape && height < 430)
    }

    var shouldUseIconOnlyTopBarControls: Bool {
        width < 700 || (isLandscape && height < 500)
    }

    var topBarReservedHeight: CGFloat {
        if shouldWrapTopBar {
            return isCompact ? 90 : 100
        }
        return isCompact ? 44 : 52
    }

    var topBarSafePadding: CGFloat {
        let fallbackSafeTop: CGFloat
        switch true {
        case isCompact && isLandscape:
            fallbackSafeTop = 8
        case isCompact:
            fallbackSafeTop = 50
        case isRegular:
            fallbackSafeTop = 20
        default:
            fallbackSafeTop = 24
        }

        let safeTop = safeAreaInsets.top > 0 ? safeAreaInsets.top : fallbackSafeTop
        return safeTop + topBarTopInset
    }

    var controlButtonMinTapSize: CGFloat {
        isCompact ? 36 : 42
    }

    var pausePanelMaxHeight: CGFloat {
        max(240, height - safeAreaInsets.top - safeAreaInsets.bottom - (isCompact ? 24 : 40))
    }

    var usesVerticalPauseActions: Bool {
        width < 380 || height < 520
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
            return isLandscape ? 6 : 8
        case isRegular:
            return 10
        case isLarge:
            return 12
        case isExtraLarge:
            return 14
        default:
            return 10
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
    let chapterTopBarDropFactor: CGFloat
    let onComplete: (() -> Void)?
    
    // Animation states
    @State private var characterScale: CGFloat = 1.0
    @State private var characterOffset: CGFloat = 0
    @State private var characterRotation: Double = 0
    @State private var isCharacterPressed = false
    @State private var showSettingsPanel = false
    @State private var backgroundOpacity: Double = 1.0
    @State private var characterPlacement: VNCharacterPlacement = .center
    @State private var sceneContentOpacity: Double = 1.0
    @State private var lastSceneVisualKey: String = ""
    
    init(
        nodes: [DialogNode],
        showBackButton: Bool = true,
        showSettings: Bool = true,
        chapterTopBarDropFactor: CGFloat = 0,
        onComplete: (() -> Void)? = nil
    ) {
        self.nodes = nodes
        self.showBackButton = showBackButton
        self.showSettings = showSettings
        self.chapterTopBarDropFactor = chapterTopBarDropFactor
        self.onComplete = onComplete
    }

    private var splitShowcaseMedia: DialogShowcaseMedia? {
        guard let node = viewModel.currentNode,
              let showcase = node.showcaseMedia else {
            return nil
        }

        let usesLegacyClockSplit = showcase.imageName == "__clock_placeholder__"
        guard showcase.prefersSplitLayout || usesLegacyClockSplit else { return nil }
        return showcase
    }

    private var canAdvanceFromDialogTap: Bool {
        guard let node = viewModel.currentNode else { return false }
        let inlineReady = node.inlineActivity == nil || viewModel.isInlineActivityCompleted(for: node.id)
        return !viewModel.isTyping && !viewModel.showChoices && !viewModel.showTextInput && inlineReady
    }

    private var sceneVisualKey: String {
        viewModel.currentNode?.backgroundImage ?? "none"
    }

    private func chapterTopBarExtraDrop(for layout: DialogAdaptiveLayout) -> CGFloat {
        let clampedFactor = min(max(chapterTopBarDropFactor, 0), 2)
        return layout.topBarReservedHeight * clampedFactor
    }

    private func topBarTopPadding(for layout: DialogAdaptiveLayout) -> CGFloat {
        layout.topBarSafePadding + chapterTopBarExtraDrop(for: layout)
    }
    
    var body: some View {
        GeometryReader { geometry in
            dialogScene(geometry: geometry)
        }
        .onAppear {
            viewModel.loadNodes(nodes)
            lastSceneVisualKey = sceneVisualKey
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                onComplete?()
            }
        }
        .onChange(of: viewModel.currentNodeIndex) {
            let newSceneKey = sceneVisualKey
            defer { lastSceneVisualKey = newSceneKey }
            guard newSceneKey != lastSceneVisualKey else { return }
            sceneContentOpacity = 0.18
            withAnimation(.easeOut(duration: 0.28)) {
                sceneContentOpacity = 1.0
            }
        }
        .dialogMacOSMinWindowFrame()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func dialogScene(geometry: GeometryProxy) -> some View {
        let layout = DialogAdaptiveLayout(
            width: geometry.size.width,
            height: geometry.size.height,
            safeAreaInsets: geometry.safeAreaInsets
        )

        return ZStack {
            // Background
            backgroundLayer(layout: layout)

            visualNovelLayout(layout: layout, geometry: geometry)

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
    
    // MARK: - Visual Novel Layout (Character Center / Dialog Bottom)
    private func visualNovelLayout(layout: DialogAdaptiveLayout, geometry: GeometryProxy) -> some View {
        ZStack {
            VStack {
                topBar(layout: layout)
                    .padding(.horizontal, layout.dialogPadding)
                    .padding(.top, topBarTopPadding(for: layout))
                Spacer()
            }
            .zIndex(20)

            VStack {
                Spacer(minLength: topBarTopPadding(for: layout) + layout.topBarReservedHeight + (layout.isCompact ? 10 : 14))

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
                .padding(.top, topBarTopPadding(for: layout))
            
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
                            backButton(layout: layout, forceIconOnly: true)
                            Spacer()
                            HStack(spacing: layout.elementSpacing) {
                                historyButton(layout: layout)
                                if showSettings {
                                    pauseButton(layout: layout, forceIconOnly: true)
                                }
                            }
                        }
                        .padding(.horizontal, layout.dialogPadding)
                        .padding(.top, topBarTopPadding(for: layout))
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
                .padding(.top, topBarTopPadding(for: layout))
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
    private func chapterStatusBadge(layout: DialogAdaptiveLayout) -> some View {
        VStack(spacing: 2) {
            Text(viewModel.resolvedCutsceneTitle(for: viewModel.currentNode) ?? "Story")
                .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("Line \(min(viewModel.currentNodeIndex + 1, max(viewModel.nodes.count, 1))) / \(max(viewModel.nodes.count, 1))")
                .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                .foregroundColor(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.42), in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func topBar(layout: DialogAdaptiveLayout) -> some View {
        let forceIconOnlyControls = layout.shouldUseIconOnlyTopBarControls
        let statusBadgeMaxWidth = min(
            max(layout.width * (layout.shouldWrapTopBar ? 1.0 : (layout.isCompact ? 0.52 : 0.46)), 180),
            layout.shouldWrapTopBar ? layout.width - (layout.dialogPadding * 2) : (layout.isCompact ? 260 : 380)
        )

        return Group {
            if layout.shouldWrapTopBar {
                VStack(spacing: max(8, layout.elementSpacing)) {
                    HStack(spacing: layout.elementSpacing) {
                        if showBackButton {
                            backButton(layout: layout, forceIconOnly: forceIconOnlyControls)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: layout.elementSpacing) {
                            historyButton(layout: layout)
                            if showSettings {
                                pauseButton(layout: layout, forceIconOnly: forceIconOnlyControls)
                            }
                        }
                    }

                    chapterStatusBadge(layout: layout)
                        .frame(maxWidth: statusBadgeMaxWidth)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: layout.elementSpacing) {
                    if showBackButton {
                        backButton(layout: layout, forceIconOnly: forceIconOnlyControls)
                    }

                    Spacer(minLength: 0)

                    chapterStatusBadge(layout: layout)
                        .frame(maxWidth: statusBadgeMaxWidth)
                        .layoutPriority(1)

                    Spacer(minLength: 0)

                    HStack(spacing: layout.elementSpacing) {
                        historyButton(layout: layout)
                        if showSettings {
                            pauseButton(layout: layout, forceIconOnly: forceIconOnlyControls)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func backButton(layout: DialogAdaptiveLayout, forceIconOnly: Bool = false) -> some View {
        DialogControlButton(
            icon: "xmark",
            title: (layout.isCompact || forceIconOnly) ? nil : "Exit",
            action: { dismiss() },
            layout: layout
        )
    }
    
    private func pauseButton(layout: DialogAdaptiveLayout, forceIconOnly: Bool = false) -> some View {
        DialogControlButton(
            icon: "pause.fill",
            title: (layout.isCompact || forceIconOnly) ? nil : "Pause",
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
        let splitShowcase = forcedPlacement == nil ? splitShowcaseMedia : nil
        let placement = forcedPlacement ?? (splitShowcase != nil ? .left : characterPlacement)
        let characterMaxWidth = splitShowcase != nil
            ? min(layout.characterMaxWidth, layout.width * (layout.isCompact ? 0.46 : 0.34))
            : layout.characterMaxWidth

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
                    .frame(maxWidth: characterMaxWidth, maxHeight: layout.characterMaxHeight)
                    .offset(x: splitShowcase != nil ? (layout.isCompact ? -8 : -18) : 0)
                if placement != .right { Spacer(minLength: 0) }
            }

            if let splitShowcase {
                HStack(alignment: .center, spacing: layout.elementSpacing) {
                    Spacer(minLength: layout.isCompact ? 0 : max(8, layout.elementSpacing))

                    DialogShowcaseCard(showcase: splitShowcase, layout: layout)
                        .frame(width: clockSplitShowcaseWidth(for: layout))
                        .padding(.trailing, layout.isCompact ? 4 : 10)
                        .padding(.bottom, layout.isCompact ? 8 : 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            
            // Character info badge
            characterInfoBadge(layout: layout, alignLeading: splitShowcase != nil)
                .padding(.leading, splitShowcase != nil ? (layout.isCompact ? 12 : 20) : 0)
                .padding(.trailing, splitShowcase == nil ? (layout.isCompact ? 16 : 24) : 0)
                .padding(.bottom, layout.isCompact ? 20 : 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: placement)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: splitShowcase?.imageName ?? "")
    }

    private func clockSplitShowcaseWidth(for layout: DialogAdaptiveLayout) -> CGFloat {
        switch true {
        case layout.isCompact:
            return min(layout.width * 0.48, 210)
        case layout.isRegular:
            return min(layout.width * 0.34, 260)
        case layout.isLarge:
            return min(layout.width * 0.28, 300)
        default:
            return min(layout.width * 0.24, 340)
        }
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
    
    private func characterInfoBadge(layout: DialogAdaptiveLayout, alignLeading: Bool = false) -> some View {
        HStack {
            if !alignLeading { Spacer() }
            VStack(alignment: alignLeading ? .leading : .trailing, spacing: layout.elementSpacing / 2) {
                Text(viewModel.resolvedSpeaker(for: viewModel.currentNode).isEmpty ? "Unknown" : viewModel.resolvedSpeaker(for: viewModel.currentNode))
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
            if alignLeading { Spacer() }
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
        let currentNode = viewModel.currentNode
        let isInlineActivityPanelVisible =
            !viewModel.isTyping &&
            !viewModel.showChoices &&
            !viewModel.showTextInput &&
            currentNode?.inlineActivity != nil
        let isShowingInteractivePanel = viewModel.showChoices || viewModel.showTextInput || isInlineActivityPanelVisible

        return VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack(alignment: .center) {
                Text(viewModel.resolvedSpeaker(for: currentNode))
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
               let sceneSubtitle = viewModel.resolvedCutsceneSubtitle(for: currentNode) {
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
            } else if let node = currentNode,
                      let inlineActivity = node.inlineActivity,
                      !viewModel.isTyping {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.displayedText)
                        .font(.system(size: layout.bodyFontSize, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.98))
                        .lineSpacing(layout.isCompact ? 5 : 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.85)

                    inlineActivitySection(
                        activity: inlineActivity,
                        nodeID: node.id,
                        layout: layout
                    )

                    if let result = viewModel.inlineActivityResult(for: node.id), !result.isEmpty {
                        Text(result)
                            .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                            .foregroundColor(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    HStack {
                        Text(viewModel.isInlineActivityCompleted(for: node.id) ? "Mini-game complete. Tap to continue." : "Complete this mini-game to continue.")
                            .font(.system(size: layout.captionFontSize, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
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

    @ViewBuilder
    private func inlineActivitySection(
        activity: DialogInlineActivity,
        nodeID: UUID,
        layout: DialogAdaptiveLayout
    ) -> some View {
        switch activity {
        case .video(let clip):
            DialogVideoCutsceneCard(
                clip: clip,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: nodeID)
            ) { result in
                viewModel.completeInlineActivity(for: nodeID, result: result)
            }
        case .promptBuilder(let minigame):
            PromptBuilderMiniGameCard(
                minigame: minigame,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: nodeID)
            ) { result in
                viewModel.completeInlineActivity(for: nodeID, result: result)
            }
        case .lectureQuiz(let quiz):
            LectureQuizMiniGameCard(
                quiz: quiz,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: nodeID)
            ) { result in
                viewModel.completeInlineActivity(for: nodeID, result: result)
            }
        }
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
            settingsPanelBackdrop
            settingsPanelCard(layout: layout)
        }
    }

    private var settingsPanelBackdrop: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring()) { showSettingsPanel = false }
            }
    }

    private func settingsPanelCard(layout: DialogAdaptiveLayout) -> some View {
        ScrollView(showsIndicators: false) {
            settingsPanelContent(layout: layout)
        }
        .frame(maxWidth: min(layout.dialogMaxWidth, 400), maxHeight: layout.pausePanelMaxHeight)
        .background(
            RoundedRectangle(cornerRadius: layout.dialogCornerRadius)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.dialogCornerRadius)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: layout.dialogCornerRadius, style: .continuous))
        .padding(.horizontal, layout.dialogPadding)
    }

    private func settingsPanelContent(layout: DialogAdaptiveLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            settingsPanelHeader(layout: layout)

            Divider()
                .background(Color.white.opacity(0.2))

            pauseActionButtons(layout: layout)
            characterPositionSection(layout: layout)
            typingSpeedSection(layout: layout)
            backgroundBrightnessSection(layout: layout)
            closePauseMenuButton(layout: layout)
        }
        .padding(layout.dialogPadding)
        .frame(maxWidth: .infinity)
    }

    private func settingsPanelHeader(layout: DialogAdaptiveLayout) -> some View {
        VStack(spacing: 6) {
            Text("Paused")
                .font(.system(size: layout.bodyFontSize + 2, weight: .bold))
                .foregroundColor(.white)

            Text("Chapter is paused. Resume, adjust settings, or exit.")
                .font(.system(size: layout.captionFontSize + 1))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func pauseActionButtons(layout: DialogAdaptiveLayout) -> some View {
        if layout.usesVerticalPauseActions {
            VStack(spacing: 10) {
                resumeButton(layout: layout)
                exitChapterButton(layout: layout)
            }
        } else {
            HStack(spacing: 10) {
                resumeButton(layout: layout)
                exitChapterButton(layout: layout)
            }
        }
    }

    private func resumeButton(layout: DialogAdaptiveLayout) -> some View {
        Button(action: { showSettingsPanel = false }) {
            Text("Resume")
                .font(.system(size: layout.bodyFontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func exitChapterButton(layout: DialogAdaptiveLayout) -> some View {
        Button(action: { dismiss() }) {
            Text("Exit Chapter")
                .font(.system(size: layout.bodyFontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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

    private func characterPositionSection(layout: DialogAdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Character Position")
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ForEach(VNCharacterPlacement.allCases) { placement in
                    let isSelected = characterPlacement == placement

                    Button {
                        characterPlacement = placement
                    } label: {
                        Text(placement.label)
                            .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? Color.pink.opacity(0.85) : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.pink.opacity(0.25) : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func typingSpeedSection(layout: DialogAdaptiveLayout) -> some View {
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
    }

    private func backgroundBrightnessSection(layout: DialogAdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background Brightness")
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white)

            Slider(value: $backgroundOpacity, in: 0.3...1.0)
        }
    }

    private func closePauseMenuButton(layout: DialogAdaptiveLayout) -> some View {
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
struct DialogVideoCutsceneCard: View {
    let clip: DialogVideoClip
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void

    @State private var player: AVPlayer?
    @State private var didSetupPlayer = false
    @State private var failedToLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .foregroundColor(.pink.opacity(0.9))
                Text(clip.title)
                    .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Placeholder")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            if let subtitle = clip.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.7))
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.45))

                if failedToLoad {
                    VStack(spacing: 6) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Could not load \(clip.resourceName).\(clip.fileExtension)")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                } else {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(height: layout.isCompact ? 150 : 220)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Button {
                    player?.seek(to: .zero)
                    player?.play()
                } label: {
                    Label("Replay", systemImage: "gobackward")
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(player == nil && failedToLoad)

                Spacer()

                Button {
                    let filename = "\(clip.resourceName).\(clip.fileExtension)"
                    onComplete("Watched placeholder cutscene: \(filename). Replace with final Chapter 1 cutscene later.")
                } label: {
                    Label(isCompleted ? "Watched" : "Continue", systemImage: isCompleted ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((isCompleted ? Color.green : Color.pink).opacity(0.9), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isCompleted)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            setupPlayerIfNeeded()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func setupPlayerIfNeeded() {
        guard !didSetupPlayer else { return }
        didSetupPlayer = true

        let url =
            Bundle.module.url(forResource: clip.resourceName, withExtension: clip.fileExtension) ??
            Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension)

        guard let url else {
            failedToLoad = true
            return
        }

        let player = AVPlayer(url: url)
        self.player = player

        if clip.autoplay {
            player.play()
        }
    }
}

struct PromptBuilderMiniGameCard: View {
    let minigame: PromptBuilderMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void

    @State private var selectedOptionBySlotID: [String: String] = [:]
    @State private var submitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(minigame.title)
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.white)
                    Text("Tap chips to build a better prompt (Goal + Context + Action + Format)")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.68))
                }
                Spacer()
                Text("Messages")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .overlay(Image(systemName: "questionmark").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                    Text(minigame.contactName)
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }

                HStack {
                    Text(minigame.introMessage)
                        .font(.system(size: layout.captionFontSize + 1))
                        .foregroundColor(.black.opacity(0.82))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer(minLength: 26)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            ForEach(minigame.slots) { slot in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(slot.label)
                            .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Text(selectedOption(for: slot)?.chipText ?? slot.placeholder)
                            .font(.system(size: layout.captionFontSize, weight: .medium))
                            .foregroundColor((selectedOption(for: slot) == nil ? Color.white.opacity(0.45) : Color.cyan.opacity(0.9)))
                            .lineLimit(1)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(slot.options) { option in
                                let isSelected = selectedOptionBySlotID[slot.id] == option.id
                                Button {
                                    guard !isCompleted else { return }
                                    selectedOptionBySlotID[slot.id] = option.id
                                } label: {
                                    Text(option.chipText)
                                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                                        .foregroundColor(isSelected ? .black : .white.opacity(0.92))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.cyan.opacity(0.95) : Color.white.opacity(0.07))
                                                .overlay(
                                                    Capsule().stroke(isSelected ? Color.cyan.opacity(0.15) : Color.white.opacity(0.12), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(isCompleted)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt Preview")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Text(promptPreview)
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            if let tip = minigame.tip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.65))
            }

            HStack(spacing: 10) {
                if submitted || isCompleted {
                    Label("Sent", systemImage: "checkmark.circle.fill")
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundColor(.green.opacity(0.9))
                }

                Spacer()

                Button {
                    submitPrompt()
                } label: {
                    Label("Send Prompt", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background((canSubmit && !isCompleted) ? Color.blue.opacity(0.9) : Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isCompleted)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var canSubmit: Bool {
        minigame.slots.allSatisfy { selectedOptionBySlotID[$0.id] != nil }
    }

    private var promptPreview: String {
        minigame.slots.map { slot in
            selectedOption(for: slot)?.promptText ?? "[\(slot.placeholder)]"
        }
        .joined(separator: " ")
    }

    private func selectedOption(for slot: PromptBuilderSlot) -> PromptBuilderOption? {
        guard let optionID = selectedOptionBySlotID[slot.id] else { return nil }
        return slot.options.first(where: { $0.id == optionID })
    }

    private func recommendedPrompt() -> String {
        minigame.slots.map { slot in
            slot.options.first(where: { $0.id == slot.recommendedOptionID })?.promptText ?? slot.placeholder
        }
        .joined(separator: " ")
    }

    private func submitPrompt() {
        guard canSubmit, !isCompleted else { return }
        submitted = true

        let selections = minigame.slots.compactMap { selectedOption(for: $0) }
        let selectedNotes = selections.map(\.feedbackNote).joined(separator: " ")
        let recommendedMatches = minigame.slots.filter { slot in
            selectedOptionBySlotID[slot.id] == slot.recommendedOptionID
        }.count
        let summary = "Message sent to \(minigame.contactName). All answers can work, but the strongest prompt here is: \"\(recommendedPrompt())\". Your version matched \(recommendedMatches)/\(minigame.slots.count) best-practice parts. \(selectedNotes) The sender still appears as \"\(minigame.contactName)\" for now; you can rename them later (default: Ploy)."
        onComplete(summary)
    }
}

struct LectureQuizMiniGameCard: View {
    let quiz: LectureQuizMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void

    @State private var selectedChoiceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            headerSection
            exampleImageSection
            questionSection
            choicesSection
            feedbackSection
        }
        .padding(12)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(quiz.title)
                    .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                    .foregroundColor(.white)
                Text(quiz.promptLabel)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.68))
            }
            Spacer()
            Label("Class Mini-game", systemImage: "graduationcap.fill")
                .font(.system(size: layout.captionFontSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private var exampleImageSection: some View {
        if let imageName = quiz.exampleImageName {
            VStack(alignment: .leading, spacing: 6) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: layout.isCompact ? 115 : 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                if let caption = quiz.exampleCaption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private var questionSection: some View {
        Text(quiz.question)
            .font(.system(size: layout.captionFontSize + 2, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.95))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var choicesSection: some View {
        VStack(spacing: 8) {
            ForEach(quiz.choices) { choice in
                choiceButton(for: choice)
            }
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let selectedChoice = selectedChoice {
            Text(selectedChoice.feedback)
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.7))
        } else if isCompleted {
            Text("Answer recorded. You can continue.")
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var selectedChoice: LectureQuizOption? {
        guard let selectedChoiceID else { return nil }
        return quiz.choices.first(where: { $0.id == selectedChoiceID })
    }

    private func choiceButton(for choice: LectureQuizOption) -> some View {
        let isSelected = selectedChoiceID == choice.id

        return Button {
            select(choice)
        } label: {
            HStack(spacing: 8) {
                if let icon = choice.icon {
                    Image(systemName: icon)
                        .font(.system(size: layout.captionFontSize + 1))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                        .frame(width: 20)
                }

                Text(choice.text)
                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .white.opacity(0.95))
                    .multilineTextAlignment(.leading)

                Spacer()

                if choice.isBestAnswer {
                    Text("Best")
                        .font(.system(size: layout.captionFontSize - 1, weight: .bold))
                        .foregroundColor(isSelected ? .black.opacity(0.7) : .mint.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.55) : Color.mint.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.mint.opacity(0.9) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.mint.opacity(0.22) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }

    private func select(_ choice: LectureQuizOption) {
        guard !isCompleted else { return }
        selectedChoiceID = choice.id

        let bestChoice = quiz.choices.first(where: \.isBestAnswer)
        let bestText = bestChoice?.text ?? "See the explanation"
        let bestCallout = choice.isBestAnswer
            ? "You chose the best answer."
            : "Best answer: \(bestText)."
        let summary = "\(choice.feedback) \(bestCallout) \(quiz.summaryNote)"
        onComplete(summary)
    }
}

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
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, title != nil ? (layout.isCompact ? 10 : 14) : (layout.isCompact ? 8 : 10))
            .padding(.vertical, title != nil ? (layout.isCompact ? 6 : 8) : (layout.isCompact ? 8 : 10))
            .frame(minHeight: layout.controlButtonMinTapSize)
            .frame(minWidth: title == nil ? layout.controlButtonMinTapSize : nil)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isHovered ? 0.28 : 0.14), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .contentShape(Capsule())
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
                Group {
                    if showcase.imageName == "__clock_placeholder__" {
                        PlaceholderClockHeroCard()
                    } else {
                        Image(showcase.imageName)
                            .resizable()
                            .scaledToFill()
                    }
                }
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

private struct PlaceholderClockHeroCard: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.15),
                    Color(red: 0.13, green: 0.16, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .padding(10)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))

                    ForEach(0..<12, id: \.self) { mark in
                        Rectangle()
                            .fill(Color.white.opacity(mark % 3 == 0 ? 0.75 : 0.35))
                            .frame(width: 2, height: mark % 3 == 0 ? 10 : 6)
                            .offset(y: -34)
                            .rotationEffect(.degrees(Double(mark) * 30))
                    }

                    // Deliberately wrong "67 minutes" cue (placeholder art)
                    Rectangle()
                        .fill(Color.red.opacity(0.9))
                        .frame(width: 2, height: 30)
                        .offset(y: -15)
                        .rotationEffect(.degrees(402)) // 67 * 6

                    Rectangle()
                        .fill(Color.cyan.opacity(0.95))
                        .frame(width: 3, height: 22)
                        .offset(y: -11)
                        .rotationEffect(.degrees(324)) // 10-ish

                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 6) {
                    Text("10:67")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("Impossible time")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("Placeholder clock art")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
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
