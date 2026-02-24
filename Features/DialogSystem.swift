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
            return min(width - 56, 1320)
        case isExtraLarge:
            return min(width - 80, 1720)
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
    @StateObject private var speechManager = SpeechManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var globalSettings: GlobalSettingsStore
    
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

    private var activeInlineActivityContext: (node: DialogNode, activity: DialogInlineActivity)? {
        guard let node = viewModel.currentNode,
              let activity = node.inlineActivity else {
            return nil
        }
        return (node, activity)
    }

    private var backgroundOverlayStrength: Double {
        guard let activity = activeInlineActivityContext?.activity else { return 1.0 }
        switch activity {
        case .video:
            return 1.0
        case .lectureQuiz, .promptBuilder:
            return 0.72
        }
    }

    private var chapterMusicVolumeBinding: Binding<Double> {
        Binding(
            get: { globalSettings.masterVolume },
            set: { newValue in
                globalSettings.masterVolume = min(max(newValue, 0), 1)
            }
        )
    }

    private var chapterSpeechVolumeBinding: Binding<Double> {
        Binding(
            get: { globalSettings.speechEnabled ? globalSettings.masterVolume : 0 },
            set: { newValue in
                let clamped = min(max(newValue, 0), 1)
                if clamped <= 0.001 {
                    globalSettings.speechEnabled = false
                    return
                }
                globalSettings.speechEnabled = true
                globalSettings.masterVolume = clamped
            }
        )
    }

    private func volumePercentText(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
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

    private func normalizedVoiceMatchText(_ raw: String) -> String {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return "" }

        // Normalize punctuation/spacing so labels like "Player(You)" or "Professor-New" match.
        let separators = CharacterSet.alphanumerics.inverted
        let parts = lowered
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    private func isProfessorSpeaker(_ normalized: String) -> Bool {
        if normalized.isEmpty { return false }
        return normalized.contains("professor new")
            || normalized.contains("professr new")
            || normalized.contains("profesor new")
            || normalized.hasPrefix("professor")
            || normalized.hasPrefix("professr")
            || normalized.contains("teacher")
    }

    private func isPlayerSpeaker(_ normalized: String) -> Bool {
        if normalized.isEmpty { return false }
        return normalized == "you"
            || normalized == "player"
            || normalized == "player you"
            || normalized.contains(" player ")
            || normalized.hasPrefix("player ")
            || normalized.hasPrefix("you ")
            || normalized.contains(" you ")
            || normalized.hasSuffix(" you")
            || normalized.contains("student")
    }

    private func voiceProfile(for speaker: String) -> SpeechVoiceProfile {
        let normalized = normalizedVoiceMatchText(speaker)
        if isProfessorSpeaker(normalized) {
            return .professorMale
        }
        if isPlayerSpeaker(normalized) {
            return .playerFemale
        }
        return .default
    }

    private func inferredVoiceProfile(forSpokenText text: String, fallbackSpeaker: String) -> SpeechVoiceProfile {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = normalizedVoiceMatchText(trimmed)

        let startsWithProfessorCue =
            normalizedText == "professor new"
            || normalizedText.hasPrefix("professor new ")
            || normalizedText == "professr new"
            || normalizedText.hasPrefix("professr new ")
            || normalizedText == "profesor new"
            || normalizedText.hasPrefix("profesor new ")

        if startsWithProfessorCue {
            return .professorMale
        }

        let startsWithPlayerCue =
            normalizedText == "you"
            || normalizedText.hasPrefix("you ")
            || normalizedText == "player"
            || normalizedText.hasPrefix("player ")
            || normalizedText == "player you"
            || normalizedText.hasPrefix("player you ")

        if startsWithPlayerCue {
            return .playerFemale
        }

        return voiceProfile(for: fallbackSpeaker)
    }

    private func speakCurrentNodeText() {
        guard let node = viewModel.currentNode else { return }
        let text = viewModel.resolvedText(for: node).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let speaker = viewModel.resolvedSpeaker(for: node)
        speechManager.speak(text, emotion: node.emotion, voiceProfile: voiceProfile(for: speaker))
    }

    private func handleSkipTypingAction() {
        speechManager.stop()
        viewModel.skipTyping()
    }

    private func handleAdvanceAction() {
        speechManager.stop()
        viewModel.advance()
    }

    private func handleSelectChoiceAction(_ choice: DialogChoice) {
        speechManager.stop()
        let responseText = viewModel.renderTemplate(choice.response).trimmingCharacters(in: .whitespacesAndNewlines)
        let currentSpeaker = viewModel.resolvedSpeaker(for: viewModel.currentNode)
        viewModel.selectChoice(choice)

        if !responseText.isEmpty {
            speechManager.speak(
                responseText,
                emotion: choice.emotion,
                voiceProfile: inferredVoiceProfile(forSpokenText: responseText, fallbackSpeaker: currentSpeaker)
            )
        }
    }

    private func handleSubmitInputAction() {
        speechManager.stop()
        viewModel.submitInput()
    }
    
    var body: some View {
        GeometryReader { geometry in
            dialogScene(geometry: geometry)
        }
        .onAppear {
            viewModel.loadNodes(nodes)
            speakCurrentNodeText()
            lastSceneVisualKey = sceneVisualKey
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                speechManager.stop()
                onComplete?()
            }
        }
        .onChange(of: viewModel.currentNodeIndex) {
            speechManager.stop()
            speakCurrentNodeText()
            let newSceneKey = sceneVisualKey
            defer { lastSceneVisualKey = newSceneKey }
            guard newSceneKey != lastSceneVisualKey else { return }
            sceneContentOpacity = 0.18
            withAnimation(globalSettings.reduceMotion ? nil : .easeOut(duration: 0.28)) {
                sceneContentOpacity = 1.0
            }
        }
        .transaction { transaction in
            if globalSettings.reduceMotion {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
        .onDisappear {
            speechManager.stop()
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
            backgroundLayer(layout: layout, overlayStrength: backgroundOverlayStrength)

            if let context = activeInlineActivityContext {
                inlineActivityScene(
                    layout: layout,
                    geometry: geometry,
                    node: context.node,
                    activity: context.activity
                )
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

            visualNovelBottomFade(layout: layout)
                .allowsHitTesting(false)
                .zIndex(5)

            VStack {
                Spacer()
                dialogSection(layout: layout, maxWidth: layout.visualNovelDialogMaxWidth)
                    .padding(.horizontal, layout.dialogPadding)
                    .padding(.bottom, visualNovelDialogBottomPadding(for: layout))
            }
            .zIndex(10)
        }
    }

    private func visualNovelBottomFade(layout: DialogAdaptiveLayout) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.60),
                .init(color: Color.black.opacity(0.18), location: 0.72),
                .init(color: Color.black.opacity(0.56), location: 0.86),
                .init(color: Color.black.opacity(0.86), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func visualNovelDialogBottomPadding(for layout: DialogAdaptiveLayout) -> CGFloat {
        let safeBottom = layout.safeAreaInsets.bottom > 0 ? layout.safeAreaInsets.bottom : (layout.isCompact ? 10 : 14)
        let lift = max(18, layout.dialogLiftFromBottom * (layout.isCompact ? 0.38 : 0.32))
        let shortScreenExtra = layout.height < 430 ? 10 : 0
        return safeBottom + lift + CGFloat(shortScreenExtra)
    }

    @ViewBuilder
    private func inlineActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        activity: DialogInlineActivity
    ) -> some View {
        switch activity {
        case .video(let clip):
            fullScreenCutsceneScene(layout: layout, geometry: geometry, node: node, clip: clip)
        case .lectureQuiz(let quiz):
            lectureQuizActivityScene(layout: layout, geometry: geometry, node: node, quiz: quiz)
        case .promptBuilder(let minigame):
            promptBuilderActivityScene(layout: layout, geometry: geometry, node: node, minigame: minigame)
        }
    }

    private func fullScreenCutsceneScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        clip: DialogVideoClip
    ) -> some View {
        ZStack {
            DialogFullscreenVideoCutsceneStage(
                clip: clip,
                title: viewModel.resolvedCutsceneTitle(for: node) ?? clip.title,
                subtitle: viewModel.resolvedCutsceneSubtitle(for: node),
                instructionText: viewModel.displayedText,
                isTyping: viewModel.isTyping,
                isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                onSkipTyping: { handleSkipTypingAction() },
                onMarkComplete: {
                    let filename = "\(clip.resourceName).\(clip.fileExtension)"
                    viewModel.completeInlineActivity(
                        for: node.id,
                        result: "Watched placeholder cutscene: \(filename). Replace with final Chapter 1 cutscene later."
                    )
                },
                onContinue: {
                    guard viewModel.isInlineActivityCompleted(for: node.id) else { return }
                    handleAdvanceAction()
                }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    if showSettings {
                        chapterMenuButton(layout: layout)
                    }
                    Spacer()
                }
                .padding(.horizontal, layout.dialogPadding)
                .padding(.top, layout.topBarSafePadding)
                Spacer()
            }
            .zIndex(10)
        }
    }

    @ViewBuilder
    private func lectureQuizActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        quiz: LectureQuizMiniGame
    ) -> some View {
        if quiz.usesClassroomStageLayout {
            classroomLectureQuizActivityScene(
                layout: layout,
                geometry: geometry,
                node: node,
                quiz: quiz
            )
        } else {
        let horizontalPadding = layout.dialogPadding
        let bottomSafePadding = max(layout.safeAreaInsets.bottom, 12)
        let leftWidth = max(min(geometry.size.width * 0.26, 360), 210)
        let useVerticalLayout = geometry.size.width < 980 || geometry.size.height < 680

        VStack(spacing: 0) {
            topBar(layout: layout)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topBarTopPadding(for: layout))

            if useVerticalLayout {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        LectureQuizMiniGameCard(
                            quiz: quiz,
                            layout: layout,
                            isCompleted: viewModel.isInlineActivityCompleted(for: node.id)
                        ) { result in
                            viewModel.completeInlineActivity(for: node.id, result: result)
                        }
                        .allowsHitTesting(!viewModel.isTyping)
                        .opacity(viewModel.isTyping ? 0.8 : 1.0)

                        MiniGameStageCharacterPanel(
                            speaker: viewModel.resolvedSpeaker(for: node).isEmpty ? "Character" : viewModel.resolvedSpeaker(for: node),
                            subtitle: viewModel.resolvedCutsceneSubtitle(for: node),
                            emotion: node.emotion,
                            characterImageName: node.characterImage ?? StoryCharacterAsset.placeholder(for: node.emotion),
                            instructionText: viewModel.displayedText,
                            isTyping: viewModel.isTyping,
                            layout: layout,
                            accentColor: getEmotionColor(node.emotion),
                            onSkipTyping: { handleSkipTypingAction() }
                        )
                        .frame(height: min(max(220, geometry.size.height * 0.34), 360))
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
            } else {
                HStack(alignment: .top, spacing: layout.sectionSpacing) {
                    MiniGameStageCharacterPanel(
                        speaker: viewModel.resolvedSpeaker(for: node).isEmpty ? "Character" : viewModel.resolvedSpeaker(for: node),
                        subtitle: viewModel.resolvedCutsceneSubtitle(for: node),
                        emotion: node.emotion,
                        characterImageName: node.characterImage ?? StoryCharacterAsset.placeholder(for: node.emotion),
                        instructionText: viewModel.displayedText,
                        isTyping: viewModel.isTyping,
                        layout: layout,
                        accentColor: getEmotionColor(node.emotion),
                        onSkipTyping: { handleSkipTypingAction() }
                    )
                    .frame(width: leftWidth)
                    .frame(maxHeight: .infinity, alignment: .top)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            LectureQuizMiniGameCard(
                                quiz: quiz,
                                layout: layout,
                                isCompleted: viewModel.isInlineActivityCompleted(for: node.id)
                            ) { result in
                                viewModel.completeInlineActivity(for: node.id, result: result)
                            }
                            .allowsHitTesting(!viewModel.isTyping)
                            .opacity(viewModel.isTyping ? 0.8 : 1.0)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }

            MiniGameBottomBar(
                instructionText: viewModel.isInlineActivityCompleted(for: node.id)
                    ? "Answer recorded. Continue when you are ready."
                    : "Choose an answer to continue.",
                continueTitle: "Continue Story",
                isContinueEnabled: viewModel.isInlineActivityCompleted(for: node.id),
                layout: layout,
                onContinue: { handleAdvanceAction() }
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomSafePadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func classroomLectureQuizActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        quiz: LectureQuizMiniGame
    ) -> some View {
        let horizontalPadding = layout.dialogPadding
        let topInset = topBarTopPadding(for: layout) + max(36, layout.topBarReservedHeight - (geometry.size.height < 700 ? 18 : 10))
        let bottomInset = max(layout.safeAreaInsets.bottom, 10)

        return ZStack {
            VStack {
                topBar(layout: layout)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topBarTopPadding(for: layout))
                Spacer()
            }
            .zIndex(20)

            ClassroomLectureQuizMiniGameStage(
                quiz: quiz,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                isTyping: viewModel.isTyping,
                instructionText: viewModel.displayedText,
                onSkipTyping: { handleSkipTypingAction() },
                onComplete: { result in
                    viewModel.completeInlineActivity(for: node.id, result: result)
                },
                onContinue: {
                    guard viewModel.isInlineActivityCompleted(for: node.id) else { return }
                    handleAdvanceAction()
                }
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func promptBuilderActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        minigame: PromptBuilderMiniGame
    ) -> some View {
        let horizontalPadding = layout.dialogPadding
        let useScrollStage = geometry.size.width < 1120 || geometry.size.height < 760
        let stageSpeaker = viewModel.resolvedSpeaker(for: node).isEmpty ? "You" : viewModel.resolvedSpeaker(for: node)
        let stageRoleLabel = dialogRoleLabel(for: node)
        let stageCharacterImage = node.characterImage ?? StoryCharacterAsset.placeholder(for: node.emotion)

        return VStack(spacing: 0) {
            topBar(layout: layout)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topBarTopPadding(for: layout))

            if useScrollStage {
                ScrollView(showsIndicators: false) {
                    PromptBuilderMessagesMiniGameStage(
                        minigame: minigame,
                        layout: layout,
                        availableWidth: geometry.size.width - (horizontalPadding * 2),
                        availableHeight: max(geometry.size.height * 0.78, 520),
                        speaker: stageSpeaker,
                        roleLabel: stageRoleLabel,
                        emotion: node.emotion,
                        characterImageName: stageCharacterImage,
                        instructionText: viewModel.displayedText,
                        isTyping: viewModel.isTyping,
                        isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                        onSkipTyping: { handleSkipTypingAction() },
                        onContinue: { handleAdvanceAction() }
                    ) { result in
                        viewModel.completeInlineActivity(for: node.id, result: result)
                    }
                    .frame(minHeight: max(geometry.size.height * 0.74, 520))
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, max(layout.safeAreaInsets.bottom, 12))
                }
            } else {
                PromptBuilderMessagesMiniGameStage(
                    minigame: minigame,
                    layout: layout,
                    availableWidth: geometry.size.width - (horizontalPadding * 2),
                    availableHeight: geometry.size.height,
                    speaker: stageSpeaker,
                    roleLabel: stageRoleLabel,
                    emotion: node.emotion,
                    characterImageName: stageCharacterImage,
                    instructionText: viewModel.displayedText,
                    isTyping: viewModel.isTyping,
                    isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                    onSkipTyping: { handleSkipTypingAction() },
                    onContinue: { handleAdvanceAction() }
                ) { result in
                    viewModel.completeInlineActivity(for: node.id, result: result)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, max(layout.safeAreaInsets.bottom, 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func activityReviewFooter(
        layout: DialogAdaptiveLayout,
        nodeID: UUID,
        pendingText: String,
        completedButtonTitle: String,
        showSummary: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if showSummary, let result = viewModel.inlineActivityResult(for: nodeID), !result.isEmpty {
                Text(result)
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else if viewModel.isInlineActivityCompleted(for: nodeID) && !showSummary {
                Text("Review shown above. Continue when you are ready.")
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                Text(pendingText)
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            if layout.width < 700 {
                Button {
                    guard viewModel.isInlineActivityCompleted(for: nodeID) else { return }
                    handleAdvanceAction()
                } label: {
                    Label(completedButtonTitle, systemImage: "arrow.right.circle.fill")
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.isInlineActivityCompleted(for: nodeID)
                                ? Color.pink
                                : Color(hex: "3B4048"),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isInlineActivityCompleted(for: nodeID))
            } else {
                HStack {
                    Spacer()
                    Button {
                        guard viewModel.isInlineActivityCompleted(for: nodeID) else { return }
                        handleAdvanceAction()
                    } label: {
                        Label(completedButtonTitle, systemImage: "arrow.right.circle.fill")
                            .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.isInlineActivityCompleted(for: nodeID)
                                    ? Color.pink
                                    : Color(hex: "3B4048"),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isInlineActivityCompleted(for: nodeID))
                }
            }
        }
    }

    // MARK: - Background Layer
    private func backgroundLayer(layout: DialogAdaptiveLayout, overlayStrength: Double = 1.0) -> some View {
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
                    Color.black.opacity(0.55 * overlayStrength),
                    Color.black.opacity(0.15 * overlayStrength),
                    Color.black.opacity(0.2 * overlayStrength),
                    Color.black.opacity(0.8 * overlayStrength)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.5 * overlayStrength)],
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
                
                // Menu overlay
                if showSettings {
                    VStack {
                        HStack {
                            chapterMenuButton(layout: layout)
                            Spacer()
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
    private func topBar(layout: DialogAdaptiveLayout) -> some View {
        HStack {
            if showSettings {
                chapterMenuButton(layout: layout)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chapterMenuButton(layout: DialogAdaptiveLayout) -> some View {
        let width: CGFloat = layout.isCompact ? 140 : (layout.isLarge ? 190 : 165)

        return Button {
            withAnimation(globalSettings.reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.9)) {
                showSettingsPanel.toggle()
            }
        } label: {
            Image("Menu")
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .padding(6)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menu")
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
        .frame(maxWidth: maxWidth ?? layout.dialogMaxWidth, alignment: .leading)
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

    private func formattedEmotionLabel(_ emotion: Emotion) -> String {
        emotion.rawValue
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func dialogRoleLabel(for node: DialogNode?) -> String? {
        guard let node else { return nil }
        let subtitle = viewModel.resolvedCutsceneSubtitle(for: node)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let subtitle,
           !subtitle.isEmpty,
           subtitle.count <= 24,
           !subtitle.contains("•"),
           !subtitle.contains("/") {
            return subtitle
        }

        return formattedEmotionLabel(node.emotion)
    }

    private func dialogSceneNote(for node: DialogNode?) -> String? {
        guard let subtitle = viewModel.resolvedCutsceneSubtitle(for: node)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !subtitle.isEmpty else {
            return nil
        }

        if subtitle == dialogRoleLabel(for: node) {
            return nil
        }

        return subtitle
    }
    
    private func dialogBox(layout: DialogAdaptiveLayout) -> some View {
        let currentNode = viewModel.currentNode
        let speakerName = viewModel.resolvedSpeaker(for: currentNode)
        let displaySpeakerName = speakerName.isEmpty ? "Narrator" : speakerName
        let roleLabel = dialogRoleLabel(for: currentNode)
        let sceneNote = dialogSceneNote(for: currentNode)
        let accentColor = getEmotionColor(currentNode?.emotion ?? .neutral)
        let isInlineActivityPanelVisible =
            !viewModel.isTyping &&
            !viewModel.showChoices &&
            !viewModel.showTextInput &&
            currentNode?.inlineActivity != nil
        let isShowingInteractivePanel = viewModel.showChoices || viewModel.showTextInput || isInlineActivityPanelVisible

        return VStack(alignment: .leading, spacing: layout.isCompact ? 10 : 12) {
            HStack(alignment: .firstTextBaseline, spacing: layout.isCompact ? 8 : 12) {
                Text(displaySpeakerName)
                    .font(
                        .system(
                            size: layout.isCompact ? (layout.speakerFontSize + 9) : (layout.speakerFontSize + 16),
                            weight: .heavy,
                            design: .rounded
                        )
                    )
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)

                if let roleLabel, !roleLabel.isEmpty {
                    Text(roleLabel)
                        .font(.system(size: layout.isCompact ? (layout.speakerFontSize + 2) : (layout.speakerFontSize + 4), weight: .bold, design: .rounded))
                        .foregroundColor(accentColor.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, layout.isCompact ? 1 : 2)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    if viewModel.isTyping {
                        TypingIndicator(layout: layout)
                    }

                    if viewModel.isTyping {
                        Button(action: { handleSkipTypingAction() }) {
                            Text("Skip")
                                .font(.system(size: layout.captionFontSize, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.78))
                .frame(height: 1)

            if !isShowingInteractivePanel,
               let sceneNote,
               !sceneNote.isEmpty {
                Text(sceneNote.uppercased())
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.62))
                    .tracking(0.8)
                    .lineLimit(1)
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
                                action: { handleSelectChoiceAction(choice) }
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
                    .font(.system(size: layout.bodyFontSize + (layout.isCompact ? 2 : 4), weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.98))
                    .lineSpacing(layout.isCompact ? 4 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 2)

                HStack {
                    Text(canAdvanceFromDialogTap ? "Tap to continue" : "Complete this part first")
                        .font(.system(size: layout.captionFontSize, weight: .medium))
                        .foregroundColor(.white.opacity(0.52))

                    Spacer()

                    if canAdvanceFromDialogTap {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: max(layout.captionFontSize + 4, 12)))
                            .rotationEffect(.degrees(180))
                            .foregroundColor(.cyan.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
        .padding(.horizontal, layout.isCompact ? 14 : 20)
        .padding(.top, layout.isCompact ? 12 : 16)
        .padding(.bottom, layout.isCompact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(
            minHeight: isShowingInteractivePanel
                ? (layout.isCompact ? 188 : 214)
                : (layout.isCompact ? 118 : 138),
            alignment: .topLeading
        )
        .background {
            if isShowingInteractivePanel {
                RoundedRectangle(cornerRadius: max(layout.dialogCornerRadius - 6, 14), style: .continuous)
                    .fill(Color.black.opacity(0.26))
                    .overlay(
                        RoundedRectangle(cornerRadius: max(layout.dialogCornerRadius - 6, 14), style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
        .contentShape(Rectangle())
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onTapGesture {
            guard canAdvanceFromDialogTap else { return }
            handleAdvanceAction()
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
                    action: { handleSelectChoiceAction(choice) }
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
            .onSubmit { handleSubmitInputAction() }
            
            Button(action: { handleSubmitInputAction() }) {
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
                withAnimation(globalSettings.reduceMotion ? nil : .spring()) { showSettingsPanel = false }
            }
    }

    private func settingsPanelCard(layout: DialogAdaptiveLayout) -> some View {
        let cardWidth = min(layout.dialogMaxWidth, layout.isCompact ? 290 : 340)
        let cornerRadius: CGFloat = 12

        return ZStack(alignment: .topLeading) {
            settingsPanelContent(layout: layout)
                .frame(width: cardWidth)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "D9F1FF"),
                                    Color(hex: "A9DBFF"),
                                    Color(hex: "7FC3F3")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.52), lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 6)

            Image("Menu")
                .resizable()
                .scaledToFit()
                .frame(width: min(cardWidth * 0.34, 118))
                .offset(x: 10, y: -18)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .allowsHitTesting(false)
        }
        .padding(.top, 16)
        .padding(.horizontal, layout.dialogPadding)
    }

    private func settingsPanelContent(layout: DialogAdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .frame(height: layout.isCompact ? 22 : 26)

            menuVolumeSection(title: "MUSIC", value: chapterMusicVolumeBinding, layout: layout)
            menuVolumeSection(title: "SPEECH", value: chapterSpeechVolumeBinding, layout: layout)

            HStack(spacing: 10) {
                resumeButton(layout: layout)
                exitChapterButton(layout: layout)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
    }

    private func menuVolumeSection(
        title: String,
        value: Binding<Double>,
        layout: DialogAdaptiveLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: layout.bodyFontSize + (layout.isCompact ? 1 : 2), weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(0.95))
                    .tracking(0.3)

                Spacer(minLength: 0)

                Text(volumePercentText(value.wrappedValue))
                    .font(.system(size: layout.captionFontSize + 2, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "0A6FEA"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
            }

            menuSlider(value: value)
        }
    }

    private func resumeButton(layout: DialogAdaptiveLayout) -> some View {
        Button(action: { showSettingsPanel = false }) {
            Text("Resume")
                .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func exitChapterButton(layout: DialogAdaptiveLayout) -> some View {
        Button(action: { dismiss() }) {
            Text("Exit")
                .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "FB7A86"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func menuSlider(value: Binding<Double>) -> some View {
        GeometryReader { proxy in
            let trackHeight: CGFloat = 10
            let knobSize: CGFloat = 20
            let clampedValue = min(max(value.wrappedValue, 0), 1)
            let usableWidth = max(proxy.size.width - knobSize, 1)
            let knobCenterX = (usableWidth * clampedValue) + (knobSize / 2)
            let filledWidth = max(knobCenterX, trackHeight)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(hex: "D7EBF8").opacity(0.95))
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "2EC5FF"),
                                Color(hex: "1397F6"),
                                Color(hex: "0A6FEA")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: filledWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .offset(x: knobCenterX - (knobSize / 2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = min(max(gesture.location.x - (knobSize / 2), 0), usableWidth)
                        value.wrappedValue = x / usableWidth
                    }
            )
        }
        .frame(height: 22)
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
struct DialogFullscreenVideoCutsceneStage: View {
    let clip: DialogVideoClip
    let title: String
    let subtitle: String?
    let instructionText: String
    let isTyping: Bool
    let isCompleted: Bool
    let onSkipTyping: () -> Void
    let onMarkComplete: () -> Void
    let onContinue: () -> Void

    @State private var player: AVPlayer?
    @State private var didSetupPlayer = false
    @State private var failedToLoad = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safeInsets = proxy.safeAreaInsets
            let isCompactCutscene = size.width < 700 || size.height < 540
            let bottomLift = max(20, min(size.height * 0.14, isCompactCutscene ? 72 : 98))
            let overlayBottomPadding = (safeInsets.bottom > 0 ? safeInsets.bottom : (isCompactCutscene ? 10 : 14)) + bottomLift
            let horizontalPadding = max(16, min(size.width * 0.04, 42))
            let useVerticalButtons = size.width < 620 || size.height < 430

            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if failedToLoad {
                        ZStack {
                            LinearGradient(
                                colors: [Color.black, Color.gray.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            VStack(spacing: 10) {
                                Image(systemName: "video.slash.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("Could not load placeholder cutscene")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(clip.resourceName).\(clip.fileExtension)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    } else {
                        VideoPlayer(player: player)
                    }
                }
                .ignoresSafeArea()

                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.45), location: 0.0),
                        .init(color: .clear, location: 0.28),
                        .init(color: .clear, location: 0.58),
                        .init(color: Color.black.opacity(0.20), location: 0.70),
                        .init(color: Color.black.opacity(0.60), location: 0.86),
                        .init(color: Color.black.opacity(0.86), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: isCompactCutscene ? 10 : 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(title)
                                .font(.system(size: isCompactCutscene ? 23 : 30, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)

                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: isCompactCutscene ? 13 : 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan.opacity(0.95))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer(minLength: 8)

                            if isTyping {
                                Button(action: onSkipTyping) {
                                    Label("Skip Text", systemImage: "forward.fill")
                                        .font(.system(size: isCompactCutscene ? 12 : 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.75))
                            .frame(height: 1)

                        if !instructionText.isEmpty {
                            Text(instructionText)
                                .font(.system(size: isCompactCutscene ? 15 : 18, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.97))
                                .lineSpacing(isCompactCutscene ? 4 : 6)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if useVerticalButtons {
                            VStack(spacing: 10) {
                                cutsceneReplayButton(isCompactCutscene: isCompactCutscene)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                cutscenePrimaryActionButton(isCompactCutscene: isCompactCutscene)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            HStack(spacing: 10) {
                                cutsceneReplayButton(isCompactCutscene: isCompactCutscene)

                                Spacer()

                                cutscenePrimaryActionButton(isCompactCutscene: isCompactCutscene)
                            }
                        }
                    }
                    .padding(.horizontal, isCompactCutscene ? 14 : 18)
                    .padding(.top, isCompactCutscene ? 12 : 16)
                    .padding(.bottom, isCompactCutscene ? 10 : 14)
                    .frame(maxWidth: min(size.width - (horizontalPadding * 2), 1500), alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, overlayBottomPadding)
                }
            }
        }
        .onAppear { setupPlayerIfNeeded() }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private func cutsceneReplayButton(isCompactCutscene: Bool) -> some View {
        Button {
            player?.seek(to: .zero)
            player?.play()
        } label: {
            Label("Replay", systemImage: "gobackward")
                .font(.system(size: isCompactCutscene ? 13 : 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(failedToLoad)
        .opacity(failedToLoad ? 0.5 : 1)
    }

    @ViewBuilder
    private func cutscenePrimaryActionButton(isCompactCutscene: Bool) -> some View {
        if !isCompleted {
            Button {
                onMarkComplete()
            } label: {
                Label("Finish Cutscene", systemImage: "checkmark.circle.fill")
                    .font(.system(size: isCompactCutscene ? 13 : 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.pink.opacity(0.92), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isTyping)
            .opacity(isTyping ? 0.55 : 1)
        } else {
            Button {
                onContinue()
            } label: {
                Label("Continue Story", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: isCompactCutscene ? 13 : 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.green.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
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

struct MiniGameStageCharacterPanel: View {
    let speaker: String
    let subtitle: String?
    let emotion: Emotion
    let characterImageName: String
    let instructionText: String
    let isTyping: Bool
    let layout: DialogAdaptiveLayout
    let accentColor: Color
    let onSkipTyping: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker)
                        .font(.system(size: layout.bodyFontSize, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(instructionText.isEmpty ? "..." : instructionText)
                        .font(.system(size: layout.captionFontSize + 1, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)

                if isTyping {
                    Button(action: onSkipTyping) {
                        Text("Skip")
                            .font(.system(size: layout.captionFontSize, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            Image(characterImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(color: accentColor.opacity(0.18), radius: 18, x: 0, y: 10)

            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                Text(emotion.rawValue.capitalized)
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.35), in: Capsule())
        }
        .padding(12)
        .background(Color(hex: "1C222B"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

struct MiniGameBottomBar: View {
    let instructionText: String
    let continueTitle: String
    let isContinueEnabled: Bool
    let layout: DialogAdaptiveLayout
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: layout.elementSpacing) {
            Text(instructionText)
                .font(.system(size: layout.captionFontSize + 1, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: onContinue) {
                HStack(spacing: 8) {
                    Text(continueTitle)
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isContinueEnabled ? Color(hex: "3A475A") : Color(hex: "262C36"),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isContinueEnabled ? 0.18 : 0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!isContinueEnabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "1C222B"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

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
    enum Presentation {
        case card
        case showcasePhone
    }

    let minigame: PromptBuilderMiniGame
    let layout: DialogAdaptiveLayout
    let presentation: Presentation
    let isCompleted: Bool
    let onComplete: (String) -> Void

    @State private var selectedOptionBySlotID: [String: String] = [:]
    @State private var submitted = false
    @State private var submissionReviewText = ""

    init(
        minigame: PromptBuilderMiniGame,
        layout: DialogAdaptiveLayout,
        presentation: Presentation = .card,
        isCompleted: Bool,
        onComplete: @escaping (String) -> Void
    ) {
        self.minigame = minigame
        self.layout = layout
        self.presentation = presentation
        self.isCompleted = isCompleted
        self.onComplete = onComplete
    }

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .card:
            standardCardBody
        case .showcasePhone:
            showcasePhoneBody
        }
    }

    private var standardCardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(minigame.title)
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.white)
                    Text("Play inside a Messages-style screen and build a clear prompt.")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.68))
                }
                Spacer()
                Text("Messages Mini-game")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }

            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    messagesTopChrome

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            messageThreadSection
                            promptBuilderSection
                            composerSection
                            if submitted || isCompleted {
                                sentReceiptSection
                            }
                        }
                        .padding(12)
                    }
                    .background(Color(red: 0.95, green: 0.96, blue: 0.98))
                }
                .frame(maxWidth: 980)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 8)
                Spacer(minLength: 0)
            }

            if let tip = minigame.tip, !tip.isEmpty {
                Text(tip)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(Color(hex: "181D25"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var showcasePhoneBody: some View {
        VStack(spacing: 0) {
            showcaseMessagesTopChrome

            showcaseThreadArea

            showcaseComposerSection

            showcasePromptPaletteSection
        }
        .background(Color(red: 0.93, green: 0.94, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.96), lineWidth: 2.8)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 10)
    }

    private var messagesTopChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Text("9:41")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.75))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)

            HStack(spacing: 10) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.blue)

                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(minigame.contactName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                    Text("Unknown sender")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "video")
                    .foregroundColor(.blue)
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .background(Color.white)
        }
    }

    private var showcaseMessagesTopChrome: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Text("12:58 PM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black.opacity(0.70))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black.opacity(0.35))
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.black.opacity(0.65))
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.white)

            Divider()
                .overlay(Color.black.opacity(0.06))
        }
    }

    private var showcaseThreadArea: some View {
        Group {
            if layout.width < 980 {
                VStack(spacing: 0) {
                    showcaseThreadListPane
                        .frame(height: 128)

                    Divider()
                        .overlay(Color.black.opacity(0.08))

                    showcaseChatPane
                        .frame(height: layout.height < 760 ? 190 : 230)
                }
            } else {
                HStack(spacing: 0) {
                    showcaseThreadListPane
                        .frame(width: 290)

                    Divider()
                        .overlay(Color.black.opacity(0.08))

                    showcaseChatPane
                }
                .frame(height: layout.height < 760 ? 230 : 280)
            }
        }
        .background(Color.white)
    }

    private var showcaseThreadListPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                Text("Messages")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.82))

                Spacer()

                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(showcaseListRows.enumerated()), id: \.offset) { index, row in
                        showcaseThreadListRow(row: row, index: index)
                    }
                }
            }
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98))
    }

    private struct ShowcaseThreadRow {
        let name: String
        let preview: String
        let timestamp: String
        let isSelected: Bool
        let accent: Color
    }

    private var showcaseListRows: [ShowcaseThreadRow] {
        [
            ShowcaseThreadRow(
                name: minigame.contactName,
                preview: "Thanks!!",
                timestamp: "12:58 PM",
                isSelected: true,
                accent: Color(hex: "B6BCC6")
            ),
            ShowcaseThreadRow(
                name: "Laura Staley",
                preview: "I'm 2 episodes in and I like it...",
                timestamp: "12:57 PM",
                isSelected: false,
                accent: Color(hex: "D28A82")
            ),
            ShowcaseThreadRow(
                name: "Mary Elliott",
                preview: "Got it - thanks for letting me know!",
                timestamp: "Yesterday",
                isSelected: false,
                accent: Color(hex: "8FAF7A")
            ),
            ShowcaseThreadRow(
                name: "Kate Spalla",
                preview: "Ah, I'm trying to plan something else...",
                timestamp: "Yesterday",
                isSelected: false,
                accent: Color(hex: "B779B7")
            )
        ]
    }

    private func showcaseThreadListRow(row: ShowcaseThreadRow, index: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(row.accent.opacity(0.95))
                .frame(width: 28, height: 28)
                .overlay(
                    Group {
                        if row.isSelected {
                            Image(systemName: "questionmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(String(row.name.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(row.timestamp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Text(row.preview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            row.isSelected
                ? Color.black.opacity(0.05)
                : (index.isMultiple(of: 2) ? Color.white.opacity(0.01) : Color.clear)
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var showcaseChatPane: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Text(minigame.contactName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.84))
                Spacer(minLength: 0)
                Text("Details")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))

            Divider()
                .overlay(Color.black.opacity(0.06))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Text Message")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                        Text("Today 12:58 PM")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.92))
                    }
                    .padding(.top, 4)

                    HStack {
                        Text("Hey")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "E9E9EE"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Spacer()
                    }

                    HStack {
                        Text(minigame.introMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.80))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color(hex: "E9E9EE"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Spacer(minLength: 46)
                    }

                    HStack {
                        Spacer(minLength: 46)
                        Text(canSubmit ? promptPreview : "Tap the colored blocks below to build your reply...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(canSubmit ? .white : Color.black.opacity(0.66))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                canSubmit ? Color(hex: "2AD160") : Color(hex: "DCE0E7"),
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                    }

                    if submitted || isCompleted {
                        showcaseSentReceiptSection
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color.white)
        }
    }

    private var messageThreadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white, in: Capsule())
                Spacer()
            }

            HStack {
                Text(minigame.introMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.84))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 40)
            }

            HStack {
                Spacer(minLength: 40)
                Text(canSubmit ? promptPreview : "Tap choices below to build your reply...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(canSubmit ? .white : Color.black.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        canSubmit ? Color(red: 0.07, green: 0.51, blue: 1.0) : Color(red: 0.88, green: 0.90, blue: 0.93),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
        .padding(12)
        .background(Color(red: 0.90, green: 0.93, blue: 0.97), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var promptBuilderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Build Your Prompt")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black.opacity(0.85))
                Spacer()
                Text("Goal + Context + Action + Format")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue.opacity(0.85))
            }

            ForEach(minigame.slots) { slot in
                promptSlotSection(slot)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var showcasePromptPaletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build the Reply")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black.opacity(0.80))
                    Text("Goal + Context + Action + Format")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black.opacity(0.55))
                }

                Spacer(minLength: 0)

                Text(canSubmit ? "Ready to Send" : "Pick 4 Blocks")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(canSubmit ? Color(hex: "0E8A3D") : Color.black.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: showcasePaletteColumns, spacing: 12) {
                    ForEach(Array(minigame.slots.enumerated()), id: \.element.id) { index, slot in
                        showcasePromptSlotCard(slot, index: index)
                    }
                }

                if let tip = minigame.tip, !tip.isEmpty {
                    Text(tip)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Color.clear
                    .frame(height: 2)
            }
            .frame(maxHeight: layout.height < 760 ? 210 : 260)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color(hex: "C9CBD2"))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.8),
            alignment: .top
        )
    }

    private var showcasePaletteColumns: [GridItem] {
        let columnCount = layout.width > 1320 ? 4 : (layout.width > 980 ? 2 : 1)
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columnCount)
    }

    private func showcasePromptSlotCard(_ slot: PromptBuilderSlot, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(slot.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black.opacity(0.80))

                Spacer(minLength: 4)

                if let selected = selectedOption(for: slot) {
                    Text(selected.chipText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black.opacity(0.75))
                        .lineLimit(1)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                ForEach(slot.options) { option in
                    let isSelected = selectedOptionBySlotID[slot.id] == option.id

                    Button {
                        guard !isCompleted else { return }
                        selectedOptionBySlotID[slot.id] = option.id
                    } label: {
                        Text(option.chipText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .black.opacity(0.78))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(isSelected ? Color.black.opacity(0.68) : Color.white.opacity(0.84))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.42), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isCompleted)
                }
            }
        }
        .padding(12)
        .background(showcaseSlotFillColor(for: index), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private func showcaseSlotFillColor(for index: Int) -> Color {
        let palette: [Color] = [
            Color(hex: "8ED0F7"),
            Color(hex: "91F0C3"),
            Color(hex: "F5E08F"),
            Color(hex: "BE93F5")
        ]
        return palette[index % palette.count]
    }

    private func promptSlotSection(_ slot: PromptBuilderSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(slot.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black.opacity(0.82))
                Spacer()
                if let selected = selectedOption(for: slot) {
                    Text(selected.chipText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.08), in: Capsule())
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(slot.options) { option in
                    let isSelected = selectedOptionBySlotID[slot.id] == option.id
                    Button {
                        guard !isCompleted else { return }
                        selectedOptionBySlotID[slot.id] = option.id
                    } label: {
                        Text(option.chipText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .black.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color(red: 0.07, green: 0.51, blue: 1.0) : Color(red: 0.94, green: 0.95, blue: 0.97))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Color.blue.opacity(0.15) : Color.black.opacity(0.05), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isCompleted)
                }
            }
        }
    }

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reply Preview")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text(canSubmit ? promptPreview : "Write a clearer prompt...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(canSubmit ? .black.opacity(0.85) : .gray)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

                Button {
                    submitPrompt()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor((canSubmit && !isCompleted) ? Color.blue : Color.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isCompleted)
            }
        }
    }

    private var showcaseComposerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray.opacity(0.85))
                .frame(width: 26, height: 26)

            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.65))

                Text(canSubmit ? promptPreview : "Text Message")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(canSubmit ? .black.opacity(0.82) : .gray)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            Button {
                submitPrompt()
            } label: {
                Text("Send")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor((canSubmit && !isCompleted) ? .blue : .gray)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isCompleted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(height: 0.8),
            alignment: .top
        )
    }

    @ViewBuilder
    private var sentReceiptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Message Sent", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
            }

            Text("You can continue the story now. Review note is shown below the mini-game screen.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black.opacity(0.72))

            if !submissionReviewText.isEmpty {
                Text(submissionReviewText)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var showcaseSentReceiptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "25B44B"))
                Text("Message Sent")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black.opacity(0.82))
            }

            Text(submissionReviewText.isEmpty ? "You can continue the story now." : submissionReviewText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.black.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color(hex: "EEF8EF"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "CDEDD4"), lineWidth: 1)
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
        submissionReviewText = summary
        onComplete(summary)
    }
}

struct PromptBuilderMessagesMiniGameStage: View {
    let minigame: PromptBuilderMiniGame
    let layout: DialogAdaptiveLayout
    let availableWidth: CGFloat
    let availableHeight: CGFloat
    let speaker: String
    let roleLabel: String?
    let emotion: Emotion
    let characterImageName: String
    let instructionText: String
    let isTyping: Bool
    let isCompleted: Bool
    let onSkipTyping: () -> Void
    let onContinue: () -> Void
    let onComplete: (String) -> Void

    private var usesStackedLayout: Bool {
        availableWidth < 1120 || availableHeight < 760
    }

    private var heroPanelWidth: CGFloat {
        max(min(availableWidth * 0.32, 410), 250)
    }

    private var phonePanelWidth: CGFloat {
        min(max(availableWidth * 0.64, 520), 980)
    }

    private var phoneWideUpOffset: CGFloat {
        min(max(availableHeight * 0.12, 64), 150)
    }

    private var heroMinHeight: CGFloat {
        min(max(availableHeight * 0.48, 250), 430)
    }

    private var heroImageHeight: CGFloat {
        min(max(availableHeight * (usesStackedLayout ? 0.30 : 0.56), 200), usesStackedLayout ? 300 : 520)
    }

    private var wideStageMaxWidth: CGFloat {
        min(availableWidth, layout.isCompact ? 900 : 1480)
    }

    private var wideCenterPhoneWidth: CGFloat {
        min(phonePanelWidth, layout.width < 1280 ? 840 : 940)
    }

    private var wideCharacterSpriteHeight: CGFloat {
        min(max(availableHeight * 0.46, 280), 520)
    }

    private var wideCharacterHorizontalPush: CGFloat {
        if availableWidth < 1200 { return 12 }
        if availableWidth < 1450 { return 24 }
        return 38
    }

    private var wideBottomDialogReserve: CGFloat {
        layout.isCompact ? 178 : 210
    }

    private var wideDialogVerticalLift: CGFloat {
        layout.isCompact ? 26 : 34
    }

    private var instructionTextColor: Color {
        .white.opacity(isTyping ? 0.92 : 0.86)
    }

    private var emotionAccent: Color {
        switch emotion {
        case .happy, .excited:
            return Color(hex: "5CE38C")
        case .sad, .concerned:
            return Color(hex: "8ED0F7")
        case .angry:
            return Color(hex: "FF7D7D")
        case .mysterious:
            return Color(hex: "BE93F5")
        case .surprised:
            return Color(hex: "FFD77A")
        case .gentle:
            return Color(hex: "91F0C3")
        case .curious:
            return Color(hex: "4AB0FF")
        case .neutral:
            return Color.white.opacity(0.85)
        }
    }

    var body: some View {
        ZStack {
            if usesStackedLayout {
                bottomSceneFade
            }

            if usesStackedLayout {
                VStack(spacing: 12) {
                    phonePanel
                        .frame(maxWidth: min(availableWidth, 920))

                    heroPanel
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: heroMinHeight)
                }
            } else {
                professorStylePromptStage
            }

            if isCompleted {
                VStack {
                    Spacer(minLength: 0)
                    if usesStackedLayout {
                        Button(action: onContinue) {
                            Label("Continue Story", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: layout.isCompact ? 14 : 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.92), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var phonePanel: some View {
        PromptBuilderMiniGameCard(
            minigame: minigame,
            layout: layout,
            presentation: .showcasePhone,
            isCompleted: isCompleted,
            onComplete: onComplete
        )
        .allowsHitTesting(!isTyping)
        .opacity(isTyping ? 0.88 : 1.0)
    }

    private var professorStylePromptStage: some View {
        ZStack {
            wideCharacterLayer

            VStack(spacing: layout.isCompact ? 6 : 8) {
                wideTopUtilityRow

                VStack(spacing: 0) {
                    Spacer(minLength: layout.isCompact ? 8 : 12)

                    phonePanel
                        .frame(width: wideCenterPhoneWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(y: -phoneWideUpOffset)

                    Spacer(minLength: wideBottomDialogReserve)
                }
            }
            .frame(maxWidth: wideStageMaxWidth, maxHeight: .infinity, alignment: .top)

            wideBottomGradientOverlay

            VStack(spacing: layout.isCompact ? 8 : 10) {
                Spacer()

                promptBottomDialogPane(
                    name: speaker.isEmpty ? "You" : speaker,
                    role: roleLabel ?? emotion.rawValue.capitalized,
                    text: instructionText.isEmpty ? "Build a clear reply before sending it in the chat." : instructionText,
                    accent: emotionAccent
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                if isCompleted {
                    Button(action: onContinue) {
                        Label("Continue Story", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: layout.isCompact ? 14 : 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.92), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: wideStageMaxWidth, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .padding(.bottom, wideDialogVerticalLift)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wideCharacterLayer: some View {
        HStack {
            Image(characterImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: min(wideStageMaxWidth * 0.26, 360), maxHeight: wideCharacterSpriteHeight, alignment: .bottom)
                .offset(x: -wideCharacterHorizontalPush, y: -12)
                .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
                .allowsHitTesting(false)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: wideStageMaxWidth, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, layout.isCompact ? 6 : 10)
        .padding(.bottom, max(0, wideBottomDialogReserve - 22))
    }

    private var wideTopUtilityRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(emotionAccent)
                    .frame(width: 8, height: 8)
                Text(roleLabel ?? emotion.rawValue.capitalized)
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.34), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            Text("iPhone Messages Mini-game")
                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.24), in: Capsule())

            Spacer(minLength: 8)

            if isTyping {
                Button(action: onSkipTyping) {
                    Label("Skip Text", systemImage: "forward.fill")
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var wideBottomGradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.58),
                .init(color: Color.black.opacity(0.12), location: 0.66),
                .init(color: Color.black.opacity(0.34), location: 0.78),
                .init(color: Color.black.opacity(0.62), location: 0.90),
                .init(color: Color.black.opacity(0.82), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func promptBottomDialogPane(
        name: String,
        role: String,
        text: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: layout.isCompact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.system(size: layout.isCompact ? 20 : 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 2)

                Text(role)
                    .font(.system(size: layout.isCompact ? 12 : 15, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 1)

                Spacer(minLength: 0)
            }

            Text(text)
                .font(.system(size: layout.isCompact ? 13 : 17, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.97))
                .lineSpacing(layout.isCompact ? 3 : 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(5)
                .minimumScaleFactor(0.85)
                .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 2)
        }
        .padding(.leading, layout.isCompact ? 0 : 2)
        .padding(.trailing, layout.isCompact ? 12 : 26)
        .padding(.vertical, layout.isCompact ? 2 : 4)
    }

    private var heroPanel: some View {
        ZStack(alignment: .bottomLeading) {
            if isTyping {
                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: onSkipTyping) {
                            Label("Skip Text", systemImage: "forward.fill")
                                .font(.system(size: layout.captionFontSize, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .zIndex(4)
            }

            Image(characterImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: heroImageHeight, alignment: .bottomLeading)
                .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)
                .zIndex(1)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.black.opacity(0.14), location: 0.42),
                        .init(color: Color.black.opacity(0.46), location: 0.72),
                        .init(color: Color.black.opacity(0.82), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: usesStackedLayout ? 160 : 210)
            }
            .allowsHitTesting(false)
            .zIndex(2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(speaker.isEmpty ? "You" : speaker)
                        .font(.system(size: layout.isCompact ? 23 : 30, weight: .heavy))
                        .foregroundColor(.white)

                    if let roleLabel, !roleLabel.isEmpty {
                        Text(" [\(roleLabel)]")
                            .font(.system(size: layout.isCompact ? 18 : 22, weight: .bold))
                            .foregroundColor(Color(hex: "2DA6FF"))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: min(220, max(120, heroPanelWidth * 0.66)), height: 2)
                    .overlay(
                        Rectangle()
                            .fill(emotionAccent)
                            .frame(width: min(62, max(28, heroPanelWidth * 0.18)), height: 2),
                        alignment: .trailing
                    )

                Text(instructionText.isEmpty ? "Build a clear reply before sending." : instructionText)
                    .font(.system(size: layout.isCompact ? 16 : 20, weight: .bold))
                    .foregroundColor(instructionTextColor)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
            .zIndex(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .clipped()
    }

    private var bottomSceneFade: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.black.opacity(0.08), location: 0.36),
                    .init(color: Color.black.opacity(0.24), location: 0.7),
                    .init(color: Color.black.opacity(0.42), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: usesStackedLayout ? 110 : 150)
        }
        .allowsHitTesting(false)
    }
}

struct ClassroomLectureQuizMiniGameStage: View {
    let quiz: LectureQuizMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let isTyping: Bool
    let instructionText: String
    let onSkipTyping: () -> Void
    let onComplete: (String) -> Void
    let onContinue: () -> Void

    @StateObject private var speechManager = SpeechManager()
    @StateObject private var playerSpeechManager = SpeechManager()
    @State private var currentQuestionIndex = 0
    @State private var selectedChoiceIDByQuestionID: [String: String] = [:]
    @State private var completionSubmitted = false
    @State private var professorTypingTask: Task<Void, Never>?
    @State private var professorSpeechTask: Task<Void, Never>?
    @State private var professorTypedText = ""
    @State private var professorTypingQuestionID: String?
    @State private var professorTypingCompletedQuestionIDs: Set<String> = []
    @State private var pulsingChoiceID: String?
    @State private var hiddenQuestionChoicePanelQuestionIDs: Set<String> = []
    @State private var shuffledChoicesByQuestionID: [String: [LectureQuizOption]] = [:]

    private var questions: [LectureQuizQuestion] {
        quiz.questions.isEmpty
            ? [
                LectureQuizQuestion(
                    id: "fallback",
                    question: "No question available",
                    choices: []
                )
            ]
            : quiz.questions
    }

    private var clampedQuestionIndex: Int {
        min(max(currentQuestionIndex, 0), max(questions.count - 1, 0))
    }

    private var currentQuestion: LectureQuizQuestion {
        questions[clampedQuestionIndex]
    }

    private func displayChoices(for question: LectureQuizQuestion) -> [LectureQuizOption] {
        shuffledChoicesByQuestionID[question.id] ?? question.choices
    }

    private var totalQuestions: Int {
        max(questions.count, 1)
    }

    private var answeredCount: Int {
        questions.filter { selectedChoiceIDByQuestionID[$0.id] != nil }.count
    }

    private var bestAnswerCount: Int {
        questions.reduce(into: 0) { count, question in
            guard let selectedID = selectedChoiceIDByQuestionID[question.id],
                  let selected = question.choices.first(where: { $0.id == selectedID }),
                  selected.isBestAnswer else {
                return
            }
            count += 1
        }
    }

    private var currentSelectedChoice: LectureQuizOption? {
        guard let selectedID = selectedChoiceIDByQuestionID[currentQuestion.id] else { return nil }
        return currentQuestion.choices.first(where: { $0.id == selectedID })
    }

    private var isCurrentQuestionAnswered: Bool {
        currentSelectedChoice != nil
    }

    private var isLastQuestion: Bool {
        clampedQuestionIndex >= (questions.count - 1)
    }

    private var isProfessorTypingCurrentQuestion: Bool {
        professorTypingQuestionID == currentQuestion.id && !professorTypingCompletedQuestionIDs.contains(currentQuestion.id)
    }

    private var hasProfessorFeedbackCompletedCurrentQuestion: Bool {
        guard isCurrentQuestionAnswered else { return true }
        return professorTypingCompletedQuestionIDs.contains(currentQuestion.id)
    }

    private var shouldHideQuestionChoices: Bool {
        isCurrentQuestionAnswered && hiddenQuestionChoicePanelQuestionIDs.contains(currentQuestion.id)
    }

    private var canGoNext: Bool {
        isCurrentQuestionAnswered && hasProfessorFeedbackCompletedCurrentQuestion && !isCompleted && !isLastQuestion
    }

    private var canFinishQuiz: Bool {
        isCurrentQuestionAnswered && hasProfessorFeedbackCompletedCurrentQuestion && !isCompleted && isLastQuestion
    }

    private var teacherDisplayName: String {
        quiz.teacherName.isEmpty ? "Professor New" : quiz.teacherName
    }

    private var teacherRole: String {
        (quiz.teacherRole?.isEmpty == false ? quiz.teacherRole! : "Teacher")
    }

    private var studentDisplayName: String {
        quiz.studentName.isEmpty ? "You" : quiz.studentName
    }

    private var studentRole: String {
        (quiz.studentRole?.isEmpty == false ? quiz.studentRole! : "Student")
    }

    private var teacherDialogText: String {
        if let selected = currentSelectedChoice {
            if isProfessorTypingCurrentQuestion {
                return professorTypedText.isEmpty ? "..." : professorTypedText
            }
            return selected.feedback
        }
        if isTyping && !instructionText.isEmpty {
            return instructionText
        }
        if clampedQuestionIndex == 0, answeredCount == 0, !instructionText.isEmpty {
            return instructionText
        }
        return "Question \(clampedQuestionIndex + 1): \(currentQuestion.question)"
    }

    private var studentDialogText: String {
        if let selected = currentSelectedChoice {
            return "My answer: \(selected.text)"
        }
        if isTyping {
            return "..."
        }
        return "I should choose the safest and most responsible answer."
    }

    private var stageMaxWidth: CGFloat {
        min(layout.width - (layout.isCompact ? 12 : 24), layout.isCompact ? 760 : 1500)
    }

    private var centerPanelMaxWidth: CGFloat {
        switch true {
        case layout.width < 700:
            return min(layout.width - 24, 700)
        case layout.width < 1100:
            return min(layout.width * 0.72, 820)
        default:
            return min(layout.width * 0.52, 860)
        }
    }

    private var spriteHeight: CGFloat {
        let lowerBound: CGFloat = layout.isCompact ? 205 : 265
        let upperBound: CGFloat = layout.isCompact ? 350 : 610
        return min(max(layout.height * (layout.isCompact ? 0.33 : 0.47), lowerBound), upperBound)
    }

    private var dialogVerticalLift: CGFloat {
        if layout.width < 780 {
            return layout.isCompact ? 68 : 82
        }
        return layout.isCompact ? 84 : 110
    }

    private var characterHorizontalPush: CGFloat {
        if layout.width < 700 { return 22 }
        if layout.width < 1000 { return 36 }
        return layout.isCompact ? 48 : 76
    }

    private var characterBottomOffsetAdjustment: CGFloat {
        layout.isCompact ? 28 : 34
    }

    private var characterVerticalLift: CGFloat {
        layout.isCompact ? 14 : 22
    }

    private var bottomDialogReserve: CGFloat {
        layout.width < 780 ? (layout.isCompact ? 264 : 286) : (layout.isCompact ? 220 : 256)
    }

    private var showsSkipTypingButton: Bool {
        isTyping || isProfessorTypingCurrentQuestion
    }

    var body: some View {
        ZStack {
            characterLayer

            VStack(spacing: layout.isCompact ? 6 : 8) {
                topUtilityRow

                VStack(spacing: 0) {
                    Spacer(minLength: layout.isCompact ? 8 : 12)

                    centerQuizPanel
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: bottomDialogReserve)
                }
            }
            .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .top)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.58),
                    .init(color: Color.black.opacity(0.22), location: 0.66),
                    .init(color: Color.black.opacity(0.48), location: 0.78),
                    .init(color: Color.black.opacity(0.78), location: 0.90),
                    .init(color: Color.black.opacity(0.94), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, -(layout.dialogPadding + (layout.isCompact ? 18 : 28)))
            .allowsHitTesting(false)

            VStack(spacing: layout.isCompact ? 8 : 10) {
                Spacer()

                HStack(alignment: .top, spacing: layout.isCompact ? 12 : 18) {
                    bottomDialogPane(
                        name: studentDisplayName,
                        role: studentRole,
                        text: studentDialogText,
                        accent: .cyan,
                        alignTrailing: false
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    bottomDialogPane(
                        name: teacherDisplayName,
                        role: teacherRole,
                        text: teacherDialogText,
                        accent: .mint,
                        alignTrailing: true
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if isCompleted {
                    Button {
                        onContinue()
                    } label: {
                        Label("Continue Story", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: layout.isCompact ? 14 : 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.92), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: stageMaxWidth, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .padding(.bottom, dialogVerticalLift)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            prepareShuffledChoicesIfNeeded()
        }
        .onDisappear {
            professorTypingTask?.cancel()
            professorTypingTask = nil
            professorSpeechTask?.cancel()
            professorSpeechTask = nil
            speechManager.stop()
            playerSpeechManager.stop()
        }
    }

    private var characterLayer: some View {
        ZStack(alignment: .bottom) {
            if let studentImageName = quiz.studentImageName, !studentImageName.isEmpty {
                HStack {
                    classroomCharacterImage(
                        named: studentImageName,
                        align: .leading
                    )
                    Spacer(minLength: 0)
                }
            }

            if let teacherImageName = quiz.teacherImageName, !teacherImageName.isEmpty {
                HStack {
                    Spacer(minLength: 0)
                    classroomCharacterImage(
                        named: teacherImageName,
                        align: .trailing
                    )
                }
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, layout.isCompact ? 6 : 10)
        .padding(.bottom, max(0, bottomDialogReserve - characterBottomOffsetAdjustment))
    }

    private enum ClassroomCharacterAlign {
        case leading
        case trailing
    }

    private func classroomCharacterImage(named imageName: String, align: ClassroomCharacterAlign) -> some View {
        let isNarrowStage = layout.width < 900
        let widthMultiplier: CGFloat
        let widthCap: CGFloat

        if isNarrowStage {
            widthMultiplier = align == .trailing ? 0.43 : 0.41
            widthCap = align == .trailing ? 270 : 255
        } else {
            widthMultiplier = align == .trailing ? 0.36 : 0.34
            widthCap = align == .trailing ? 430 : 400
        }

        return Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(
                maxWidth: min(layout.width * widthMultiplier, widthCap),
                maxHeight: spriteHeight,
                alignment: .bottom
            )
            .offset(
                x: align == .leading ? -characterHorizontalPush : characterHorizontalPush,
                y: -characterVerticalLift
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
            .allowsHitTesting(false)
    }

    private var topUtilityRow: some View {
        HStack(spacing: 10) {
            Text("Question \(clampedQuestionIndex + 1) / \(totalQuestions)")
                .font(.system(size: layout.captionFontSize + 2, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.34), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Text("Professor New Class Quiz")
                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.24), in: Capsule())

            Spacer(minLength: 8)

            if showsSkipTypingButton {
                Button(action: handleSkipTyping) {
                    Label("Skip Text", systemImage: "forward.fill")
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var centerQuizPanel: some View {
        VStack(spacing: layout.isCompact ? 10 : 12) {
            if shouldHideQuestionChoices {
                VStack(spacing: layout.isCompact ? 8 : 10) {
                    if isProfessorTypingCurrentQuestion {
                        HStack(spacing: 8) {
                            TypingIndicator(layout: layout)
                            Text("\(teacherDisplayName) is replying...")
                                .font(.system(size: layout.captionFontSize + 1, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Professor feedback complete.")
                            .font(.system(size: layout.captionFontSize + 1, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.86))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: layout.isCompact ? 42 : 52)
                .transition(.opacity)
            } else {
                questionCard

                VStack(spacing: 10) {
                    ForEach(displayChoices(for: currentQuestion)) { choice in
                        optionButton(choice)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if canGoNext || canFinishQuiz {
                Button {
                    if canGoNext {
                        goToNextQuestion()
                    } else if canFinishQuiz {
                        submitQuizIfNeeded()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(canFinishQuiz ? "Finish Quiz" : "Next Question")
                        Image(systemName: canFinishQuiz ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    }
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.isCompact ? 11 : 13)
                    .background(
                        LinearGradient(
                            colors: canFinishQuiz
                                ? [Color.green.opacity(0.95), Color.mint.opacity(0.9)]
                                : [Color.blue.opacity(0.95), Color.cyan.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(completionSubmitted)
                .opacity(completionSubmitted ? 0.65 : 1)
                .padding(.top, 2)
            } else if isCompleted {
                Text("Quiz complete. Read Professor New's feedback below, then continue.")
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if completionSubmitted {
                Text("Recording your quiz result...")
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if shouldHideQuestionChoices {
                Text(isProfessorTypingCurrentQuestion ? "Wait for Professor New's reply..." : "Choose Next when you are ready.")
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: centerPanelMaxWidth)
        .padding(.top, 0)
        .animation(.easeInOut(duration: 0.22), value: shouldHideQuestionChoices)
        .animation(.easeInOut(duration: 0.18), value: isProfessorTypingCurrentQuestion)
    }

    private var questionCard: some View {
        VStack(spacing: 8) {
            Text("QUESTION")
                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.75))
                .tracking(0.8)

            Text(currentQuestion.question)
                .font(.system(size: layout.isCompact ? 15 : 18, weight: .medium, design: .rounded))
                .foregroundColor(Color.black.opacity(0.88))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, layout.isCompact ? 14 : 18)
        .padding(.vertical, layout.isCompact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
    }

    private func optionButton(_ choice: LectureQuizOption) -> some View {
        let selectedID = selectedChoiceIDByQuestionID[currentQuestion.id]
        let isSelected = selectedID == choice.id
        let isDisabled = isTyping || isCompleted || selectedID != nil
        let isResultReveal = selectedID != nil
        let isCorrect = choice.isBestAnswer
        let isWrong = !choice.isBestAnswer
        let isPulsing = pulsingChoiceID == choice.id

        let fillColor: Color = {
            guard isResultReveal else {
                return isSelected ? Color.cyan.opacity(0.30) : Color.white.opacity(0.88)
            }
            if isCorrect {
                return isSelected ? Color.green.opacity(0.34) : Color.green.opacity(0.20)
            }
            if isWrong {
                return isSelected ? Color.red.opacity(0.30) : Color.red.opacity(0.16)
            }
            return Color.white.opacity(0.88)
        }()

        let strokeColor: Color = {
            guard isResultReveal else {
                return isSelected ? Color.cyan.opacity(0.95) : Color.black.opacity(0.05)
            }
            return isCorrect ? Color.green.opacity(0.95) : Color.red.opacity(0.86)
        }()

        let textColor: Color = isResultReveal
            ? Color.black.opacity(isSelected ? 0.94 : 0.88)
            : Color.black.opacity(0.86)

        return Button {
            select(choice)
        } label: {
            HStack(spacing: 10) {
                Text(choice.text)
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if isResultReveal {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: layout.isCompact ? 16 : 18, weight: .bold))
                        .foregroundColor(isCorrect ? Color.green.opacity(0.95) : Color.red.opacity(0.92))
                        .transition(.scale.combined(with: .opacity))
                } else if isSelected {
                    Image(systemName: "sparkles")
                        .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, layout.isCompact ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                strokeColor,
                                lineWidth: isSelected || isResultReveal ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isPulsing
                    ? (isCorrect ? Color.green.opacity(0.30) : Color.red.opacity(0.28))
                    : Color.black.opacity(0.06),
                radius: isPulsing ? 12 : 4,
                x: 0,
                y: isPulsing ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.92 : 1)
        .scaleEffect(isPulsing ? 1.035 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.68), value: pulsingChoiceID)
        .animation(.easeInOut(duration: 0.2), value: selectedID)
    }

    private func bottomDialogPane(
        name: String,
        role: String,
        text: String,
        accent: Color,
        alignTrailing: Bool
    ) -> some View {
        let edgeInset = layout.isCompact ? 0 : 2
        let middleInset = layout.isCompact ? 14 : 26

        return VStack(alignment: .leading, spacing: layout.isCompact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if alignTrailing { Spacer(minLength: 0) }

                Text(name)
                    .font(.system(size: layout.isCompact ? 20 : 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 2)

                Text(role)
                    .font(.system(size: layout.isCompact ? 12 : 15, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 1)

                if !alignTrailing { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)

            Text(text)
                .font(.system(size: layout.isCompact ? 13 : 17, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.97))
                .lineSpacing(layout.isCompact ? 3 : 5)
                .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
                .multilineTextAlignment(alignTrailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(5)
                .minimumScaleFactor(0.85)
                .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 2)
        }
        .padding(.leading, CGFloat(alignTrailing ? middleInset : edgeInset))
        .padding(.trailing, CGFloat(alignTrailing ? edgeInset : middleInset))
        .padding(.vertical, layout.isCompact ? 2 : 4)
    }

    private func select(_ choice: LectureQuizOption) {
        guard !isTyping, !isCompleted else { return }
        guard selectedChoiceIDByQuestionID[currentQuestion.id] == nil else { return }

        let questionID = currentQuestion.id

        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
            selectedChoiceIDByQuestionID[questionID] = choice.id
            pulsingChoiceID = choice.id
        }

        let playerReply = "My answer: \(choice.text)"
        playerSpeechManager.speak(playerReply, emotion: .neutral, voiceProfile: .playerFemale)

        startProfessorTyping(feedback: choice.feedback, for: questionID)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard selectedChoiceIDByQuestionID[questionID] != nil else { return }
            _ = withAnimation(.easeInOut(duration: 0.2)) {
                hiddenQuestionChoicePanelQuestionIDs.insert(questionID)
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeOut(duration: 0.18)) {
                if pulsingChoiceID == choice.id {
                    pulsingChoiceID = nil
                }
            }
        }
    }

    private func goToNextQuestion() {
        guard canGoNext else { return }
        professorTypingTask?.cancel()
        professorTypingTask = nil
        professorSpeechTask?.cancel()
        professorSpeechTask = nil
        professorTypedText = ""
        professorTypingQuestionID = nil
        speechManager.stop()
        playerSpeechManager.stop()
        currentQuestionIndex = min(currentQuestionIndex + 1, max(questions.count - 1, 0))
    }

    private func handleSkipTyping() {
        if isProfessorTypingCurrentQuestion {
            skipProfessorTyping()
        } else {
            onSkipTyping()
        }
    }

    private func startProfessorTyping(feedback: String, for questionID: String) {
        professorTypingTask?.cancel()
        professorSpeechTask?.cancel()
        professorTypingQuestionID = questionID
        professorTypedText = ""
        professorTypingCompletedQuestionIDs.remove(questionID)
        professorSpeechTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled, professorTypingQuestionID == questionID else { return }
            speechManager.speak(feedback, emotion: .neutral, voiceProfile: .professorMale)
        }

        professorTypingTask = Task { @MainActor in
            let chars = Array(feedback)

            for (index, char) in chars.enumerated() {
                if Task.isCancelled { return }

                professorTypedText.append(char)

                if index >= chars.count - 1 { break }

                var delayNanoseconds: UInt64 = 22_000_000
                if [".", "!", "?"].contains(char) {
                    delayNanoseconds = 110_000_000
                } else if [",", ";", ":"].contains(char) {
                    delayNanoseconds = 70_000_000
                }

                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            guard !Task.isCancelled else { return }
            professorTypedText = feedback
            professorTypingCompletedQuestionIDs.insert(questionID)
            if professorTypingQuestionID == questionID {
                professorTypingQuestionID = nil
            }
            professorTypingTask = nil
            professorSpeechTask = nil
        }
    }

    private func skipProfessorTyping() {
        guard let questionID = professorTypingQuestionID,
              let selected = currentSelectedChoice,
              questionID == currentQuestion.id else {
            return
        }

        professorTypingTask?.cancel()
        professorTypingTask = nil
        professorSpeechTask?.cancel()
        professorSpeechTask = nil
        speechManager.stop()
        playerSpeechManager.stop()
        professorTypedText = selected.feedback
        professorTypingCompletedQuestionIDs.insert(questionID)
        professorTypingQuestionID = nil
    }

    private func prepareShuffledChoicesIfNeeded() {
        guard shuffledChoicesByQuestionID.isEmpty else { return }

        var next: [String: [LectureQuizOption]] = [:]
        for question in questions {
            next[question.id] = question.choices.shuffled()
        }
        shuffledChoicesByQuestionID = next
    }

    private func submitQuizIfNeeded() {
        guard canFinishQuiz, !completionSubmitted else { return }
        completionSubmitted = true

        let questionSummaries: [String] = questions.enumerated().compactMap { (index, question) -> String? in
            guard let selectedID = selectedChoiceIDByQuestionID[question.id],
                  let selected = question.choices.first(where: { $0.id == selectedID }) else {
                return nil
            }

            let bestChoice = question.choices.first(where: \.isBestAnswer)
            let bestCallout = selected.isBestAnswer
                ? "Best answer."
                : "Best answer: \(bestChoice?.text ?? "Review the explanation")."

            return "Q\(index + 1): \(selected.feedback) \(bestCallout)"
        }

        let summary =
            "Professor New reviewed \(answeredCount)/\(totalQuestions) questions. " +
            "Best answers: \(bestAnswerCount)/\(totalQuestions). " +
            questionSummaries.joined(separator: " ") +
            " \(quiz.summaryNote)"

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
        .background(Color(hex: "181D25"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Review")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                    .foregroundColor(.white)

                Text(selectedChoice.feedback)
                    .font(.system(size: layout.captionFontSize + 1))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                if let bestChoice = quiz.choices.first(where: \.isBestAnswer) {
                    Text(selectedChoice.isBestAnswer ? "You chose the best answer." : "Best answer: \(bestChoice.text)")
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.mint.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(quiz.summaryNote)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(hex: "11161D"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        } else if isCompleted {
            Text("Answer recorded. Review is ready.")
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
        let index = quiz.choices.firstIndex(where: { $0.id == choice.id }) ?? 0
        let letter = String(UnicodeScalar(65 + min(max(index, 0), 25))!)
        let baseFill = isSelected ? Color(hex: "2F6FED") : Color(hex: "242C38")

        return Button {
            select(choice)
        } label: {
            HStack(spacing: 12) {
                Text("\(letter))")
                    .font(.system(size: layout.bodyFontSize, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(width: 34, alignment: .leading)

                Text(choice.text)
                    .font(.system(size: layout.bodyFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .multilineTextAlignment(.leading)

                Spacer()

                if choice.isBestAnswer && (selectedChoiceID != nil || isCompleted) {
                    Text("Best")
                        .font(.system(size: layout.captionFontSize - 1, weight: .bold))
                        .foregroundColor(.white.opacity(isSelected ? 0.92 : 0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, layout.isCompact ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(isSelected ? 0.20 : 0.10), lineWidth: 1)
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
                    .fill(Color(hex: "232A33"))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isHovered ? 0.30 : 0.18), lineWidth: 1)
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
