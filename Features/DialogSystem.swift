import SwiftUI
import UIKit
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
        let persistedAIName = GlobalSettingsStore.shared.aiDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        storyVariables = ["ai_name": persistedAIName.isEmpty ? "Ploy" : persistedAIName]
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

    func setStoryVariable(_ key: String, value: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        let finalValue: String
        if trimmedKey == "ai_name" {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            finalValue = trimmedValue.isEmpty ? "Ploy" : String(trimmedValue.prefix(24))
            GlobalSettingsStore.shared.aiDisplayName = finalValue
        } else {
            finalValue = value
        }
        storyVariables[trimmedKey] = finalValue
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
    let showCompletionOverlay: Bool
    
    // Animation states
    @State private var characterScale: CGFloat = 1.0
    @State private var characterOffset: CGFloat = 0
    @State private var characterRotation: Double = 0
    @State private var isCharacterPressed = false
    @State private var showSettingsPanel = false
    @State private var settingsAINameDraft = "Ploy"
    @State private var dialogSpeed: Int = 1          // 1x, 2x, 3x
    @State private var isAutoSkipping = false
    @State private var autoSkipTask: Task<Void, Never>?
    @State private var showSkipMinigameConfirm = false
    @State private var backgroundOpacity: Double = 1.0
    @State private var characterPlacement: VNCharacterPlacement = .center
    @State private var sceneContentOpacity: Double = 1.0
    @State private var lastSceneVisualKey: String = ""
    
    init(
        nodes: [DialogNode],
        showBackButton: Bool = true,
        showSettings: Bool = true,
        chapterTopBarDropFactor: CGFloat = 0,
        onComplete: (() -> Void)? = nil,
        showCompletionOverlay: Bool = true
    ) {
        self.nodes = nodes
        self.showBackButton = showBackButton
        self.showSettings = showSettings
        self.chapterTopBarDropFactor = chapterTopBarDropFactor
        self.onComplete = onComplete
        self.showCompletionOverlay = showCompletionOverlay
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
        case .lectureQuiz, .promptBuilder, .biasDataAudit, .chapter3KNNRescue:
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
    
    private var chapterMusicEnabledBinding: Binding<Bool> {
        Binding(
            get: { globalSettings.musicEnabled },
            set: { globalSettings.musicEnabled = $0 }
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

    private func matchesSpeakerName(_ normalized: String, candidate: String) -> Bool {
        let normalizedCandidate = normalizedVoiceMatchText(candidate)
        guard !normalized.isEmpty, !normalizedCandidate.isEmpty else { return false }
        return normalized == normalizedCandidate
            || normalized.hasPrefix("\(normalizedCandidate) ")
            || normalized.hasSuffix(" \(normalizedCandidate)")
            || normalized.contains(" \(normalizedCandidate) ")
    }

    private func isAISpeaker(_ normalized: String) -> Bool {
        if normalized.isEmpty { return false }

        let configuredAIName = viewModel.storyVariables["ai_name"] ?? "Ploy"
        if matchesSpeakerName(normalized, candidate: configuredAIName) { return true }

        if normalized == "ai"
            || normalized.hasPrefix("ai ")
            || normalized == "ai friend"
            || normalized.hasPrefix("ai friend ")
            || (normalized.contains("ai") && normalized.contains("friend")) {
            return true
        }

        return matchesSpeakerName(normalized, candidate: "Ploy")
            || matchesSpeakerName(normalized, candidate: "AI Friend")
            || matchesSpeakerName(normalized, candidate: "Unknown User")
            || matchesSpeakerName(normalized, candidate: "Unknown Sender")
            || matchesSpeakerName(normalized, candidate: "unknow")
            || matchesSpeakerName(normalized, candidate: "Phone")
    }

    private func voiceProfile(for speaker: String) -> SpeechVoiceProfile {
        let normalized = normalizedVoiceMatchText(speaker)
        if isProfessorSpeaker(normalized) {
            return .professorMale
        }
        if isPlayerSpeaker(normalized) {
            return .playerFemale
        }
        if isAISpeaker(normalized) {
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

        let configuredAIName = viewModel.storyVariables["ai_name"] ?? "Ploy"
        let startsWithAICue =
            matchesSpeakerName(normalizedText, candidate: configuredAIName)
            || normalizedText == "ai friend"
            || normalizedText.hasPrefix("ai friend ")
            || normalizedText == "ai"
            || normalizedText.hasPrefix("ai ")
            || normalizedText == "ploy"
            || normalizedText.hasPrefix("ploy ")
            || normalizedText == "unknown user"
            || normalizedText.hasPrefix("unknown user ")
            || normalizedText == "unknown sender"
            || normalizedText.hasPrefix("unknown sender ")
            || normalizedText == "phone"
            || normalizedText.hasPrefix("phone ")

        if startsWithAICue {
            return .playerFemale
        }

        return voiceProfile(for: fallbackSpeaker)
    }

    private func shouldSpeakForSpeaker(_ speaker: String) -> Bool {
        let normalized = normalizedVoiceMatchText(speaker)
        return !isPlayerSpeaker(normalized)
    }

    private func speakCurrentNodeText() {
        guard let node = viewModel.currentNode else { return }
        let text = viewModel.resolvedText(for: node).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let speaker = viewModel.resolvedSpeaker(for: node)
        guard shouldSpeakForSpeaker(speaker) else { return }
        speechManager.speak(text, emotion: node.emotion, voiceProfile: voiceProfile(for: speaker))
    }

    private func handleSkipTypingAction() {
        let wasTyping = viewModel.isTyping
        speechManager.stop()
        viewModel.skipTyping()

        // If the user skips the typewriter animation, resume TTS for the now-visible line.
        if wasTyping {
            speakCurrentNodeText()
        }
    }

    private func handleAdvanceAction() {
        if viewModel.isTyping {
            speechManager.stop()
            viewModel.skipTyping()
            // Advancing while typing acts as "skip typing"; replay the full line TTS.
            speakCurrentNodeText()
            return
        }

        speechManager.stop()
        viewModel.advance()
    }

    private func handleSelectChoiceAction(_ choice: DialogChoice) {
        speechManager.stop()
        let responseText = viewModel.renderTemplate(choice.response).trimmingCharacters(in: .whitespacesAndNewlines)
        let currentSpeaker = viewModel.resolvedSpeaker(for: viewModel.currentNode)
        viewModel.selectChoice(choice)

        if !responseText.isEmpty, shouldSpeakForSpeaker(currentSpeaker) {
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
                stopAutoSkip()
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
            stopAutoSkip()
        }
        .onChange(of: viewModel.isTyping) { _, isTyping in
            if !isTyping, let node = viewModel.currentNode {
                let speaker = viewModel.resolvedSpeaker(for: node)
                let announcement = "\(speaker) says: \(viewModel.displayedText)"
                UIAccessibility.post(notification: .announcement, argument: announcement as NSString)
            }
        }
        .onChange(of: viewModel.showChoices) { _, showChoices in
            if showChoices {
                UIAccessibility.post(notification: .announcement, argument: "Choose a response" as NSString)
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

            // Skip minigame confirmation overlay
            if showSkipMinigameConfirm {
                skipMinigameOverlay(layout: layout)
                    .zIndex(90)
            }

            // Settings overlay
            if showSettingsPanel {
                settingsPanel(layout: layout)
            }

            // Completion overlay
            if showCompletionOverlay && viewModel.isCompleted {
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
        case .biasDataAudit(let minigame):
            biasDataAuditActivityScene(layout: layout, geometry: geometry, node: node, minigame: minigame)
        case .chapter3KNNRescue(let minigame):
            chapter3KNNRescueActivityScene(layout: layout, geometry: geometry, node: node, minigame: minigame)
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
            // Messenger/chat style (like Chapter 1's PromptBuilder)
            let horizontalPadding = layout.dialogPadding
            let useScrollStage = geometry.size.width < 1120 || geometry.size.height < 760
            let stageTopPadding: CGFloat = 12
            let stageBottomPadding = max(layout.safeAreaInsets.bottom, 12)
            let stageSpeaker = viewModel.resolvedSpeaker(for: node).isEmpty ? "You" : viewModel.resolvedSpeaker(for: node)
            let stageRoleLabel = dialogRoleLabel(for: node)
            let stageCharacterImage = node.characterImage ?? StoryCharacterAsset.placeholder(for: node.emotion)

            VStack(spacing: 0) {
                topBar(layout: layout)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topBarTopPadding(for: layout))

                if useScrollStage {
                    ScrollView(showsIndicators: false) {
                        MessengerLectureQuizMiniGameStage(
                            quiz: quiz,
                            layout: layout,
                            availableWidth: geometry.size.width - (horizontalPadding * 2),
                            availableHeight: geometry.size.height - topBarTopPadding(for: layout) - layout.topBarReservedHeight - stageTopPadding - stageBottomPadding,
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
                        .frame(minHeight: geometry.size.height - topBarTopPadding(for: layout) - layout.topBarReservedHeight - stageTopPadding - stageBottomPadding)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, stageTopPadding)
                        .padding(.bottom, stageBottomPadding)
                    }
                } else {
                    MessengerLectureQuizMiniGameStage(
                        quiz: quiz,
                        layout: layout,
                        availableWidth: geometry.size.width - (horizontalPadding * 2),
                        availableHeight: geometry.size.height - topBarTopPadding(for: layout) - layout.topBarReservedHeight - stageTopPadding - stageBottomPadding,
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, stageTopPadding)
                    .padding(.bottom, stageBottomPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func biasDataAuditActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        minigame: BiasDataAuditMiniGame
    ) -> some View {
        // Classroom/stage style (like Chapter 2's LectureQuiz)
        let horizontalPadding = layout.dialogPadding
        let topInset = topBarTopPadding(for: layout) + max(36, layout.topBarReservedHeight - (geometry.size.height < 700 ? 18 : 10))
        let bottomInset = max(layout.safeAreaInsets.bottom, 10)
        let stageSpeaker = viewModel.resolvedSpeaker(for: node).isEmpty ? "You" : viewModel.resolvedSpeaker(for: node)
        let stageRoleLabel = dialogRoleLabel(for: node)
        let stageCharacterImage = node.characterImage ?? StoryCharacterAsset.placeholder(for: node.emotion)

        return ZStack {
            VStack {
                topBar(layout: layout)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topBarTopPadding(for: layout))
                Spacer()
            }
            .zIndex(20)

            ClassroomBiasDataAuditMiniGameStage(
                minigame: minigame,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                isTyping: viewModel.isTyping,
                instructionText: viewModel.displayedText,
                speaker: stageSpeaker,
                roleLabel: stageRoleLabel,
                characterImageName: stageCharacterImage,
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


    private func chapter3KNNRescueActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        minigame: Chapter3KNNRescueMiniGame
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

            Chapter3KNNRescueMessagesMiniGame(
                minigame: minigame,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                onComplete: { result in
                    viewModel.completeInlineActivity(for: node.id, result: result)
                    handleAdvanceAction()
                }
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        let resolvedQuiz = resolvedLectureQuizTemplates(quiz)

        return ZStack {
            VStack {
                topBar(layout: layout)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topBarTopPadding(for: layout))
                Spacer()
            }
            .zIndex(20)

            ClassroomLectureQuizMiniGameStage(
                quiz: resolvedQuiz,
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

    private func resolvedLectureQuizTemplates(_ quiz: LectureQuizMiniGame) -> LectureQuizMiniGame {
        let resolvedQuestions = quiz.questions.map { question in
            LectureQuizQuestion(
                id: question.id,
                question: viewModel.renderTemplate(question.question),
                choices: question.choices.map { option in
                    LectureQuizOption(
                        id: option.id,
                        text: viewModel.renderTemplate(option.text),
                        feedback: viewModel.renderTemplate(option.feedback),
                        isBestAnswer: option.isBestAnswer,
                        icon: option.icon
                    )
                },
                aiGuessLine: question.aiGuessLine.map(viewModel.renderTemplate),
                sceneImageName: question.sceneImageName,
                sceneImageCaption: question.sceneImageCaption.map(viewModel.renderTemplate),
                referenceBookTitle: question.referenceBookTitle.map(viewModel.renderTemplate),
                referencePages: question.referencePages.map { page in
                    LectureQuizReferencePage(
                        id: page.id,
                        title: viewModel.renderTemplate(page.title),
                        text: viewModel.renderTemplate(page.text),
                        imageName: page.imageName
                    )
                }
            )
        }

        return LectureQuizMiniGame(
            title: viewModel.renderTemplate(quiz.title),
            questions: resolvedQuestions,
            promptLabel: viewModel.renderTemplate(quiz.promptLabel),
            exampleImageName: quiz.exampleImageName,
            exampleCaption: quiz.exampleCaption.map(viewModel.renderTemplate),
            summaryNote: viewModel.renderTemplate(quiz.summaryNote),
            teacherName: viewModel.renderTemplate(quiz.teacherName),
            teacherRole: quiz.teacherRole.map(viewModel.renderTemplate),
            teacherImageName: quiz.teacherImageName,
            studentName: viewModel.renderTemplate(quiz.studentName),
            studentRole: quiz.studentRole.map(viewModel.renderTemplate),
            studentImageName: quiz.studentImageName,
            usesClassroomStageLayout: quiz.usesClassroomStageLayout,
            studentGivesCorrectionFeedback: quiz.studentGivesCorrectionFeedback
        )
    }

    private func promptBuilderActivityScene(
        layout: DialogAdaptiveLayout,
        geometry: GeometryProxy,
        node: DialogNode,
        minigame: PromptBuilderMiniGame
    ) -> some View {
        let horizontalPadding = layout.dialogPadding
        let useScrollStage = geometry.size.width < 1120 || geometry.size.height < 760
        let stageTopPadding: CGFloat = 12
        let stageBottomPadding = max(layout.safeAreaInsets.bottom, 12)
        let promptStageVisibleHeight = max(
            geometry.size.height
                - topBarTopPadding(for: layout)
                - layout.topBarReservedHeight
                - stageTopPadding
                - stageBottomPadding,
            520
        )
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
                        availableHeight: promptStageVisibleHeight,
                        speaker: stageSpeaker,
                        roleLabel: stageRoleLabel,
                        emotion: node.emotion,
                        characterImageName: stageCharacterImage,
                        instructionText: viewModel.displayedText,
                        isTyping: viewModel.isTyping,
                        isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                        onSkipTyping: { handleSkipTypingAction() },
                        onContinue: { handleAdvanceAction() },
                        onSetStoryVariable: { key, value in
                            viewModel.setStoryVariable(key, value: value)
                        }
                    ) { result in
                        viewModel.completeInlineActivity(for: node.id, result: result)
                    }
                    .frame(minHeight: promptStageVisibleHeight)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, stageTopPadding)
                    .padding(.bottom, stageBottomPadding)
                }
            } else {
                PromptBuilderMessagesMiniGameStage(
                    minigame: minigame,
                    layout: layout,
                    availableWidth: geometry.size.width - (horizontalPadding * 2),
                    availableHeight: promptStageVisibleHeight,
                    speaker: stageSpeaker,
                    roleLabel: stageRoleLabel,
                    emotion: node.emotion,
                    characterImageName: stageCharacterImage,
                    instructionText: viewModel.displayedText,
                    isTyping: viewModel.isTyping,
                    isCompleted: viewModel.isInlineActivityCompleted(for: node.id),
                    onSkipTyping: { handleSkipTypingAction() },
                    onContinue: { handleAdvanceAction() },
                    onSetStoryVariable: { key, value in
                        viewModel.setStoryVariable(key, value: value)
                    }
                ) { result in
                    viewModel.completeInlineActivity(for: node.id, result: result)
                }
                .frame(height: promptStageVisibleHeight, alignment: .topLeading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, stageTopPadding)
                .padding(.bottom, stageBottomPadding)
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
        HStack(spacing: layout.isCompact ? 6 : 10) {
            if showSettings {
                chapterMenuButton(layout: layout)
            }
            Spacer(minLength: 0)
            if showSettings {
                dialogSpeedButton(layout: layout)
                dialogSkipButton(layout: layout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chapterMenuButton(layout: DialogAdaptiveLayout) -> some View {
        let width: CGFloat = layout.isCompact ? 140 : (layout.isLarge ? 190 : 165)

        return Button {
            let willOpen = !showSettingsPanel
            if willOpen {
                syncSettingsAINameDraft()
            }
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

    // MARK: - Speed & Skip Controls

    private var missionThemeBlue: Color {
        Color(red: 0.12, green: 0.51, blue: 0.88)
    }

    private func dialogSpeedButton(layout: DialogAdaptiveLayout) -> some View {
        let fontSize: CGFloat = layout.isCompact ? 12 : 14
        let slantOffset: CGFloat = layout.isCompact ? 5 : 7
        let chevronCount = dialogSpeed  // 1 = >, 2 = >>, 3 = >>>
        let isActive = dialogSpeed > 1
        let bgColor = isActive ? missionThemeBlue : Color.black.opacity(0.45)

        return Button {
            cycleDialogSpeed()
        } label: {
            HStack(spacing: 3) {
                HStack(spacing: -1) {
                    ForEach(0..<chevronCount, id: \.self) { _ in
                        Image(systemName: "chevron.right")
                            .font(.system(size: fontSize - 2, weight: .black))
                    }
                }
                Text("\(dialogSpeed)x")
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundColor(.white)
            .padding(.horizontal, layout.isCompact ? 12 : 16)
            .padding(.vertical, layout.isCompact ? 8 : 10)
            .background(bgColor)
            .clipShape(SlantedRect(offset: slantOffset, direction: .forward))
            .shadow(color: bgColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dialog speed \(dialogSpeed)x")
        .accessibilityHint("Tap to cycle through 1x, 2x, 3x speed")
    }

    private func dialogSkipButton(layout: DialogAdaptiveLayout) -> some View {
        let fontSize: CGFloat = layout.isCompact ? 12 : 14
        let slantOffset: CGFloat = layout.isCompact ? 5 : 7
        let onMinigame = isOnMinigameNode
        let bgColor: Color = {
            if isAutoSkipping { return Color(red: 0.98, green: 0.48, blue: 0.53) }
            if onMinigame { return Color(red: 0.95, green: 0.6, blue: 0.15) }
            return Color.black.opacity(0.45)
        }()

        return Button {
            handleSkipButtonTap()
        } label: {
            HStack(spacing: layout.isCompact ? 4 : 6) {
                Image(systemName: "forward.fill")
                    .font(.system(size: fontSize - 1, weight: .bold))
                Text("SKIP")
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundColor(.white)
            .padding(.horizontal, layout.isCompact ? 12 : 16)
            .padding(.vertical, layout.isCompact ? 8 : 10)
            .background(bgColor)
            .clipShape(SlantedRect(offset: slantOffset, direction: .forward))
            .shadow(color: bgColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAutoSkipping ? "Stop skipping" : "Skip dialog")
        .accessibilityHint("Auto-advance through dialog lines")
    }

    private func skipMinigameOverlay(layout: DialogAdaptiveLayout) -> some View {
        let cardWidth: CGFloat = layout.isCompact ? 220 : 260

        return ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.18)) { showSkipMinigameConfirm = false }
                }

            // Card
            VStack(spacing: layout.isCompact ? 10 : 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: layout.isCompact ? 26 : 32))
                    .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.15))

                Text("Skip this minigame?")
                    .font(.system(size: layout.isCompact ? 15 : 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("You won't be able to replay it\nin this run.")
                    .font(.system(size: layout.isCompact ? 11 : 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { showSkipMinigameConfirm = false }
                    } label: {
                        Text("CANCEL")
                            .font(.system(size: layout.isCompact ? 12 : 14, weight: .black, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, layout.isCompact ? 10 : 12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(SlantedRect(offset: 5, direction: .forward))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { showSkipMinigameConfirm = false }
                        skipCurrentMinigame()
                    } label: {
                        Text("SKIP")
                            .font(.system(size: layout.isCompact ? 12 : 14, weight: .black, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, layout.isCompact ? 10 : 12)
                            .background(Color(red: 0.98, green: 0.48, blue: 0.53))
                            .clipShape(SlantedRect(offset: 5, direction: .forward))
                            .shadow(color: Color(red: 0.98, green: 0.48, blue: 0.53).opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(layout.isCompact ? 16 : 22)
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.92),
                                Color(red: 0.08, green: 0.08, blue: 0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
        }
        .transition(.opacity)
    }

    private func cycleDialogSpeed() {
        switch dialogSpeed {
        case 1: dialogSpeed = 2
        case 2: dialogSpeed = 3
        default: dialogSpeed = 1
        }
        applyDialogSpeed()
    }

    private func applyDialogSpeed() {
        let speed = Double(dialogSpeed)
        viewModel.setTypingSpeed(speed)
        speechManager.rateMultiplier = Float(speed == 1 ? 1.0 : (speed == 2 ? 1.4 : 1.8))
    }

    private func handleSkipButtonTap() {
        // If already auto-skipping, stop it
        if isAutoSkipping {
            isAutoSkipping = false
            stopAutoSkip()
            return
        }
        // If on a minigame node, show confirmation dropdown
        if isOnMinigameNode {
            withAnimation(.easeOut(duration: 0.18)) {
                showSkipMinigameConfirm.toggle()
            }
            return
        }
        // Otherwise toggle normal auto-skip
        isAutoSkipping = true
        startAutoSkip()
    }

    private func toggleAutoSkip() {
        isAutoSkipping.toggle()
        if isAutoSkipping {
            startAutoSkip()
        } else {
            stopAutoSkip()
        }
    }

    /// Whether the current node has an incomplete minigame (inline activity).
    private var isOnMinigameNode: Bool {
        guard let node = viewModel.currentNode else { return false }
        return node.inlineActivity != nil && !viewModel.isInlineActivityCompleted(for: node.id)
    }

    /// Whether the current node is interactive and must not be auto-skipped.
    private var isOnInteractiveNode: Bool {
        guard let node = viewModel.currentNode else { return false }
        if viewModel.showChoices || viewModel.showTextInput { return true }
        if node.requiresInput { return true }
        if node.choices != nil && !node.choices!.isEmpty { return true }
        if isOnMinigameNode { return true }
        return false
    }

    /// Force-skip the current minigame, marking it complete and advancing.
    private func skipCurrentMinigame() {
        guard let node = viewModel.currentNode,
              node.inlineActivity != nil else { return }
        viewModel.completeInlineActivity(for: node.id, result: "skipped")
        speechManager.stop()
        viewModel.advance()
    }

    private func startAutoSkip() {
        // Never start skipping on an interactive / minigame node
        if isOnInteractiveNode {
            isAutoSkipping = false
            return
        }

        autoSkipTask?.cancel()
        autoSkipTask = Task { @MainActor in
            while !Task.isCancelled && isAutoSkipping && !viewModel.isCompleted {
                // If currently typing, skip to end instantly
                if viewModel.isTyping {
                    speechManager.stop()
                    viewModel.skipTyping()
                }

                // Stop when hitting any interactive / minigame node
                if isOnInteractiveNode {
                    isAutoSkipping = false
                    break
                }

                // Brief pause before advancing (shorter at higher speeds)
                let delayMs: UInt64 = dialogSpeed >= 3 ? 150 : (dialogSpeed >= 2 ? 350 : 600)
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                guard !Task.isCancelled && isAutoSkipping else { break }

                // Re-check after sleep in case node changed
                if isOnInteractiveNode {
                    isAutoSkipping = false
                    break
                }

                // Advance to next node
                speechManager.stop()
                viewModel.advance()

                // Small delay to let the new node load
                try? await Task.sleep(nanoseconds: 50_000_000)

                // Check the newly loaded node immediately
                if isOnInteractiveNode {
                    isAutoSkipping = false
                    break
                }
            }
            if !Task.isCancelled {
                isAutoSkipping = false
            }
        }
    }

    private func stopAutoSkip() {
        autoSkipTask?.cancel()
        autoSkipTask = nil
    }

    private func syncSettingsAINameDraft() {
        let current = viewModel.storyVariables["ai_name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        settingsAINameDraft = (current?.isEmpty == false ? current! : "Ploy")
    }

    private func commitSettingsAINameDraft(resetToDefault: Bool = false) {
        let nextValue: String
        if resetToDefault {
            nextValue = "Ploy"
        } else {
            let trimmed = settingsAINameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            nextValue = trimmed.isEmpty ? "Ploy" : String(trimmed.prefix(24))
        }
        settingsAINameDraft = nextValue
        viewModel.setStoryVariable("ai_name", value: nextValue)
    }
    
    // MARK: - Character Section
    private func characterSection(
        layout: DialogAdaptiveLayout,
        forcedPlacement: VNCharacterPlacement? = nil
    ) -> some View {
        let splitShowcase = forcedPlacement == nil ? splitShowcaseMedia : nil
        let hidesCharacter = viewModel.currentNode?.characterImage == "__none__"
        let placement = forcedPlacement ?? (splitShowcase != nil ? .left : characterPlacement)
        let characterMaxWidth = splitShowcase != nil
            ? min(layout.characterMaxWidth, layout.width * (layout.isCompact ? 0.46 : 0.34))
            : layout.characterMaxWidth

        return ZStack(alignment: .bottom) {
            if !hidesCharacter {
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
            }
            
            if !hidesCharacter {
                // Character image
                HStack {
                    if placement != .left { Spacer(minLength: 0) }
                    characterImage(layout: layout)
                        .frame(maxWidth: characterMaxWidth, maxHeight: layout.characterMaxHeight)
                        .offset(x: splitShowcase != nil ? (layout.isCompact ? -8 : -18) : 0)
                    if placement != .right { Spacer(minLength: 0) }
                }
            }

            if let splitShowcase {
                HStack(alignment: .center, spacing: layout.elementSpacing) {
                    Spacer(minLength: splitShowcase.animatesShake ? 0 : (layout.isCompact ? 0 : max(8, layout.elementSpacing)))

                    DialogShowcaseCard(showcase: splitShowcase, layout: layout)
                        .frame(width: splitShowcaseWidth(for: splitShowcase, layout: layout))
                        .padding(.trailing, layout.isCompact ? 4 : 10)
                        .padding(.bottom, layout.isCompact ? 8 : 18)
                        .offset(x: splitShowcaseHorizontalOffset(for: splitShowcase, layout: layout))
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

    private func splitShowcaseWidth(for showcase: DialogShowcaseMedia, layout: DialogAdaptiveLayout) -> CGFloat {
        if showcase.animatesShake {
            switch true {
            case layout.isCompact:
                return min(layout.width * 0.70, 300)
            case layout.isRegular:
                return min(layout.width * 0.54, 390)
            case layout.isLarge:
                return min(layout.width * 0.46, 500)
            default:
                return min(layout.width * 0.42, 620)
            }
        }
        return clockSplitShowcaseWidth(for: layout)
    }

    private func splitShowcaseHorizontalOffset(for showcase: DialogShowcaseMedia, layout: DialogAdaptiveLayout) -> CGFloat {
        guard showcase.animatesShake else { return 0 }
        switch true {
        case layout.isCompact:
            return -24
        case layout.isRegular:
            return -48
        case layout.isLarge:
            return -86
        default:
            return -120
        }
    }
    
    private func characterImage(layout: DialogAdaptiveLayout) -> some View {
        let imageName: String = {
            if let explicit = viewModel.currentNode?.characterImage,
               !explicit.isEmpty,
               explicit != "__none__" {
                return explicit
            }

            if let node = viewModel.currentNode {
                let normalizedSpeaker = normalizedVoiceMatchText(viewModel.resolvedSpeaker(for: node))
                if isProfessorSpeaker(normalizedSpeaker) {
                    return "teachernew"
                }
                return "char_\(node.emotion.rawValue)"
            }

            return "char_\(Emotion.neutral.rawValue)"
        }()
        let specialSpriteScale: CGFloat = imageName == "unknow" ? 1.32 : 1.0
        
        return Image(imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect((characterScale * (isCharacterPressed ? 0.97 : 1.0)) * specialSpriteScale)
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
        let displaySpeakerName = speakerName
        let hasSpeakerHeader = !speakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if hasSpeakerHeader {
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
            } else if viewModel.isTyping {
                HStack(spacing: 8) {
                    TypingIndicator(layout: layout)
                    Button(action: { handleSkipTypingAction() }) {
                        Text("Skip")
                            .font(.system(size: layout.captionFontSize, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
            }

            if !isShowingInteractivePanel,
               hasSpeakerHeader,
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
        case .biasDataAudit(let minigame):
            BiasDataAuditMiniGameCard(
                minigame: minigame,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: nodeID)
            ) { result in
                viewModel.completeInlineActivity(for: nodeID, result: result)
            }
        case .chapter3KNNRescue(let minigame):
            Chapter3KNNRescueMessagesMiniGame(
                minigame: minigame,
                layout: layout,
                isCompleted: viewModel.isInlineActivityCompleted(for: nodeID),
                onComplete: { result in
                    viewModel.completeInlineActivity(for: nodeID, result: result)
                    handleAdvanceAction()
                }
            )
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

            menuToggleSection(title: "BGM", value: chapterMusicEnabledBinding, layout: layout)
            menuToggleSection(title: "VOICE", value: Binding(get: { globalSettings.speechEnabled }, set: { globalSettings.speechEnabled = $0 }), layout: layout)
            menuVolumeSection(title: "VOLUME", value: chapterMusicVolumeBinding, layout: layout)
            aiNameSettingsSection(layout: layout)

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

    private func aiNameSettingsSection(layout: DialogAdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("AI NAME")
                    .font(.system(size: layout.bodyFontSize + (layout.isCompact ? 1 : 2), weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(0.95))
                    .tracking(0.3)

                Spacer(minLength: 0)

                Text(viewModel.storyVariables["ai_name"] ?? "Ploy")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "0A6FEA"))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
            }

            HStack(spacing: 8) {
                TextField("Ploy", text: $settingsAINameDraft)
                    .font(.system(size: layout.bodyFontSize, weight: .medium, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.78), lineWidth: 1)
                    )
                    .onSubmit {
                        commitSettingsAINameDraft()
                    }

                Button("Change") {
                    commitSettingsAINameDraft()
                }
                .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "0A6FEA"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .buttonStyle(.plain)

                Button("Reset") {
                    commitSettingsAINameDraft(resetToDefault: true)
                }
                .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                .foregroundColor(.black.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .buttonStyle(.plain)
            }

            Text("Use this to rename the AI (girl voice). Reset returns to Ploy.")
                .font(.system(size: layout.captionFontSize, weight: .medium))
                .foregroundColor(.black.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func menuToggleSection(title: String, value: Binding<Bool>, layout: DialogAdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: layout.bodyFontSize + (layout.isCompact ? 1 : 2), weight: .bold, design: .rounded))
                .foregroundColor(.black.opacity(0.95))
                .tracking(0.3)

            HStack {
                Toggle("", isOn: value)
                    .labelsHidden()
                    .tint(Color(hex: "0A6FEA"))
                Spacer()
                Text(value.wrappedValue ? "On" : "Off")
                    .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(value.wrappedValue ? Color(hex: "0A6FEA") : .gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
        }
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
        case .curious: return .mint
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
    private enum FollowupStage: Equatable {
        case buildPrompt
        case ethicsChoice
        case renameAI
        case completed
    }

    private struct FollowupEthicsChoice: Identifiable {
        let id: String
        let text: String
        let feedback: String
    }

    private struct ChapterOneCraftRoundScript {
        let round: Int
        let unknownPrompt: String?
        let promptPlaceholder: String
        let unknownReply: String
    }

    private struct ChapterOneCraftSubmission: Identifiable {
        let id: String
        let round: Int
        let promptText: String
    }

    enum Presentation {
        case card
        case showcasePhone
    }

    let minigame: PromptBuilderMiniGame
    let layout: DialogAdaptiveLayout
    let presentation: Presentation
    let isCompleted: Bool
    let onSetStoryVariable: ((String, String) -> Void)?
    let onComplete: (String) -> Void

    @State private var selectedOptionBySlotID: [String: String] = [:]
    @State private var submitted = false
    @State private var submissionReviewText = ""
    @State private var followupStage: FollowupStage = .buildPrompt
    @State private var selectedFollowupEthicsChoiceID: String?
    @State private var renameDraft = ""
    @State private var renamedAIName: String?
    @State private var chapterOneCurrentCraftRound = 1
    @State private var chapterOneCraftSubmissions: [ChapterOneCraftSubmission] = []
    @State private var chapterOneRevealedUnknownMessageIDs: Set<String> = []
    @State private var chapterOneIsUnknownTyping = false
    @State private var chapterOneTypingTask: Task<Void, Never>?

    init(
        minigame: PromptBuilderMiniGame,
        layout: DialogAdaptiveLayout,
        presentation: Presentation = .card,
        isCompleted: Bool,
        onSetStoryVariable: ((String, String) -> Void)? = nil,
        onComplete: @escaping (String) -> Void
    ) {
        self.minigame = minigame
        self.layout = layout
        self.presentation = presentation
        self.isCompleted = isCompleted
        self.onSetStoryVariable = onSetStoryVariable
        self.onComplete = onComplete
        _renameDraft = State(initialValue: minigame.followupDefaultAIName)
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch presentation {
            case .card:
                standardCardBody
            case .showcasePhone:
                showcasePhoneBody
            }
        }
        .onDisappear {
            chapterOneTypingTask?.cancel()
            chapterOneTypingTask = nil
            chapterOneIsUnknownTyping = false
        }
    }

    private var usesChapterOneFollowupChat: Bool {
        presentation == .showcasePhone && minigame.includesChapterOneFollowupChat
    }

    private var displayedContactName: String {
        if let renamedAIName, !renamedAIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return renamedAIName
        }
        return minigame.contactName
    }

    private var followupEthicsChoices: [FollowupEthicsChoice] {
        [
            FollowupEthicsChoice(
                id: "yes_ethics",
                text: "Yes, explain and include safety reminders.",
                feedback: "Good choice. A clear answer is better when it also includes safety, privacy, and responsibility reminders."
            ),
            FollowupEthicsChoice(
                id: "no_ethics",
                text: "No, just explain who you are first.",
                feedback: "I can explain first, but safety context still matters because useful answers can be misused."
            )
        ]
    }

    private var selectedFollowupEthicsChoice: FollowupEthicsChoice? {
        guard let selectedFollowupEthicsChoiceID else { return nil }
        return followupEthicsChoices.first(where: { $0.id == selectedFollowupEthicsChoiceID })
    }

    private var isSpecialFlowBusy: Bool {
        usesChapterOneFollowupChat && chapterOneIsUnknownTyping
    }

    private var showsPromptSubmissionReceipt: Bool {
        (submitted || isCompleted) && !usesChapterOneFollowupChat
    }

    private var arePromptSlotsLocked: Bool {
        if isCompleted { return true }
        if isSpecialFlowBusy { return true }
        if usesChapterOneFollowupChat {
            return submitted && followupStage != .buildPrompt
        }
        return submitted
    }

    private var chapterOneCraftScripts: [ChapterOneCraftRoundScript] {
        [
            ChapterOneCraftRoundScript(
                round: 1,
                unknownPrompt: nil,
                promptPlaceholder: "Reply politely and ask who they are...",
                unknownReply: "Thanks for replying carefully. I can read that better. Ask me clearly who I am and why I messaged you, and I will answer."
            ),
            ChapterOneCraftRoundScript(
                round: 2,
                unknownPrompt: "Good start. Send one clearer message with your question and your boundary.",
                promptPlaceholder: "Ask identity + reason clearly...",
                unknownReply: "Much clearer. I am not a normal contact in your phone. Before I explain more, should I include safety and ethics reminders too?"
            ),
            ChapterOneCraftRoundScript(
                round: 3,
                unknownPrompt: "Now ask what I am and why I appeared in your messages in a calm, clear way.",
                promptPlaceholder: "Ask what this unknown sender is...",
                unknownReply: "I am an AI system using this thread to teach you. Your class topic and your questions made this chat possible."
            ),
            ChapterOneCraftRoundScript(
                round: 4,
                unknownPrompt: "Ask how I can help with school without replacing your own thinking.",
                promptPlaceholder: "Ask about safe help for school...",
                unknownReply: "I can help you learn, brainstorm, and practice prompts. I should not replace your judgment, your relationships, or your responsibility."
            ),
            ChapterOneCraftRoundScript(
                round: 5,
                unknownPrompt: "Final question before naming me: ask how you should treat AI and what rules to follow.",
                promptPlaceholder: "Ask for practical AI-use rules...",
                unknownReply: "Exactly. Ethical use means respecting people, checking truth, protecting privacy, and not giving me more authority than I should have."
            )
        ]
    }

    private func chapterOneConversationSlots(for round: Int) -> [PromptBuilderSlot] {
        switch round {
        case 1:
            return [
                PromptBuilderSlot(
                    id: "goal",
                    label: "[Goal]",
                    placeholder: "Goal",
                    options: [
                        PromptBuilderOption(id: "r1-goal-polite", chipText: "Reply politely", promptText: "Hi, I just got your message and I want to reply politely", feedbackNote: "Polite tone helps when talking to an unknown sender."),
                        PromptBuilderOption(id: "r1-goal-identity", chipText: "Ask identity first", promptText: "Hi, before we continue I need to know who you are", feedbackNote: "Good boundary: identity first."),
                        PromptBuilderOption(id: "r1-goal-calm", chipText: "Stay calm + ask", promptText: "Hi, I just received this message and I want to stay calm while I ask who you are", feedbackNote: "Great start: calm tone plus a clear purpose.")
                    ],
                    recommendedOptionID: "r1-goal-calm"
                ),
                PromptBuilderSlot(
                    id: "context",
                    label: "[Context]",
                    placeholder: "Context",
                    options: [
                        PromptBuilderOption(id: "r1-context-bus", chipText: "Riding home", promptText: "because I am riding home right now and the signal is not great,", feedbackNote: "Useful context: explains the noisy chat."),
                        PromptBuilderOption(id: "r1-context-unknown", chipText: "I don't know you", promptText: "and I do not recognize this contact,", feedbackNote: "Strong boundary context."),
                        PromptBuilderOption(id: "r1-context-bus-unknown", chipText: "Bus + unknown", promptText: "and I only saw it during my ride home from school, so I do not know who sent it,", feedbackNote: "Great context: time + situation + uncertainty.")
                    ],
                    recommendedOptionID: "r1-context-bus-unknown"
                ),
                PromptBuilderSlot(
                    id: "action",
                    label: "[Action]",
                    placeholder: "Action",
                    options: [
                        PromptBuilderOption(id: "r1-action-name", chipText: "Ask name + reason", promptText: "please tell me your name and why you contacted me", feedbackNote: "Clear question with purpose."),
                        PromptBuilderOption(id: "r1-action-contact", chipText: "Ask how they got contact", promptText: "please explain how you got this number and why you are messaging me", feedbackNote: "Good safety question."),
                        PromptBuilderOption(id: "r1-action-need", chipText: "Ask what they need", promptText: "and please explain clearly what you need from me", feedbackNote: "Useful, but identity is still important.")
                    ],
                    recommendedOptionID: "r1-action-name"
                ),
                PromptBuilderSlot(
                    id: "format",
                    label: "[Format]",
                    placeholder: "Format",
                    options: [
                        PromptBuilderOption(id: "r1-format-short", chipText: "Short friendly", promptText: "in one short friendly reply.", feedbackNote: "Good format for a first contact."),
                        PromptBuilderOption(id: "r1-format-two", chipText: "2 short sentences", promptText: "in 2 short sentences.", feedbackNote: "Simple and easy to read."),
                        PromptBuilderOption(id: "r1-format-simple", chipText: "Simple words", promptText: "with simple words so I can understand quickly.", feedbackNote: "Good clarity request.")
                    ],
                    recommendedOptionID: "r1-format-short"
                )
            ]
        case 2:
            return [
                PromptBuilderSlot(
                    id: "goal",
                    label: "[Goal]",
                    placeholder: "Goal",
                    options: [
                        PromptBuilderOption(id: "r2-goal-clarify", chipText: "Clarify first", promptText: "I can continue chatting, but I need to clarify this first", feedbackNote: "Good boundary and tone."),
                        PromptBuilderOption(id: "r2-goal-safe", chipText: "Only if safe", promptText: "I can help if this conversation is safe,", feedbackNote: "Good safety framing."),
                        PromptBuilderOption(id: "r2-goal-resend", chipText: "Resend clearly", promptText: "Please resend your message more clearly", feedbackNote: "Direct but less conversational.")
                    ],
                    recommendedOptionID: "r2-goal-clarify"
                ),
                PromptBuilderSlot(
                    id: "context",
                    label: "[Context]",
                    placeholder: "Context",
                    options: [
                        PromptBuilderOption(id: "r2-context-noisy", chipText: "Signal is noisy", promptText: "because your signal is noisy and some parts are hard to read,", feedbackNote: "Strong context for why you need clarity."),
                        PromptBuilderOption(id: "r2-context-student", chipText: "Student riding home", promptText: "and I am a student on the way home from school,", feedbackNote: "Helpful identity context."),
                        PromptBuilderOption(id: "r2-context-private", chipText: "No private info yet", promptText: "and I do not want to share private details yet,", feedbackNote: "Excellent boundary context.")
                    ],
                    recommendedOptionID: "r2-context-noisy"
                ),
                PromptBuilderSlot(
                    id: "action",
                    label: "[Action]",
                    placeholder: "Action",
                    options: [
                        PromptBuilderOption(id: "r2-action-identity-reason", chipText: "Identity + reason", promptText: "so please explain who you are and why you messaged me", feedbackNote: "Great action: asks both key questions."),
                        PromptBuilderOption(id: "r2-action-topic", chipText: "Topic + reason", promptText: "and tell me what topic you want to discuss and why", feedbackNote: "Good if you want intent first."),
                        PromptBuilderOption(id: "r2-action-school", chipText: "School related?", promptText: "and tell me what you need from me and whether this is related to school", feedbackNote: "Good context-specific action.")
                    ],
                    recommendedOptionID: "r2-action-identity-reason"
                ),
                PromptBuilderSlot(
                    id: "format",
                    label: "[Format]",
                    placeholder: "Format",
                    options: [
                        PromptBuilderOption(id: "r2-format-parts", chipText: "2 parts", promptText: "in two short parts: who you are and why you texted me.", feedbackNote: "Excellent format: very clear structure."),
                        PromptBuilderOption(id: "r2-format-short", chipText: "Short reply", promptText: "in one clear short reply.", feedbackNote: "Simple and readable."),
                        PromptBuilderOption(id: "r2-format-bullets", chipText: "Bullet points", promptText: "in bullet points so I can read it quickly.", feedbackNote: "Readable, but a bit formal for first contact.")
                    ],
                    recommendedOptionID: "r2-format-parts"
                )
            ]
        case 3:
            return [
                PromptBuilderSlot(
                    id: "goal",
                    label: "[Goal]",
                    placeholder: "Goal",
                    options: [
                        PromptBuilderOption(id: "r3-goal-what", chipText: "What are you?", promptText: "Please explain what you are", feedbackNote: "Direct and clear."),
                        PromptBuilderOption(id: "r3-goal-ai-or-person", chipText: "AI or person?", promptText: "Please tell me whether you are a person or an AI", feedbackNote: "Clear identity question."),
                        PromptBuilderOption(id: "r3-goal-introduce", chipText: "Introduce yourself", promptText: "Please introduce yourself and explain what you are", feedbackNote: "Strong start for a strange conversation.")
                    ],
                    recommendedOptionID: "r3-goal-introduce"
                ),
                PromptBuilderSlot(
                    id: "context",
                    label: "[Context]",
                    placeholder: "Context",
                    options: [
                        PromptBuilderOption(id: "r3-context-strange", chipText: "Strange message", promptText: "because this message thread appeared strangely on my phone,", feedbackNote: "Good context: describes the event."),
                        PromptBuilderOption(id: "r3-context-class", chipText: "I learned AI today", promptText: "and I just learned about AI in class today,", feedbackNote: "Great context: connects the topic to class."),
                        PromptBuilderOption(id: "r3-context-prank", chipText: "Could be a prank", promptText: "and I do not know if this is a prank or something real,", feedbackNote: "Honest context and uncertainty.")
                    ],
                    recommendedOptionID: "r3-context-class"
                ),
                PromptBuilderSlot(
                    id: "action",
                    label: "[Action]",
                    placeholder: "Action",
                    options: [
                        PromptBuilderOption(id: "r3-action-why", chipText: "Why message me?", promptText: "and tell me why you contacted me specifically", feedbackNote: "Important question."),
                        PromptBuilderOption(id: "r3-action-can-help", chipText: "What can you do?", promptText: "and tell me what you can help me with", feedbackNote: "Useful next step."),
                        PromptBuilderOption(id: "r3-action-reason-first", chipText: "Reason + limits", promptText: "and explain why you appeared in my messages and what your limits are", feedbackNote: "Excellent action: purpose plus limits.")
                    ],
                    recommendedOptionID: "r3-action-reason-first"
                ),
                PromptBuilderSlot(
                    id: "format",
                    label: "[Format]",
                    placeholder: "Format",
                    options: [
                        PromptBuilderOption(id: "r3-format-simple", chipText: "Simple language", promptText: "in simple student-friendly language.", feedbackNote: "Great clarity request."),
                        PromptBuilderOption(id: "r3-format-three", chipText: "3 sentences", promptText: "in 3 short sentences.", feedbackNote: "Readable and focused."),
                        PromptBuilderOption(id: "r3-format-calm", chipText: "Calm tone", promptText: "with a calm tone and no scary wording.", feedbackNote: "Good tone control.")
                    ],
                    recommendedOptionID: "r3-format-simple"
                )
            ]
        case 4:
            return [
                PromptBuilderSlot(
                    id: "goal",
                    label: "[Goal]",
                    placeholder: "Goal",
                    options: [
                        PromptBuilderOption(id: "r4-goal-school-safe", chipText: "Safe school help", promptText: "Please explain how you can help me with school safely", feedbackNote: "Strong goal for practical use."),
                        PromptBuilderOption(id: "r4-goal-prompt-practice", chipText: "Prompt practice", promptText: "Please explain how I can practice better prompts with your help", feedbackNote: "Good prompting focus."),
                        PromptBuilderOption(id: "r4-goal-learn-after-class", chipText: "Learn after class", promptText: "Please explain how you can help me learn after class", feedbackNote: "Good learning goal.")
                    ],
                    recommendedOptionID: "r4-goal-school-safe"
                ),
                PromptBuilderSlot(
                    id: "context",
                    label: "[Context]",
                    placeholder: "Context",
                    options: [
                        PromptBuilderOption(id: "r4-context-think-myself", chipText: "Think for myself", promptText: "while I still make my own decisions as a student,", feedbackNote: "Excellent context: keeps human judgment in control."),
                        PromptBuilderOption(id: "r4-context-not-homework", chipText: "Not do all homework", promptText: "and I do not want AI to do all my homework for me,", feedbackNote: "Good boundary for school use."),
                        PromptBuilderOption(id: "r4-context-real-examples", chipText: "Need examples", promptText: "and I learn better with practical examples,", feedbackNote: "Helpful learning context.")
                    ],
                    recommendedOptionID: "r4-context-think-myself"
                ),
                PromptBuilderSlot(
                    id: "action",
                    label: "[Action]",
                    placeholder: "Action",
                    options: [
                        PromptBuilderOption(id: "r4-action-safe-vs-risky", chipText: "Safe vs risky", promptText: "so compare safe uses and risky uses for school tasks", feedbackNote: "Great action: comparison builds judgment."),
                        PromptBuilderOption(id: "r4-action-judgment", chipText: "Keep judgment", promptText: "and explain how AI can help without replacing my judgment", feedbackNote: "Excellent action: focuses on responsibility."),
                        PromptBuilderOption(id: "r4-action-steps", chipText: "Steps to use", promptText: "and give steps for asking for help responsibly", feedbackNote: "Good practical action.")
                    ],
                    recommendedOptionID: "r4-action-safe-vs-risky"
                ),
                PromptBuilderSlot(
                    id: "format",
                    label: "[Format]",
                    placeholder: "Format",
                    options: [
                        PromptBuilderOption(id: "r4-format-bullets", chipText: "Bullets + examples", promptText: "in bullet points with short examples.", feedbackNote: "Excellent format for school comparison."),
                        PromptBuilderOption(id: "r4-format-checklist", chipText: "Checklist", promptText: "as a checklist I can use after class.", feedbackNote: "Practical and useful."),
                        PromptBuilderOption(id: "r4-format-paragraph", chipText: "Paragraph", promptText: "in one short paragraph.", feedbackNote: "Readable, but less scannable.")
                    ],
                    recommendedOptionID: "r4-format-bullets"
                )
            ]
        case 5:
            return [
                PromptBuilderSlot(
                    id: "goal",
                    label: "[Goal]",
                    placeholder: "Goal",
                    options: [
                        PromptBuilderOption(id: "r5-goal-rules", chipText: "AI-use rules", promptText: "Please give me clear rules for using AI responsibly", feedbackNote: "Strong practical goal."),
                        PromptBuilderOption(id: "r5-goal-treat-ai", chipText: "How to treat AI", promptText: "Please explain how I should treat AI respectfully", feedbackNote: "Good ethics goal."),
                        PromptBuilderOption(id: "r5-goal-boundaries", chipText: "Set boundaries", promptText: "Please explain what boundaries I should keep when using AI", feedbackNote: "Good focus on limits.")
                    ],
                    recommendedOptionID: "r5-goal-rules"
                ),
                PromptBuilderSlot(
                    id: "context",
                    label: "[Context]",
                    placeholder: "Context",
                    options: [
                        PromptBuilderOption(id: "r5-context-not-human", chipText: "AI not human", promptText: "because I know AI is not human but it still affects my habits,", feedbackNote: "Excellent context: balances respect and realism."),
                        PromptBuilderOption(id: "r5-context-privacy", chipText: "Protect privacy", promptText: "and I want to protect privacy and avoid overtrusting it,", feedbackNote: "Good safety context."),
                        PromptBuilderOption(id: "r5-context-new-user", chipText: "New to AI", promptText: "and I am still new to using AI outside class,", feedbackNote: "Good beginner context.")
                    ],
                    recommendedOptionID: "r5-context-not-human"
                ),
                PromptBuilderSlot(
                    id: "action",
                    label: "[Action]",
                    placeholder: "Action",
                    options: [
                        PromptBuilderOption(id: "r5-action-rules", chipText: "Practical rules", promptText: "so give me practical rules I can follow", feedbackNote: "Clear action with real-life use."),
                        PromptBuilderOption(id: "r5-action-respect-not-person", chipText: "Respect + tool", promptText: "and explain how to be respectful without treating AI like a person", feedbackNote: "Great nuance for ethics."),
                        PromptBuilderOption(id: "r5-action-reminders", chipText: "Key reminders", promptText: "and summarize the most important ethics reminders", feedbackNote: "Helpful summary action.")
                    ],
                    recommendedOptionID: "r5-action-respect-not-person"
                ),
                PromptBuilderSlot(
                    id: "format",
                    label: "[Format]",
                    placeholder: "Format",
                    options: [
                        PromptBuilderOption(id: "r5-format-checklist", chipText: "Checklist", promptText: "as a short checklist I can remember.", feedbackNote: "Best format for rules."),
                        PromptBuilderOption(id: "r5-format-five", chipText: "5 bullets", promptText: "in 5 bullet points.", feedbackNote: "Clear and organized."),
                        PromptBuilderOption(id: "r5-format-paragraph", chipText: "Paragraph", promptText: "in one clear paragraph.", feedbackNote: "Works, but harder to scan quickly.")
                    ],
                    recommendedOptionID: "r5-format-checklist"
                )
            ]
        default:
            return minigame.slots
        }
    }

    private var activePromptSlots: [PromptBuilderSlot] {
        if usesChapterOneFollowupChat && isSpecialCraftPhaseActive {
            return chapterOneConversationSlots(for: chapterOneCurrentCraftRound)
        }
        return minigame.slots
    }

    private func chapterOneCraftScript(for round: Int) -> ChapterOneCraftRoundScript? {
        chapterOneCraftScripts.first(where: { $0.round == round })
    }

    private func chapterOneReplyMessageID(for round: Int) -> String {
        "special-round-\(round)-reply"
    }

    private func chapterOneTypingDelay(for text: String) -> UInt64 {
        let clampedCount = min(max(text.count, 18), 180)
        let seconds = 0.45 + (Double(clampedCount) * 0.0085)
        return UInt64(seconds * 1_000_000_000)
    }

    private func scheduleChapterOneUnknownReply(
        revealMessageID: String,
        replyText: String,
        onReveal: @escaping () -> Void = {}
    ) {
        chapterOneTypingTask?.cancel()
        chapterOneIsUnknownTyping = true

        chapterOneTypingTask = Task {
            try? await Task.sleep(nanoseconds: chapterOneTypingDelay(for: replyText))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    chapterOneRevealedUnknownMessageIDs.insert(revealMessageID)
                    chapterOneIsUnknownTyping = false
                }
                onReveal()
                chapterOneTypingTask = nil
            }
        }
    }

    private func isRevealedChapterOneUnknownMessage(_ messageID: String) -> Bool {
        chapterOneRevealedUnknownMessageIDs.contains(messageID)
    }

    private var isSpecialCraftPhaseActive: Bool {
        usesChapterOneFollowupChat && followupStage == .buildPrompt && chapterOneCurrentCraftRound <= 5
    }

    private var shouldShowSpecialCraftDraftBubble: Bool {
        isSpecialCraftPhaseActive && !isCompleted && !chapterOneIsUnknownTyping
    }

    private var specialCraftDraftPlaceholder: String {
        if canSubmit {
            return promptPreview
        }
        return chapterOneCraftScript(for: chapterOneCurrentCraftRound)?.promptPlaceholder
            ?? "Tap the colored blocks below to build your reply..."
    }

    private var standardCardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(minigame.title)
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.white)
                    Text("Play inside a Messages-style screen and build a clear reply.")
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
                            if showsPromptSubmissionReceipt {
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
                    Text(displayedContactName)
                        .font(.system(size: 16, weight: .bold))
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
                        .frame(height: 138)

                    Divider()
                        .overlay(Color.black.opacity(0.08))

                    showcaseChatPane
                        .frame(height: layout.height < 760 ? 210 : 255)
                }
            } else {
                HStack(spacing: 0) {
                    showcaseThreadListPane
                        .frame(width: 320)

                    Divider()
                        .overlay(Color.black.opacity(0.08))

                    showcaseChatPane
                }
                .frame(height: layout.height < 760 ? 270 : 320)
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
        let activePreviewText: String = {
            if chapterOneIsUnknownTyping {
                return "\(displayedContactName) is typing..."
            }
            let activeMessages = usesChapterOneFollowupChat ? specialChapterOneChatMessages : preIntroChatMessages
            let lastText = activeMessages.last?.text ?? minigame.introMessage
            return String(lastText.prefix(42))
        }()

        return [
            ShowcaseThreadRow(
                name: displayedContactName,
                preview: activePreviewText,
                timestamp: chapterOneIsUnknownTyping ? "now" : "12:58 PM",
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
                        .font(.system(size: row.isSelected ? 14 : 13, weight: row.isSelected ? .bold : .semibold))
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
                Text(displayedContactName)
                    .font(.system(size: 16, weight: .bold))
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

                    if usesChapterOneFollowupChat {
                        ForEach(specialChapterOneChatMessages) { message in
                            showcaseChatBubbleRow(message: message)
                        }

                        if chapterOneIsUnknownTyping {
                            showcaseTypingBubbleRow
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        if shouldShowSpecialCraftDraftBubble {
                            HStack {
                                Spacer(minLength: 46)
                                Text(specialCraftDraftPlaceholder)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(canSubmit ? .white : Color.black.opacity(0.66))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        canSubmit ? Color(hex: "2AD160") : Color(hex: "DCE0E7"),
                                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    )
                            }
                        }
                    } else {
                        ForEach(preIntroChatMessages) { message in
                            showcaseChatBubbleRow(message: message)
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

                        ForEach(promptCraftingConversationMessages) { message in
                            showcaseChatBubbleRow(message: message)
                        }

                        if submitted || isCompleted {
                            ForEach(postSendConversationMessages) { message in
                                showcaseChatBubbleRow(message: message)
                            }
                            ForEach(extendedFollowupConversationMessages) { message in
                                showcaseChatBubbleRow(message: message)
                            }
                        } else {
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
                        }
                    }

                    if showsPromptSubmissionReceipt {
                        showcaseSentReceiptSection
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: specialChapterOneChatMessages.map { $0.id })
                .animation(.easeInOut(duration: 0.18), value: chapterOneIsUnknownTyping)
            }
            .background(Color.white)
        }
    }

    private var preIntroChatMessages: [DialogShowcaseChatMessage] {
        if !minigame.chatHistory.isEmpty {
            return minigame.chatHistory
        }

        return [
            DialogShowcaseChatMessage(
                id: "default-hey",
                text: "Hey",
                isFromPlayer: false
            )
        ]
    }

    private var specialChapterOneChatMessages: [DialogShowcaseChatMessage] {
        guard usesChapterOneFollowupChat else { return [] }

        var messages = preIntroChatMessages

        for submission in chapterOneCraftSubmissions {
            guard let script = chapterOneCraftScript(for: submission.round) else { continue }

            if let prompt = script.unknownPrompt, !prompt.isEmpty {
                messages.append(
                    DialogShowcaseChatMessage(
                        id: "special-round-\(submission.round)-prompt",
                        text: prompt,
                        isFromPlayer: false
                    )
                )
            }

            messages.append(
                DialogShowcaseChatMessage(
                    id: "special-round-\(submission.round)-player",
                    text: submission.promptText,
                    isFromPlayer: true
                )
            )

            let replyMessageID = chapterOneReplyMessageID(for: submission.round)
            if isRevealedChapterOneUnknownMessage(replyMessageID) {
                messages.append(
                    DialogShowcaseChatMessage(
                        id: replyMessageID,
                        text: script.unknownReply,
                        isFromPlayer: false
                    )
                )
            }

            if submission.round == 2 {
                if let selectedFollowupEthicsChoice {
                    messages.append(
                        DialogShowcaseChatMessage(
                            id: "special-yesno-player",
                            text: selectedFollowupEthicsChoice.text,
                            isFromPlayer: true
                        )
                    )
                    if isRevealedChapterOneUnknownMessage("special-yesno-reply") {
                        messages.append(
                            DialogShowcaseChatMessage(
                                id: "special-yesno-reply",
                                text: selectedFollowupEthicsChoice.feedback,
                                isFromPlayer: false
                            )
                        )
                    }
                }
            }
        }

        if isSpecialCraftPhaseActive,
           !chapterOneIsUnknownTyping,
           let activeScript = chapterOneCraftScript(for: chapterOneCurrentCraftRound),
           let prompt = activeScript.unknownPrompt,
           !prompt.isEmpty {
            messages.append(
                DialogShowcaseChatMessage(
                    id: "special-active-round-\(chapterOneCurrentCraftRound)-prompt",
                    text: prompt,
                    isFromPlayer: false
                )
            )
        }

        if shouldShowFollowupRenameInput || followupStage == .completed {
            messages.append(
                DialogShowcaseChatMessage(
                    id: "special-rename-prompt",
                    text: "Your thread still looks mysterious. I can keep your default name as \(minigame.followupDefaultAIName), or rename you now.",
                    isFromPlayer: true
                )
            )
        }

        if followupStage == .completed {
            messages.append(
                DialogShowcaseChatMessage(
                    id: "special-rename-player-choice",
                    text: "I will call you \(resolvedFollowupAINameForTemplate).",
                    isFromPlayer: true
                )
            )
            if isRevealedChapterOneUnknownMessage("special-final-ai") {
                messages.append(
                    DialogShowcaseChatMessage(
                        id: "special-final-ai",
                        text: "Name accepted. Next time, bring your notes from Professor New. We will practice stronger prompts and safer decisions together.",
                        isFromPlayer: false
                    )
                )
            }
        }

        return messages
    }

    private var promptCraftingConversationMessages: [DialogShowcaseChatMessage] {
        var messages: [DialogShowcaseChatMessage] = []

        for (index, slot) in minigame.slots.enumerated() {
            guard let selected = selectedOption(for: slot) else { break }

            messages.append(
                DialogShowcaseChatMessage(
                    id: "slot-player-\(slot.id)",
                    text: "\(slotChatLabel(slot)): \(selected.chipText)",
                    isFromPlayer: true
                )
            )

            messages.append(
                DialogShowcaseChatMessage(
                    id: "slot-unknown-\(slot.id)",
                    text: unknownReplyForPromptStep(index: index),
                    isFromPlayer: false
                )
            )
        }

        return messages
    }

    private var postSendConversationMessages: [DialogShowcaseChatMessage] {
        guard submitted || isCompleted else { return [] }

        if usesChapterOneFollowupChat {
            return [
                DialogShowcaseChatMessage(
                    id: "final-player-prompt",
                    text: promptPreview,
                    isFromPlayer: true
                ),
                DialogShowcaseChatMessage(
                    id: "followup-prompt-lesson",
                    text: "That helped. When you define the goal, context, action, and format, my reply becomes easier to understand and safer to use.",
                    isFromPlayer: false
                )
            ]
        }

        return [
            DialogShowcaseChatMessage(
                id: "final-player-prompt",
                text: promptPreview,
                isFromPlayer: true
            ),
            DialogShowcaseChatMessage(
                id: "final-unknown-reply",
                text: "That prompt is much clearer. I can answer better now because you gave me a goal, context, action, and format.",
                isFromPlayer: false
            )
        ]
    }

    private var extendedFollowupConversationMessages: [DialogShowcaseChatMessage] {
        guard usesChapterOneFollowupChat, submitted else { return [] }

        var messages: [DialogShowcaseChatMessage] = []

        if followupStage == .ethicsChoice || followupStage == .renameAI || followupStage == .completed {
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-player-home",
                    text: "Back home, I open my computer and continue the same thread on a larger screen. The unknown sender still replies instantly.",
                    isFromPlayer: true
                )
            )
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-unknown-ethics1",
                    text: "One more lesson. A good prompt improves quality, but ethics decides whether the result should be used at all.",
                    isFromPlayer: false
                )
            )
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-unknown-ethics2",
                    text: "Do not panic. I am not human, and I should not replace human relationships. But I can still help you learn if you use me responsibly.",
                    isFromPlayer: false
                )
            )
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-player-ethics-question",
                    text: "If you are not human, how should I treat you?",
                    isFromPlayer: true
                )
            )
        }

        if let selectedFollowupEthicsChoice {
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-player-choice",
                    text: selectedFollowupEthicsChoice.text,
                    isFromPlayer: true
                )
            )
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-unknown-choice-feedback",
                    text: selectedFollowupEthicsChoice.feedback,
                    isFromPlayer: false
                )
            )
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-unknown-reminder",
                    text: "Exactly. Ethical use means respecting people, checking truth, protecting privacy, and not giving me more authority than I should have.",
                    isFromPlayer: false
                )
            )
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-player-rename-prompt",
                    text: "Your thread still looks mysterious. I can keep your default name as \(resolvedFollowupAINameForTemplate), or rename you now.",
                    isFromPlayer: true
                )
            )
        }

        if followupStage == .completed {
            messages.append(
                DialogShowcaseChatMessage(
                    id: "followup-ai-final",
                    text: "Name accepted. Next time, bring your notes from Professor New. We will practice stronger prompts and safer decisions together.",
                    isFromPlayer: false
                )
            )
        }

        return messages
    }

    private var shouldShowFollowupEthicsChoices: Bool {
        usesChapterOneFollowupChat && submitted && followupStage == .ethicsChoice && selectedFollowupEthicsChoice == nil && !chapterOneIsUnknownTyping
    }

    private var shouldShowFollowupRenameInput: Bool {
        usesChapterOneFollowupChat && submitted && followupStage == .renameAI && !chapterOneIsUnknownTyping
    }

    private var resolvedFollowupAINameForTemplate: String {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return minigame.followupDefaultAIName
        }
        return trimmed
    }

    private func slotChatLabel(_ slot: PromptBuilderSlot) -> String {
        slot.label
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
    }

    private func unknownReplyForPromptStep(index: Int) -> String {
        switch index {
        case 0:
            return "Nice start. Now tell me the context so I know who this answer is for."
        case 1:
            return "Good. What do you want me to do with that topic?"
        case 2:
            return "Great. Last step: tell me the format you want."
        default:
            return "Perfect. Send the full message and I will answer more clearly."
        }
    }

    private func selectFollowupEthicsChoice(_ choice: FollowupEthicsChoice) {
        guard shouldShowFollowupEthicsChoices else { return }
        selectedFollowupEthicsChoiceID = choice.id
        followupStage = .buildPrompt
        chapterOneCurrentCraftRound = 3
        scheduleChapterOneUnknownReply(
            revealMessageID: "special-yesno-reply",
            replyText: choice.feedback
        )
    }

    private func submitFollowupRename() {
        guard shouldShowFollowupRenameInput, !chapterOneIsUnknownTyping else { return }
        let finalName = resolvedFollowupAINameForTemplate
        renamedAIName = finalName
        if let key = minigame.followupRenameVariableKey {
            onSetStoryVariable?(key, finalName)
        }
        followupStage = .completed
        scheduleChapterOneUnknownReply(
            revealMessageID: "special-final-ai",
            replyText: "Name accepted. Next time, bring your notes from Professor New. We will practice stronger prompts and safer decisions together."
        ) {
            finalizePromptBuilderCompletion(renamedTo: finalName)
        }
    }

    private func showcaseChatBubbleRow(message: DialogShowcaseChatMessage) -> some View {
        HStack {
            if message.isFromPlayer {
                Spacer(minLength: 46)
            }

            Text(message.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(message.isFromPlayer ? .white : Color.black.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    message.isFromPlayer ? Color(hex: "2D8CFF") : Color(hex: "E9E9EE"),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            if !message.isFromPlayer {
                Spacer(minLength: 46)
            }
        }
        .id(message.id)
        .transition(
            .asymmetric(
                insertion: .move(edge: message.isFromPlayer ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    private var showcaseTypingBubbleRow: some View {
        HStack {
            HStack(spacing: 8) {
                TypingIndicator(layout: layout)
                Text("\(displayedContactName) is typing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 46)
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

            if usesChapterOneFollowupChat {
                ForEach(specialChapterOneChatMessages) { message in
                    messageThreadBubbleRow(message: message)
                }

                if chapterOneIsUnknownTyping {
                    messageThreadTypingBubbleRow
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if shouldShowSpecialCraftDraftBubble {
                    HStack {
                        Spacer(minLength: 40)
                        Text(specialCraftDraftPlaceholder)
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
            } else {
                ForEach(preIntroChatMessages) { message in
                    messageThreadBubbleRow(message: message)
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

                ForEach(promptCraftingConversationMessages) { message in
                    messageThreadBubbleRow(message: message)
                }

                if submitted || isCompleted {
                    ForEach(postSendConversationMessages) { message in
                        messageThreadBubbleRow(message: message)
                    }
                    ForEach(extendedFollowupConversationMessages) { message in
                        messageThreadBubbleRow(message: message)
                    }
                } else {
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
            }
        }
        .padding(12)
        .background(Color(red: 0.90, green: 0.93, blue: 0.97), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: specialChapterOneChatMessages.map { $0.id })
        .animation(.easeInOut(duration: 0.18), value: chapterOneIsUnknownTyping)
    }

    private func messageThreadBubbleRow(message: DialogShowcaseChatMessage) -> some View {
        HStack {
            if message.isFromPlayer {
                Spacer(minLength: 40)
            }

            Text(message.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(message.isFromPlayer ? .white : Color.black.opacity(0.84))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    message.isFromPlayer
                        ? Color(red: 0.07, green: 0.51, blue: 1.0)
                        : Color.white,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            if !message.isFromPlayer {
                Spacer(minLength: 40)
            }
        }
        .id(message.id)
        .transition(
            .asymmetric(
                insertion: .move(edge: message.isFromPlayer ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    private var messageThreadTypingBubbleRow: some View {
        HStack {
            HStack(spacing: 8) {
                TypingIndicator(layout: layout)
                Text("\(displayedContactName) is typing")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 40)
        }
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

            ForEach(activePromptSlots) { slot in
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
        if usesChapterOneFollowupChat && submitted && followupStage != .buildPrompt {
            return AnyView(showcaseFollowupPaletteSection)
        }

        return AnyView(
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

                if usesChapterOneFollowupChat {
                    Text("Round \(min(chapterOneCurrentCraftRound, 5)) / 5")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.85), in: Capsule())
                }

                Text(isSpecialFlowBusy ? "Typing..." : (canSubmit ? "Ready to Send" : "Pick 4 Blocks"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(
                        isSpecialFlowBusy
                            ? Color(hex: "2D8CFF")
                            : (canSubmit ? Color(hex: "0E8A3D") : Color.black.opacity(0.55))
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: showcasePaletteColumns, spacing: 12) {
                    ForEach(Array(activePromptSlots.enumerated()), id: \.element.id) { index, slot in
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
            .frame(maxHeight: layout.height < 760 ? 230 : 285)
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
        )
    }

    private var showcasePaletteColumns: [GridItem] {
        let columnCount = layout.width > 1500 ? 3 : (layout.width > 980 ? 2 : 1)
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columnCount)
    }

    private func showcasePromptSlotCard(_ slot: PromptBuilderSlot, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(slot.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black.opacity(0.80))

                Spacer(minLength: 4)

                if let selected = selectedOption(for: slot) {
                    Text(selected.chipText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black.opacity(0.75))
                        .lineLimit(1)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                ForEach(slot.options) { option in
                    let isSelected = selectedOptionBySlotID[slot.id] == option.id

                    Button {
                        guard !arePromptSlotsLocked else { return }
                        selectedOptionBySlotID[slot.id] = option.id
                    } label: {
                        Text(option.chipText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .black.opacity(0.78))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 9)
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
                    .disabled(arePromptSlotsLocked)
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
                        guard !arePromptSlotsLocked else { return }
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
                    .disabled(arePromptSlotsLocked)
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
                        .foregroundColor((canSubmit && !isCompleted && !isSpecialFlowBusy) ? Color.blue : Color.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isCompleted || isSpecialFlowBusy)
            }
        }
    }

    private var showcaseComposerSection: some View {
        if usesChapterOneFollowupChat && submitted && followupStage != .buildPrompt {
            if shouldShowFollowupRenameInput {
                return AnyView(showcaseFollowupRenameComposer)
            }
            return AnyView(showcaseFollowupPassiveComposer)
        }

        if shouldShowFollowupRenameInput {
            return AnyView(showcaseFollowupRenameComposer)
        }

        return AnyView(
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray.opacity(0.85))
                .frame(width: 26, height: 26)

            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.65))

                Text(
                    isSpecialFlowBusy
                        ? "\(displayedContactName) is typing..."
                        : (canSubmit ? promptPreview : "Text Message")
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSpecialFlowBusy ? .gray : (canSubmit ? .black.opacity(0.82) : .gray))
                    .lineLimit(isSpecialFlowBusy ? 1 : 2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor((canSubmit && !isCompleted && !isSpecialFlowBusy) ? .white : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill((canSubmit && !isCompleted && !isSpecialFlowBusy) ? Color.blue : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isCompleted || isSpecialFlowBusy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.07))
                .frame(height: 0.8),
            alignment: .top
        )
        )
    }

    private var showcaseFollowupPassiveComposer: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.bubble")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray.opacity(0.85))
                .frame(width: 26, height: 26)

            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.65))

                Text(
                    chapterOneIsUnknownTyping
                        ? "\(displayedContactName) is typing..."
                        : (shouldShowFollowupEthicsChoices ? "Choose a reply from the options below..." : "Continue the chat below...")
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
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

            Text("Send")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
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

    private var showcaseFollowupPaletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shouldShowFollowupEthicsChoices ? "Choose Your Reply" : (followupStage == .completed ? "Chat Complete" : "Name the AI"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black.opacity(0.80))
                    Text(shouldShowFollowupEthicsChoices ? "Reply in the chat to continue the conversation" : "Continue inside Messages to finish Chapter 1")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black.opacity(0.55))
                }

                Spacer(minLength: 0)

                Text(
                    chapterOneIsUnknownTyping
                        ? "Waiting..."
                        : (followupStage == .completed ? "Ready" : "Step 2")
                )
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(
                        chapterOneIsUnknownTyping
                            ? Color(hex: "2D8CFF")
                            : (followupStage == .completed ? Color(hex: "0E8A3D") : Color.black.opacity(0.55))
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }

            if shouldShowFollowupEthicsChoices {
                VStack(spacing: 8) {
                    ForEach(followupEthicsChoices) { choice in
                        followupEthicsChoiceButton(choice)
                    }
                }
            } else if shouldShowFollowupRenameInput {
                Text("Type a name in the message bar below, or press Send to keep the default name \(minigame.followupDefaultAIName).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            } else if chapterOneIsUnknownTyping {
                Text("Wait for the reply to finish typing...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Conversation complete. The thread now continues with the AI's chosen name.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private func followupEthicsChoiceButton(_ choice: FollowupEthicsChoice) -> some View {
        Button {
            selectFollowupEthicsChoice(choice)
        } label: {
            Text(choice.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.82))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.65), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!shouldShowFollowupEthicsChoices)
    }

    private var showcaseFollowupRenameComposer: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray.opacity(0.85))
                .frame(width: 26, height: 26)

            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.65))

                TextField(minigame.followupDefaultAIName, text: $renameDraft)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black.opacity(0.82))
                    .submitLabel(.send)
                    .onSubmit { submitFollowupRename() }
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
                submitFollowupRename()
            } label: {
                Text("Send")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
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
        activePromptSlots.allSatisfy { selectedOptionBySlotID[$0.id] != nil }
    }

    private var promptPreview: String {
        activePromptSlots.map { slot in
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
        if usesChapterOneFollowupChat {
            guard canSubmit, !isCompleted, isSpecialCraftPhaseActive, !chapterOneIsUnknownTyping else { return }
            let round = chapterOneCurrentCraftRound
            let sentPrompt = promptPreview

            if !submitted {
                submitted = true
            }

            chapterOneCraftSubmissions.append(
                ChapterOneCraftSubmission(
                    id: "special-craft-\(round)-\(chapterOneCraftSubmissions.count)",
                    round: round,
                    promptText: sentPrompt
                )
            )

            selectedOptionBySlotID.removeAll()

            switch round {
            case 1:
                chapterOneCurrentCraftRound = 2
                followupStage = .buildPrompt
            case 2:
                followupStage = .ethicsChoice
            case 3:
                chapterOneCurrentCraftRound = 4
                followupStage = .buildPrompt
            case 4:
                chapterOneCurrentCraftRound = 5
                followupStage = .buildPrompt
            case 5:
                followupStage = .renameAI
                if renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    renameDraft = minigame.followupDefaultAIName
                }
            default:
                followupStage = .renameAI
            }

            if let script = chapterOneCraftScript(for: round) {
                scheduleChapterOneUnknownReply(
                    revealMessageID: chapterOneReplyMessageID(for: round),
                    replyText: script.unknownReply
                )
            }
            return
        }

        guard canSubmit, !isCompleted, !submitted else { return }
        submitted = true

        finalizePromptBuilderCompletion()
    }

    private func finalizePromptBuilderCompletion(renamedTo: String? = nil) {
        let trimmedRenamedTo = renamedTo?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = (trimmedRenamedTo?.isEmpty == false) ? trimmedRenamedTo : nil

        if usesChapterOneFollowupChat {
            let finalCraftPrompt = chapterOneCraftSubmissions.last?.promptText ?? "No final prompt recorded"
            var summary = "Completed the extended Messages mini-game. Final crafted prompt: \"\(finalCraftPrompt)\"."
            if let selectedFollowupEthicsChoice {
                summary += " Yes/No choice: \"\(selectedFollowupEthicsChoice.text)\"."
            }
            if let finalName {
                summary += " Renamed \(minigame.contactName) to \(finalName)."
            }
            submissionReviewText = summary
            onComplete(summary)
            return
        }

        let selections = minigame.slots.compactMap { selectedOption(for: $0) }
        let selectedNotes = selections.map(\.feedbackNote).joined(separator: " ")
        let recommendedMatches = minigame.slots.filter { slot in
            selectedOptionBySlotID[slot.id] == slot.recommendedOptionID
        }.count
        var summary = "Message sent to \(minigame.contactName). All answers can work, but the strongest prompt here is: \"\(recommendedPrompt())\". Your version matched \(recommendedMatches)/\(minigame.slots.count) best-practice parts. \(selectedNotes)"
        summary += " The sender still appears as \"\(minigame.contactName)\" for now; you can rename them later (default: Ploy)."

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
    let onSetStoryVariable: (String, String) -> Void
    let onComplete: (String) -> Void

    private var usesStackedLayout: Bool {
        availableWidth < 940 || availableHeight < 700
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
        let base = layout.isCompact ? 8.0 : 12.0
        return base * 4.0
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
            onSetStoryVariable: onSetStoryVariable,
            onComplete: onComplete
        )
        .allowsHitTesting(!isTyping)
        .opacity(isTyping ? 0.88 : 1.0)
    }

    private var professorStylePromptStage: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: layout.isCompact ? 6 : 8) {
                    wideTopUtilityRow

                    VStack(spacing: 0) {
                        Spacer(minLength: layout.isCompact ? 8 : 12)

                        phonePanel
                            .frame(width: wideCenterPhoneWidth)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: -phoneWideUpOffset)

                        Spacer(minLength: wideBottomDialogReserve)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .zIndex(0)

                wideBottomGradientOverlay
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .zIndex(1)

                wideBottomDialogOverlay
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .bottomLeading
                    )
                    .zIndex(10)

                wideCharacterLayer
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                    .zIndex(5)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wideCharacterLayer: some View {
        HStack {
            Image(characterImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: min(wideStageMaxWidth * 0.26, 360), maxHeight: wideCharacterSpriteHeight, alignment: .bottom)
                .offset(x: -wideCharacterHorizontalPush, y: -(layout.isCompact ? 14 : 22))
                .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
                .allowsHitTesting(false)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: wideStageMaxWidth, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, layout.isCompact ? 6 : 10)
        .padding(.bottom, max(0, wideBottomDialogReserve - (layout.isCompact ? 28 : 34)))
    }

    private var wideTopUtilityRow: some View {
        HStack(spacing: 10) {
            Text("Message Mini-game")
                .font(.system(size: layout.captionFontSize + 2, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.34), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Text("iPad Messages Prompt Builder")
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
    }

    private var wideBottomDialogOverlay: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: layout.isCompact ? 8 : 10) {
                HStack(alignment: .top, spacing: layout.isCompact ? 12 : 18) {
                    promptBottomDialogPane(
                        name: speaker.isEmpty ? "You" : speaker,
                        role: roleLabel ?? emotion.rawValue.capitalized,
                        text: instructionText.isEmpty ? "Build a clear reply before sending it in the chat." : instructionText,
                        accent: emotionAccent
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                        .allowsHitTesting(false)
                }

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
        }
        .frame(maxWidth: wideStageMaxWidth, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 4)
        .padding(.bottom, wideDialogVerticalLift)
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

    @EnvironmentObject private var settings: GlobalSettingsStore
    @Environment(\.accessibleColors) private var accessColors
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
    @State private var isFieldGuideOpen = false
    @State private var fieldGuidePageIndex = 0
    @State private var spokenTeacherIntroQuestionIDs: Set<String> = []

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

    private var currentQuestionReferencePages: [LectureQuizReferencePage] {
        currentQuestion.referencePages
    }

    private var currentFieldGuidePage: LectureQuizReferencePage? {
        guard !currentQuestionReferencePages.isEmpty else { return nil }
        let safeIndex = min(max(fieldGuidePageIndex, 0), currentQuestionReferencePages.count - 1)
        return currentQuestionReferencePages[safeIndex]
    }

    private var hasQuestionVisualPanel: Bool {
        (currentQuestion.sceneImageName?.isEmpty == false)
            || (currentQuestion.sceneImageCaption?.isEmpty == false)
            || !currentQuestionReferencePages.isEmpty
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

    private var studentGivesCorrectionFeedback: Bool {
        quiz.studentGivesCorrectionFeedback
    }

    private var teacherUsesFemaleVoice: Bool {
        let normalizedName = teacherDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedRole = teacherRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedImage = (quiz.teacherImageName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedRole.contains("ai")
            || normalizedName == "ploy"
            || normalizedImage == "unknow"
    }

    private func playerCorrectionText(for choice: LectureQuizOption) -> String {
        studentGivesCorrectionFeedback ? choice.feedback : "My answer: \(choice.text)"
    }

    private func teacherReplyText(for choice: LectureQuizOption) -> String {
        guard studentGivesCorrectionFeedback else { return choice.feedback }
        if choice.isBestAnswer {
            return "Ohh, got it. Thanks for correcting me. I should verify before I guess next time."
        }
        return "Hmm... maybe. Can we check the sign or field guide one more time before we save that?"
    }

    private var teacherIntroSpeechText: String? {
        if let aiGuessLine = currentQuestion.aiGuessLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !aiGuessLine.isEmpty {
            return aiGuessLine
        }
        return nil
    }

    private var teacherDialogText: String {
        if let selected = currentSelectedChoice {
            if isProfessorTypingCurrentQuestion {
                return professorTypedText.isEmpty ? "..." : professorTypedText
            }
            return teacherReplyText(for: selected)
        }
        if isTyping && !instructionText.isEmpty {
            return instructionText
        }
        if clampedQuestionIndex == 0, answeredCount == 0, !instructionText.isEmpty, !studentGivesCorrectionFeedback {
            return instructionText
        }
        if let aiGuessLine = currentQuestion.aiGuessLine, !aiGuessLine.isEmpty {
            return aiGuessLine
        }
        return "Question \(clampedQuestionIndex + 1): \(currentQuestion.question)"
    }

    private var studentDialogText: String {
        if let selected = currentSelectedChoice {
            return playerCorrectionText(for: selected)
        }
        if isTyping {
            return "..."
        }
        if !currentQuestionReferencePages.isEmpty {
            return studentGivesCorrectionFeedback
                ? "I need to correct \(teacherDisplayName) using the sign, clues, and field guide."
                : "I should look carefully and check the field guide before answering."
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

            if isFieldGuideOpen {
                fieldGuideOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            prepareShuffledChoicesIfNeeded()
            speakTeacherIntroIfNeeded()
        }
        .onChange(of: clampedQuestionIndex) { _, _ in
            isFieldGuideOpen = false
            fieldGuidePageIndex = 0
            speakTeacherIntroIfNeeded()
        }
        .onChange(of: isTyping) { _, typing in
            guard !typing else { return }
            speakTeacherIntroIfNeeded()
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

            Text(quiz.title)
                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
                            Text(studentGivesCorrectionFeedback ? "\(teacherDisplayName) is reacting..." : "\(teacherDisplayName) is replying...")
                                .font(.system(size: layout.captionFontSize + 1, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text(studentGivesCorrectionFeedback ? "\(teacherDisplayName) reacted." : "\(teacherDisplayName) feedback complete.")
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

                if hasQuestionVisualPanel {
                    questionVisualAndGuidePanel
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

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
                                ? [accessColors.success.opacity(0.95), accessColors.success.opacity(0.75)]
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
                Text(
                    studentGivesCorrectionFeedback
                        ? "Quiz complete. Review your corrections and \(teacherDisplayName)'s reactions below, then continue."
                        : "Quiz complete. Read \(teacherDisplayName)'s feedback below, then continue."
                )
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if completionSubmitted {
                Text("Recording your quiz result...")
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if shouldHideQuestionChoices {
                Text(
                    isProfessorTypingCurrentQuestion
                        ? (studentGivesCorrectionFeedback ? "Wait for \(teacherDisplayName)'s reaction..." : "Wait for \(teacherDisplayName)'s reply...")
                        : "Choose Next when you are ready."
                )
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: centerPanelMaxWidth)
        .padding(.top, 0)
        .animation(.easeInOut(duration: 0.22), value: shouldHideQuestionChoices)
        .animation(.easeInOut(duration: 0.18), value: isProfessorTypingCurrentQuestion)
        .animation(.easeInOut(duration: 0.18), value: clampedQuestionIndex)
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

    private var questionVisualAndGuidePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageName = currentQuestion.sceneImageName, !imageName.isEmpty {
                ZStack(alignment: .topLeading) {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: layout.isCompact ? 240 : 340)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.18),
                                    Color.black.opacity(0.45)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    HStack(spacing: 8) {
                        Label("Scene", systemImage: "photo")
                            .font(.system(size: layout.captionFontSize, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.52), in: Capsule())

                        if !currentQuestionReferencePages.isEmpty {
                            Text("Field Guide Available")
                                .font(.system(size: layout.captionFontSize - 1, weight: .bold))
                                .foregroundColor(.white.opacity(0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.70), in: Capsule())
                        }
                    }
                    .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
            }

            if let caption = currentQuestion.sceneImageCaption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !currentQuestionReferencePages.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        fieldGuidePageIndex = 0
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            isFieldGuideOpen = true
                        }
                    } label: {
                        Label(currentQuestion.referenceBookTitle ?? "Open Field Guide", systemImage: "book.closed.fill")
                            .font(.system(size: layout.isCompact ? 13 : 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.92), Color.yellow.opacity(0.84)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.26), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text("\(currentQuestionReferencePages.count) page\(currentQuestionReferencePages.count == 1 ? "" : "s")")
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var fieldGuideOverlay: some View {
        return ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFieldGuideOpen = false
                    }
                }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Label(currentQuestion.referenceBookTitle ?? "Field Guide", systemImage: "book.pages.fill")
                        .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer(minLength: 0)

                    Text("Page \(min(fieldGuidePageIndex + 1, max(currentQuestionReferencePages.count, 1))) / \(max(currentQuestionReferencePages.count, 1))")
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFieldGuideOpen = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .buttonStyle(.plain)
                }

                if let page = currentFieldGuidePage {
                    fieldGuidePageCard(page: page)
                        .id(page.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                } else {
                    VStack(spacing: 8) {
                        Text("No pages available for this question.")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Close the guide and answer using the visible clues.")
                            .font(.system(size: layout.captionFontSize + 1))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button {
                        guard fieldGuidePageIndex > 0 else { return }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            fieldGuidePageIndex -= 1
                        }
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                            .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                            .foregroundColor(fieldGuidePageIndex > 0 ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(fieldGuidePageIndex > 0 ? 0.12 : 0.05), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(fieldGuidePageIndex <= 0)

                    Spacer(minLength: 0)

                    Button {
                        guard fieldGuidePageIndex < currentQuestionReferencePages.count - 1 else { return }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            fieldGuidePageIndex += 1
                        }
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                            .foregroundColor(fieldGuidePageIndex < currentQuestionReferencePages.count - 1 ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(fieldGuidePageIndex < currentQuestionReferencePages.count - 1 ? 0.12 : 0.05), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(fieldGuidePageIndex >= currentQuestionReferencePages.count - 1)
                }
            }
            .padding(14)
            .frame(maxWidth: min(stageMaxWidth * 0.68, 720))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "1A212B"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 14)
        }
    }

    private func fieldGuidePageCard(page: LectureQuizReferencePage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(page.title)
                    .font(.system(size: layout.isCompact ? 16 : 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer(minLength: 0)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange.opacity(0.92))
            }

            if let imageName = page.imageName, !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: layout.isCompact ? 120 : 165)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }

            Text(page.text)
                .font(.system(size: layout.isCompact ? 13 : 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.86))
                .lineSpacing(layout.isCompact ? 3 : 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "2C2420"), Color(hex: "221B17")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func optionButton(_ choice: LectureQuizOption) -> some View {
        let selectedID = selectedChoiceIDByQuestionID[currentQuestion.id]
        let isSelected = selectedID == choice.id
        let isDisabled = isTyping || isCompleted || selectedID != nil
        let isResultReveal = selectedID != nil
        let isCorrect = choice.isBestAnswer
        let isWrong = !choice.isBestAnswer
        let isPulsing = pulsingChoiceID == choice.id
        let successColor = accessColors.success
        let errorColor = accessColors.error

        let fillColor: Color = {
            guard isResultReveal else {
                return isSelected ? Color.cyan.opacity(0.30) : Color.white.opacity(0.88)
            }
            if isCorrect {
                return isSelected ? successColor.opacity(0.34) : successColor.opacity(0.20)
            }
            if isWrong {
                return isSelected ? errorColor.opacity(0.30) : errorColor.opacity(0.16)
            }
            return Color.white.opacity(0.88)
        }()

        let strokeColor: Color = {
            guard isResultReveal else {
                return isSelected ? Color.cyan.opacity(0.95) : Color.black.opacity(0.05)
            }
            return isCorrect ? successColor.opacity(0.95) : errorColor.opacity(0.86)
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
                    HStack(spacing: 4) {
                        if settings.colorBlindMode {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .font(.system(size: layout.isCompact ? 16 : 18, weight: .bold))
                                .foregroundColor(isCorrect ? successColor.opacity(0.95) : errorColor.opacity(0.92))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                           Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                               .font(.system(size: layout.isCompact ? 16 : 18, weight: .bold))
                               .foregroundColor(isCorrect ? successColor.opacity(0.95) : errorColor.opacity(0.92))
                               .transition(.scale.combined(with: .opacity))
                        }
                    }
                } else if isSelected {
                    Image(systemName: "sparkles")
                        .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
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
                    ? (isCorrect ? successColor.opacity(0.30) : errorColor.opacity(0.28))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(role). \(text)")
    }

    private func select(_ choice: LectureQuizOption) {
        guard !isTyping, !isCompleted else { return }
        guard selectedChoiceIDByQuestionID[currentQuestion.id] == nil else { return }

        let questionID = currentQuestion.id

        withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
            selectedChoiceIDByQuestionID[questionID] = choice.id
            pulsingChoiceID = choice.id
        }

        speechManager.stop()
        let playerReply = playerCorrectionText(for: choice)
        _ = playerReply // Keep text generation for UI, but do not speak player lines.

        startProfessorTyping(feedback: teacherReplyText(for: choice), for: questionID)

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
            // Avoid two synthesizers speaking over each other; prioritize the AI teacher reply.
            playerSpeechManager.stop()
            speechManager.speak(
                feedback,
                emotion: .neutral,
                voiceProfile: teacherUsesFemaleVoice ? .playerFemale : .professorMale
            )
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
        professorTypedText = teacherReplyText(for: selected)
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

    private func speakTeacherIntroIfNeeded() {
        guard !isCompleted else { return }
        guard !isTyping else { return }
        guard currentSelectedChoice == nil else { return }
        guard !isProfessorTypingCurrentQuestion else { return }
        if clampedQuestionIndex == 0, answeredCount == 0, !instructionText.isEmpty, !studentGivesCorrectionFeedback {
            return
        }
        guard !spokenTeacherIntroQuestionIDs.contains(currentQuestion.id) else { return }
        guard let introText = teacherIntroSpeechText else { return }

        spokenTeacherIntroQuestionIDs.insert(currentQuestion.id)
        playerSpeechManager.stop()
        speechManager.speak(
            introText,
            emotion: .neutral,
            voiceProfile: teacherUsesFemaleVoice ? .playerFemale : .professorMale
        )
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

        let summaryPrefix = studentGivesCorrectionFeedback
            ? "You corrected \(teacherDisplayName) across \(answeredCount)/\(totalQuestions) scenes. "
            : "\(teacherDisplayName) reviewed \(answeredCount)/\(totalQuestions) questions. "

        let summary =
            summaryPrefix +
            "Best answers: \(bestAnswerCount)/\(totalQuestions). " +
            questionSummaries.joined(separator: " ") +
            " \(quiz.summaryNote)"

        onComplete(summary)
    }
}

struct BiasDataAuditMiniGameCard: View {
    let minigame: BiasDataAuditMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void

    @State private var selectionsByCardID: [String: String] = [:]
    @State private var currentCardIndex: Int = 0
    @State private var showFeedback: Bool = false
    @State private var feedbackCorrect: Bool = false
    @State private var configFeedbackMessage: String = ""
    @State private var noiseLevel: Double = 78
    @State private var diversityLevel: Double = 32
    @State private var labelQualityLevel: Double = 46
    @State private var showCompletionBanner: Bool = false
    @Environment(\.accessibleColors) private var accessColors

    private var totalCards: Int { minigame.cards.count }
    private var assignedCardsCount: Int { selectionsByCardID.count }

    private var correctCardsCount: Int {
        minigame.cards.reduce(into: 0) { count, card in
            if selectionsByCardID[card.id] == card.correctBucketID { count += 1 }
        }
    }

    private var allCardsAssigned: Bool { assignedCardsCount == totalCards && totalCards > 0 }
    private var sortPassed: Bool { allCardsAssigned && correctCardsCount == totalCards }
    private var configUnlocked: Bool { sortPassed || isCompleted }

    private var configPassed: Bool {
        noiseLevel <= minigame.noiseTargetMax
            && diversityLevel >= minigame.diversityTargetMin
            && labelQualityLevel >= minigame.labelQualityTargetMin
    }

    private var sortedBuckets: [BiasDataAuditBucket] { minigame.buckets }

    private var bucketByID: [String: BiasDataAuditBucket] {
        Dictionary(uniqueKeysWithValues: minigame.buckets.map { ($0.id, $0) })
    }

    private var currentCard: BiasDataAuditCard? {
        guard currentCardIndex < minigame.cards.count else { return nil }
        return minigame.cards[currentCardIndex]
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            headerSection
            progressBar
            if !sortPassed && !isCompleted {
                sortStepperSection
            } else {
                sortPassedBanner
            }
            configSection
            summarySection
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "181D25"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.04), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(minigame.title)
                    .font(.system(size: layout.captionFontSize + 2, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(minigame.promptLabel)
                    .font(.system(size: layout.captionFontSize, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Label("Lab", systemImage: "tray.2.fill")
                .font(.system(size: layout.captionFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(.cyan.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cyan.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Segmented Progress Bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(Array(minigame.cards.enumerated()), id: \.element.id) { index, card in
                    let selected = selectionsByCardID[card.id]
                    let isCorrect = selected == card.correctBucketID
                    let isSorted = selected != nil

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segmentColor(isSorted: isSorted, isCorrect: isCorrect))
                        .frame(height: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(index == currentCardIndex && !sortPassed && !isCompleted ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                }
            }
            HStack {
                Text("\(correctCardsCount)/\(totalCards) correct")
                    .font(.system(size: layout.captionFontSize - 1, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                if sortPassed || isCompleted {
                    Text("Sort complete")
                        .font(.system(size: layout.captionFontSize - 1, weight: .bold, design: .rounded))
                        .foregroundColor(accessColors.success.opacity(0.9))
                }
            }
        }
    }

    private func segmentColor(isSorted: Bool, isCorrect: Bool) -> Color {
        guard isSorted else { return Color.white.opacity(0.12) }
        return isCorrect ? accessColors.success.opacity(0.85) : Color.orange.opacity(0.75)
    }

    // MARK: - Sort Stepper (one card at a time)

    private var sortStepperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Step 1: Bias Detect / Data Quality Sort")
                    .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
            }

            if let card = currentCard {
                cardPresentation(card)
                    .id(card.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                if showFeedback {
                    feedbackPanel(for: card)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    bucketChips(for: card)
                        .transition(.opacity)
                }
            } else {
                allCardsSortedPrompt
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "11161D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.03), Color.clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentCardIndex)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showFeedback)
    }

    // MARK: - Card Presentation (large icon badge + text)

    private func cardPresentation(_ card: BiasDataAuditCard) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text("Case \(currentCardIndex + 1) of \(totalCards)")
                    .font(.system(size: layout.captionFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if currentCardIndex > 0 {
                    Button {
                        guard !showFeedback else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentCardIndex = max(0, currentCardIndex - 1)
                            showFeedback = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: layout.captionFontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                if let systemImage = card.systemImage {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Circle()
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 48, height: 48)
                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.system(size: layout.bodyFontSize + 1, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(card.detail)
                        .font(.system(size: layout.captionFontSize + 1, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "1B222C"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.04), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Horizontal Bucket Chips

    private func bucketChips(for card: BiasDataAuditCard) -> some View {
        let selectedID = selectionsByCardID[card.id]

        return VStack(alignment: .leading, spacing: 8) {
            Text("Classify this case:")
                .font(.system(size: layout.captionFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))

            FlowLayoutBucketChips(buckets: sortedBuckets, selectedID: selectedID, layout: layout, isCompleted: isCompleted) { bucket in
                guard !isCompleted else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectionsByCardID[card.id] = bucket.id
                    feedbackCorrect = bucket.id == card.correctBucketID
                    showFeedback = true
                }
            }
        }
    }

    // MARK: - Feedback Panel

    private func feedbackPanel(for card: BiasDataAuditCard) -> some View {
        let isCorrect = feedbackCorrect
        let selectedBucketID = selectionsByCardID[card.id]
        let selectedBucket = selectedBucketID.flatMap { bucketByID[$0] }
        let correctBucket = bucketByID[card.correctBucketID]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isCorrect ? accessColors.success : .orange)
                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(card.feedback)
                .font(.system(size: layout.captionFontSize + 1, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if !isCorrect {
                HStack(spacing: 6) {
                    if let sel = selectedBucket {
                        chipLabel(text: "You chose: \(sel.title)", color: .orange)
                    }
                    if let cor = correctBucket {
                        chipLabel(text: "Correct: \(cor.title)", color: accessColors.success)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectionsByCardID.removeValue(forKey: card.id)
                        showFeedback = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Again")
                    }
                    .font(.system(size: layout.captionFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.25), in: Capsule())
                    .overlay(Capsule().stroke(Color.orange.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if isCorrect {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showFeedback = false
                        if currentCardIndex < totalCards - 1 {
                            currentCardIndex += 1
                        } else {
                            currentCardIndex = totalCards
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentCardIndex < totalCards - 1 ? "Next Case" : "Finish Sorting")
                        Image(systemName: currentCardIndex < totalCards - 1 ? "arrow.right" : "checkmark")
                    }
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [Color.cyan.opacity(0.6), Color(hex: "2D5BFF").opacity(0.6)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            (isCorrect ? accessColors.success : Color.orange).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((isCorrect ? accessColors.success : Color.orange).opacity(0.30), lineWidth: 1)
        )
    }

    private func chipLabel(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: layout.captionFontSize, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - All Cards Sorted Prompt

    private var allCardsSortedPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundColor(accessColors.success)
            Text("All cases classified!")
                .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Sort accuracy: \(correctCardsCount)/\(totalCards). Move to Step 2.")
                .font(.system(size: layout.captionFontSize + 1, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(accessColors.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accessColors.success.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Sort Passed Banner (replaces stepper when done)

    private var sortPassedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(accessColors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Step 1 Complete")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("All \(totalCards) cases classified correctly")
                    .font(.system(size: layout.captionFontSize, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(12)
        .background(accessColors.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accessColors.success.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Config Section (Step 2)

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("Step 2: \(minigame.configTitle)")
                        .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer(minLength: 0)
                if configPassed && configUnlocked {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.system(size: layout.captionFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.92))
                }
            }

            if !configUnlocked {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Complete Step 1 to unlock configuration")
                        .font(.system(size: layout.captionFontSize, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
            } else {
                Text(minigame.configHint)
                    .font(.system(size: layout.captionFontSize + 1, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                gaugeSliderRow(
                    title: "Noise Level", subtitle: "Lower is better",
                    value: $noiseLevel,
                    targetText: "Target <= \(percentText(minigame.noiseTargetMax))",
                    targetPassed: noiseLevel <= minigame.noiseTargetMax,
                    tint: Color.orange, invertGauge: true
                )
                gaugeSliderRow(
                    title: "Dataset Diversity", subtitle: "Higher is better",
                    value: $diversityLevel,
                    targetText: "Target >= \(percentText(minigame.diversityTargetMin))",
                    targetPassed: diversityLevel >= minigame.diversityTargetMin,
                    tint: Color.mint, invertGauge: false
                )
                gaugeSliderRow(
                    title: "Label Quality", subtitle: "Higher is better",
                    value: $labelQualityLevel,
                    targetText: "Target >= \(percentText(minigame.labelQualityTargetMin))",
                    targetPassed: labelQualityLevel >= minigame.labelQualityTargetMin,
                    tint: Color.cyan, invertGauge: false
                )
            }
            .opacity(configUnlocked ? 1.0 : 0.35)
            .allowsHitTesting(configUnlocked && !isCompleted)

            Button(action: runAudit) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Run Bias/Data Audit")
                        .fontWeight(.bold)
                }
                .font(.system(size: layout.captionFontSize + 1, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: configUnlocked
                            ? [Color(hex: "1E879E"), Color.cyan.opacity(0.7)]
                            : [Color(hex: "2B313D"), Color(hex: "2B313D")],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(configUnlocked ? 0.16 : 0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!configUnlocked || isCompleted)

            if !configFeedbackMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: configPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(configPassed ? accessColors.success : .orange)
                    Text(configFeedbackMessage)
                        .font(.system(size: layout.captionFontSize + 1, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (configPassed ? accessColors.success : accessColors.warning).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke((configPassed ? accessColors.success : accessColors.warning).opacity(0.30), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "11161D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.02), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: configUnlocked)
    }

    // MARK: - Gauge Slider Row

    private func gaugeSliderRow(
        title: String, subtitle: String,
        value: Binding<Double>, targetText: String,
        targetPassed: Bool, tint: Color, invertGauge: Bool
    ) -> some View {
        HStack(spacing: 12) {
            // Circular gauge indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 42, height: 42)
                Circle()
                    .trim(from: 0, to: CGFloat(value.wrappedValue / 100.0))
                    .stroke(
                        targetPassed ? tint : tint.opacity(0.45),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                    Text(targetText)
                        .font(.system(size: layout.captionFontSize - 1, weight: .medium, design: .rounded))
                        .foregroundColor(targetPassed ? tint : .white.opacity(0.45))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            targetPassed ? tint.opacity(0.15) : Color.white.opacity(0.04),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(targetPassed ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                }

                Slider(value: value, in: 0...100, step: 1)
                    .tint(tint)

                Text(subtitle)
                    .font(.system(size: layout.captionFontSize - 1, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(10)
        .background(Color(hex: "171C24"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(targetPassed ? 0.35 : 0.10), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: targetPassed)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isCompleted && showCompletionBanner {
                completionCelebration
                    .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "sparkles" : "book.closed.fill")
                    .foregroundColor(isCompleted ? .yellow.opacity(0.9) : .white.opacity(0.7))
                Text(isCompleted ? "Lab Complete" : "Key Lesson")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(minigame.summaryNote)
                .font(.system(size: layout.captionFontSize + 1, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            if isCompleted {
                Text("You can continue the story now.")
                    .font(.system(size: layout.captionFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.mint.opacity(0.9))
            }
        }
        .padding(12)
        .background(Color(hex: "11161D"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Completion Celebration

    private var completionCelebration: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Audit Complete!")
                    .font(.system(size: layout.bodyFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Sorted \(correctCardsCount)/\(totalCards) cases. Bias & data quality optimized.")
                    .font(.system(size: layout.captionFontSize, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.12), Color.orange.opacity(0.08)],
                startPoint: .leading, endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func runAudit() {
        guard !isCompleted else { return }
        guard configUnlocked else {
            configFeedbackMessage = "Pass the sort board first to unlock the noise and bias controls."
            return
        }

        if configPassed {
            configFeedbackMessage = "Audit passed! Cleaner inputs + better diversity + label checks reduce bad-data failures and bias errors."

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showCompletionBanner = true
            }

            let summary = "Completed \(minigame.title). Sorted \(correctCardsCount)/\(totalCards) cases correctly. Final settings: noise \(percentText(noiseLevel)), diversity \(percentText(diversityLevel)), label quality \(percentText(labelQualityLevel)). \(minigame.summaryNote)"
            onComplete(summary)
        } else {
            var missing: [String] = []
            if noiseLevel > minigame.noiseTargetMax { missing.append("lower Noise Level") }
            if diversityLevel < minigame.diversityTargetMin { missing.append("increase Dataset Diversity") }
            if labelQualityLevel < minigame.labelQualityTargetMin { missing.append("increase Label Quality") }
            configFeedbackMessage = "Audit failed. \(missing.joined(separator: ", "))."
        }
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

// MARK: - Bucket Chips Flow Layout

private struct FlowLayoutBucketChips: View {
    let buckets: [BiasDataAuditBucket]
    let selectedID: String?
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onSelect: (BiasDataAuditBucket) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(buckets) { bucket in
                let isSelected = selectedID == bucket.id
                Button {
                    onSelect(bucket)
                } label: {
                    HStack(spacing: 6) {
                        if let systemImage = bucket.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: layout.captionFontSize, weight: .bold))
                        }
                        Text(bucket.title)
                            .font(.system(size: layout.captionFontSize, weight: .bold, design: .rounded))
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: layout.captionFontSize - 1, weight: .bold))
                        }
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        isSelected
                            ? Color(hex: bucket.accentHex).opacity(0.55)
                            : Color(hex: "242C38"),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected
                                    ? Color(hex: bucket.accentHex).opacity(0.85)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isCompleted)
            }
        }
    }
}

// MARK: - Classroom Stage Style Bias Data Audit (LectureQuiz Dialog Style)
struct ClassroomBiasDataAuditMiniGameStage: View {
    let minigame: BiasDataAuditMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let isTyping: Bool
    let instructionText: String
    let speaker: String
    let roleLabel: String?
    let characterImageName: String
    let onSkipTyping: () -> Void
    let onComplete: (String) -> Void
    let onContinue: () -> Void

    @State private var currentCardIndex = 0
    @State private var selectionsByCardID: [String: String] = [:]
    @State private var feedbackVisible = false
    @State private var showConfigStep = false
    @State private var noiseLevel: Double = 78
    @State private var diversityLevel: Double = 32
    @State private var labelQualityLevel: Double = 46
    @State private var hasSubmitted = false
    @Environment(\.accessibleColors) private var accessColors

    private var cards: [BiasDataAuditCard] { minigame.cards }

    private var currentCard: BiasDataAuditCard {
        cards[min(max(currentCardIndex, 0), max(cards.count - 1, 0))]
    }

    private var isLastCard: Bool { currentCardIndex >= cards.count - 1 }

    private var correctSortCount: Int {
        cards.reduce(0) { count, card in
            selectionsByCardID[card.id] == card.correctBucketID ? count + 1 : count
        }
    }

    private var configPassed: Bool {
        noiseLevel <= minigame.noiseTargetMax
            && diversityLevel >= minigame.diversityTargetMin
            && labelQualityLevel >= minigame.labelQualityTargetMin
    }

    private var currentSelectedBucket: BiasDataAuditBucket? {
        guard let bucketID = selectionsByCardID[currentCard.id] else { return nil }
        return minigame.buckets.first(where: { $0.id == bucketID })
    }

    private var isCurrentCardAnswered: Bool { currentSelectedBucket != nil }

    private var canGoNext: Bool {
        isCurrentCardAnswered && feedbackVisible && !isLastCard && !isCompleted
    }

    private var canShowConfig: Bool {
        isCurrentCardAnswered && feedbackVisible && isLastCard && !showConfigStep && !isCompleted
    }

    private var aiName: String { speaker.isEmpty ? "AI Friend" : speaker }

    // MARK: Layout Dimensions
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
        let lo: CGFloat = layout.isCompact ? 205 : 265
        let hi: CGFloat = layout.isCompact ? 350 : 610
        return min(max(layout.height * (layout.isCompact ? 0.33 : 0.47), lo), hi)
    }

    private var bottomDialogReserve: CGFloat {
        layout.width < 780 ? (layout.isCompact ? 220 : 240) : (layout.isCompact ? 190 : 220)
    }

    private var dialogVerticalLift: CGFloat {
        if layout.width < 780 {
            return layout.isCompact ? 58 : 72
        }
        return layout.isCompact ? 74 : 96
    }

    private var characterHorizontalPush: CGFloat {
        if layout.width < 700 { return 22 }
        if layout.width < 1000 { return 36 }
        return layout.isCompact ? 48 : 76
    }

    // MARK: Dialog Text
    private var dialogText: String {
        if showConfigStep {
            return configPassed
                ? "Settings look great! The data pipeline is much healthier now."
                : "Tune the sliders to improve the data quality before we finish."
        }
        if isCurrentCardAnswered, feedbackVisible {
            return currentCard.feedback
        }
        if isTyping && !instructionText.isEmpty { return instructionText }
        if currentCardIndex == 0 && !instructionText.isEmpty { return instructionText }
        return "Review this case and classify the issue."
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Character sprite layer (behind everything)
            characterLayer

            // Center content column
            VStack(spacing: layout.isCompact ? 6 : 8) {
                topUtilityRow

                VStack(spacing: 0) {
                    Spacer(minLength: layout.isCompact ? 8 : 12)

                    if showConfigStep {
                        configCenterPanel
                            .frame(maxWidth: centerPanelMaxWidth)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else {
                        centerCaseCard
                            .frame(maxWidth: centerPanelMaxWidth)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    Spacer(minLength: bottomDialogReserve)
                }
            }
            .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .top)

            // Bottom fade gradient
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

            // Bottom dialog + action buttons
            VStack(spacing: layout.isCompact ? 8 : 10) {
                Spacer()

                // Dialog pane
                bottomDialogPane

                // Action buttons
                bottomActionRow

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
                }
            }
            .frame(maxWidth: stageMaxWidth, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .padding(.bottom, dialogVerticalLift)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Character Layer
    private var characterLayer: some View {
        ZStack(alignment: .bottom) {
            HStack {
                Image(characterImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: min(layout.width * 0.38, 420),
                        maxHeight: spriteHeight,
                        alignment: .bottom
                    )
                    .offset(x: -characterHorizontalPush, y: -14)
                    .shadow(color: Color.cyan.opacity(0.12), radius: 20, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.32), radius: 12, x: 0, y: 10)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, layout.isCompact ? 6 : 10)
        .padding(.bottom, max(0, bottomDialogReserve - 30))
    }

    // MARK: - Top Utility Row
    private var topUtilityRow: some View {
        HStack(spacing: 10) {
            Text(showConfigStep ? "Calibration" : "Case \(currentCardIndex + 1) / \(cards.count)")
                .font(.system(size: layout.captionFontSize + 2, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.34), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Text(minigame.title)
                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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

    // MARK: - Center Case Card
    private var centerCaseCard: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            // Case info card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if let sysImg = currentCard.systemImage {
                        ZStack {
                            Circle()
                                .fill(Color.cyan.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: sysImg)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentCard.title)
                            .font(.system(size: layout.isCompact ? 16 : 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Case \(currentCardIndex + 1) of \(cards.count)")
                            .font(.system(size: layout.captionFontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                }

                Text(currentCard.detail)
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(layout.isCompact ? 16 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Color.black.opacity(0.45)
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 6)

            // Feedback card (after answering)
            if feedbackVisible, isCurrentCardAnswered {
                feedbackCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Navigation buttons
            if canGoNext || canShowConfig {
                Button {
                    if canGoNext { goToNextCard() }
                    else if canShowConfig { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showConfigStep = true } }
                } label: {
                    HStack(spacing: 8) {
                        Text(canGoNext ? "Next Case" : "Begin Calibration")
                        Image(systemName: canGoNext ? "arrow.right.circle.fill" : "slider.horizontal.3")
                    }
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.isCompact ? 11 : 13)
                    .background(
                        LinearGradient(
                            colors: canShowConfig
                                ? [accessColors.success.opacity(0.95), accessColors.success.opacity(0.75)]
                                : [Color.blue.opacity(0.95), Color.cyan.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Feedback Card
    private var feedbackCard: some View {
        let isCorrect = selectionsByCardID[currentCard.id] == currentCard.correctBucketID
        let selectedBucket = currentSelectedBucket
        let correctBucket = minigame.buckets.first(where: { $0.id == currentCard.correctBucketID })

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.system(size: 20))
                Text(isCorrect ? "Correct!" : "Not quite…")
                    .font(.system(size: layout.isCompact ? 15 : 17, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundColor(isCorrect ? accessColors.success : accessColors.warning)

            Text(currentCard.feedback)
                .font(.system(size: layout.isCompact ? 13 : 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            if !isCorrect, let selectedBucket, let correctBucket {
                HStack(spacing: 6) {
                    Text("You chose:")
                        .foregroundColor(.white.opacity(0.5))
                    Text(selectedBucket.title)
                        .foregroundColor(Color(hex: selectedBucket.accentHex))
                    Spacer()
                    Text("Answer:")
                        .foregroundColor(.white.opacity(0.5))
                    Text(correctBucket.title)
                        .foregroundColor(Color(hex: correctBucket.accentHex))
                        .fontWeight(.bold)
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(layout.isCompact ? 14 : 16)
        .background(
            (isCorrect ? accessColors.success : accessColors.warning).opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((isCorrect ? accessColors.success : accessColors.warning).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Config Center Panel
    private var configCenterPanel: some View {
        VStack(spacing: layout.isCompact ? 14 : 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                    Text("System Calibration")
                        .font(.system(size: layout.isCompact ? 18 : 22, weight: .bold, design: .rounded))
                }
                .foregroundColor(.cyan)

                Text(minigame.configHint)
                    .font(.system(size: layout.isCompact ? 13 : 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                configSlider(title: "Noise Filter Level", subtitle: "Target: ≤ \(Int(minigame.noiseTargetMax))%", value: $noiseLevel, passed: noiseLevel <= minigame.noiseTargetMax, tint: .orange)
                configSlider(title: "Dataset Diversity", subtitle: "Target: ≥ \(Int(minigame.diversityTargetMin))%", value: $diversityLevel, passed: diversityLevel >= minigame.diversityTargetMin, tint: .blue)
                configSlider(title: "Label Verification", subtitle: "Target: ≥ \(Int(minigame.labelQualityTargetMin))%", value: $labelQualityLevel, passed: labelQualityLevel >= minigame.labelQualityTargetMin, tint: .green)
            }

            HStack {
                Text("Sort accuracy: \(correctSortCount)/\(cards.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                if configPassed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("All targets met")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
                }
            }
        }
        .padding(layout.isCompact ? 16 : 22)
        .background(
            ZStack {
                Color.black.opacity(0.45)
                LinearGradient(
                    colors: [Color.cyan.opacity(0.04), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 6)
    }

    private func configSlider(title: String, subtitle: String, value: Binding<Double>, passed: Bool, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(passed ? tint : .white.opacity(0.4))
                Text(String(format: "%02d%%", Int(value.wrappedValue)))
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(passed ? tint : .white)
                    .frame(width: 45, alignment: .trailing)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(tint)
        }
        .padding(12)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(passed ? 0.25 : 0.05), lineWidth: 1)
        )
    }

    // MARK: - Bottom Dialog Pane
    private var bottomDialogPane: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(characterImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.cyan.opacity(0.45), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(aiName.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                Text(dialogText)
                    .font(.system(size: layout.isCompact ? 13 : 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Row
    private var bottomActionRow: some View {
        Group {
            if showConfigStep {
                Button(action: completeAudit) {
                    HStack(spacing: 8) {
                        Text(configPassed ? "Apply Calibration" : "Targets Not Met")
                        Image(systemName: configPassed ? "checkmark.circle.fill" : "lock.fill")
                    }
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(configPassed ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.isCompact ? 11 : 13)
                    .background(
                        configPassed
                            ? AnyShapeStyle(LinearGradient(colors: [accessColors.success.opacity(0.95), accessColors.success.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!configPassed || hasSubmitted)
                .opacity(hasSubmitted ? 0.6 : 1)
            } else if !isCurrentCardAnswered && !isCompleted {
                HStack(spacing: layout.isCompact ? 8 : 12) {
                    ForEach(minigame.buckets) { bucket in
                        bucketChoiceButton(bucket: bucket)
                    }
                }
            }
        }
    }

    // MARK: - Bucket Choice Button
    private func bucketChoiceButton(bucket: BiasDataAuditBucket) -> some View {
        let bucketColor = Color(hex: bucket.accentHex)
        return Button {
            selectBucket(bucket)
        } label: {
            VStack(spacing: 4) {
                if let sysImg = bucket.systemImage {
                    Image(systemName: sysImg)
                        .font(.system(size: layout.isCompact ? 16 : 18, weight: .bold))
                }
                Text(bucket.title)
                    .font(.system(size: layout.isCompact ? 10 : 12, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(bucketColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout.isCompact ? 12 : 14)
            .background(
                ZStack {
                    Color.black.opacity(0.5)
                    LinearGradient(
                        colors: [bucketColor.opacity(0.12), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(bucketColor.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isTyping || isCompleted)
    }

    // MARK: - Actions
    private func selectBucket(_ bucket: BiasDataAuditBucket) {
        guard selectionsByCardID[currentCard.id] == nil else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectionsByCardID[currentCard.id] = bucket.id
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                feedbackVisible = true
            }
        }
    }

    private func goToNextCard() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            feedbackVisible = false
            currentCardIndex = min(currentCardIndex + 1, max(cards.count - 1, 0))
        }
    }

    private func completeAudit() {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        let summary = "Completed \(minigame.title). Sorted \(correctSortCount)/\(cards.count) cases correctly. Final settings: noise \(Int(noiseLevel))%, diversity \(Int(diversityLevel))%, label quality \(Int(labelQualityLevel))%. \(minigame.summaryNote)"
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Choice: \(choice.text)")
        .accessibilityHint("Double tap to select this response")
        .accessibilityAddTraits(.isButton)
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
        case .curious: return .mint
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
    @State private var showcaseShakeOffset: CGFloat = 0
    @State private var showcaseShakeRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            if let messagesThread = showcase.messagesThread {
                messagesShowcasePanel(messagesThread)
            } else {
                imageShowcasePanel
            }

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

    private var imageShowcasePanel: some View {
        let panelHeight = showcase.animatesShake
            ? (layout.isCompact ? 190.0 : 255.0)
            : (layout.isCompact ? 140.0 : 180.0)

        return ZStack(alignment: .topLeading) {
            Group {
                if showcase.imageName == "__clock_placeholder__" {
                    PlaceholderClockHeroCard()
                } else {
                    Image(showcase.imageName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .offset(x: showcase.animatesShake ? showcaseShakeOffset : 0)
            .rotationEffect(.degrees(showcase.animatesShake ? showcaseShakeRotation : 0))
            .frame(height: panelHeight)
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
        .onAppear {
            guard showcase.animatesShake else { return }
            showcaseShakeOffset = 0
            showcaseShakeRotation = 0
            withAnimation(.easeInOut(duration: 0.085).repeatForever(autoreverses: true)) {
                showcaseShakeOffset = 3.2
                showcaseShakeRotation = 1.2
            }
        }
    }

    private func messagesShowcasePanel(_ thread: DialogShowcaseMessagesThread) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Messages")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold))
                    .foregroundColor(.black.opacity(0.82))

                Spacer(minLength: 0)

                Text(thread.contactName)
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.black.opacity(0.62))

                if let badge = showcase.badge {
                    Text(badge)
                        .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.10), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.97, green: 0.97, blue: 0.99))

            Divider()
                .overlay(Color.black.opacity(0.07))

            VStack(spacing: 8) {
                ForEach(Array(thread.messages.suffix(6))) { message in
                    messagesShowcaseBubble(message)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: layout.isCompact ? 132 : 160, alignment: .top)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.isCompact ? 14 : 18, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
    }

    private func messagesShowcaseBubble(_ message: DialogShowcaseChatMessage) -> some View {
        HStack {
            if message.isFromPlayer {
                Spacer(minLength: 34)
            }

            Text(message.text)
                .font(.system(size: layout.captionFontSize + 1, weight: .medium))
                .foregroundColor(message.isFromPlayer ? .white : Color.black.opacity(0.82))
                .lineLimit(3)
                .multilineTextAlignment(message.isFromPlayer ? .trailing : .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    message.isFromPlayer
                        ? Color(hex: "2D8CFF")
                        : Color(hex: "ECECF1"),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            if !message.isFromPlayer {
                Spacer(minLength: 34)
            }
        }
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


// MARK: - Messenger Style Lecture Quiz (Chapter 2 Style)
// A chat-based quiz UI similar to PromptBuilder - fade dialogs instead of boxes

struct MessengerLectureQuizMiniGameStage: View {
    let quiz: LectureQuizMiniGame
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

    @State private var currentQuestionIndex = 0
    @State private var selectedChoiceIDByQuestionID: [String: String] = [:]
    @State private var chatMessages: [DialogShowcaseChatMessage] = []
    @State private var isShowingChoices = false
    @State private var hasSubmitted = false
    @EnvironmentObject private var settings: GlobalSettingsStore

    private var questions: [LectureQuizQuestion] {
        quiz.questions.isEmpty
            ? [LectureQuizQuestion(id: "fallback", question: "No question available", choices: [])]
            : quiz.questions
    }

    private var currentQuestion: LectureQuizQuestion {
        let index = min(max(currentQuestionIndex, 0), max(questions.count - 1, 0))
        return questions[index]
    }

    private var isLastQuestion: Bool {
        currentQuestionIndex >= questions.count - 1
    }

    private var allQuestionsAnswered: Bool {
        questions.allSatisfy { selectedChoiceIDByQuestionID[$0.id] != nil }
    }

    private var aiName: String {
        quiz.teacherName.isEmpty ? "AI Friend" : quiz.teacherName
    }

    private var playerName: String {
        quiz.studentName.isEmpty ? "You" : quiz.studentName
    }

    private var usesStackedLayout: Bool {
        availableWidth < 940 || availableHeight < 700
    }

    private var phonePanelWidth: CGFloat {
        min(max(availableWidth * 0.64, 520), 980)
    }

    private var phoneWideUpOffset: CGFloat {
        min(max(availableHeight * 0.12, 64), 150)
    }

    private var emotionAccent: Color {
        switch emotion {
        case .happy, .excited: return Color(hex: "5CE38C")
        case .sad, .concerned: return Color(hex: "8ED0F7")

        case .curious: return Color(hex: "4AB0FF")
        case .neutral: return Color.white.opacity(0.85)
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
                        .frame(minHeight: min(max(availableHeight * 0.48, 250), 430))
                }
            } else {
                wideLayoutStage
            }

            if isCompleted || allQuestionsAnswered {
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
        .onAppear {
            initializeChat()
        }
    }

    private var phonePanel: some View {
        VStack(spacing: 0) {
            // Phone header
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "2D8CFF"))

                Image(characterImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                VStack(alignment: .leading, spacing: 1) {
                    Text(aiName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    Text(roleLabel ?? "AI Friend")
                        .font(.system(size: 11))
                        .foregroundColor(Color.black.opacity(0.5))
                }

                Spacer()

                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "2D8CFF"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            )

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(chatMessages) { message in
                            chatBubbleRow(message: message)
                        }

                        if isShowingChoices && !isTyping && !hasSubmitted {
                            choicesPanel
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .background(Color.white)
                .onChange(of: chatMessages.count) { _ in
                    if let last = chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 32, x: 0, y: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var heroPanel: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            if !usesStackedLayout {
                wideTopUtilityRow
            }

            HStack(spacing: layout.isCompact ? 12 : 18) {
                Image(characterImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: min(max(availableHeight * (usesStackedLayout ? 0.30 : 0.56), 200), usesStackedLayout ? 300 : 520))
                    .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)

                if !usesStackedLayout {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(aiName)
                            .font(.system(size: layout.isCompact ? 20 : 26, weight: .heavy))
                            .foregroundColor(.white)
                        if let roleLabel, !roleLabel.isEmpty {
                            Text(roleLabel)
                                .font(.system(size: layout.isCompact ? 14 : 17, weight: .medium))
                                .foregroundColor(emotionAccent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !instructionText.isEmpty {
                Text(instructionText)
                    .font(.system(size: layout.isCompact ? 13 : 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(isTyping ? 0.92 : 0.82))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, layout.isCompact ? 14 : 18)
                    .padding(.vertical, layout.isCompact ? 10 : 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, layout.isCompact ? 12 : 16)
        .padding(.vertical, layout.isCompact ? 10 : 14)
    }

    private var wideLayoutStage: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: layout.isCompact ? 6 : 8) {
                    wideTopUtilityRow

                    VStack(spacing: 0) {
                        Spacer(minLength: layout.isCompact ? 8 : 12)

                        phonePanel
                            .frame(width: min(availableWidth * 0.52, 840))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: -phoneWideUpOffset)

                        Spacer(minLength: min(max(availableHeight * 0.18, 178), 210))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .zIndex(0)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.black.opacity(0.22), location: 0.70),
                        .init(color: Color.black.opacity(0.55), location: 0.85),
                        .init(color: Color.black.opacity(0.78), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(1)

                wideBottomDialogOverlay
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                    .zIndex(10)

                wideCharacterLayer
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                    .zIndex(5)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomSceneFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: Color.black.opacity(0.15), location: 0.58),
                .init(color: Color.black.opacity(0.45), location: 0.78),
                .init(color: Color.black.opacity(0.78), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var wideCharacterLayer: some View {
        HStack {
            Image(characterImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: min(min(availableWidth, 1480) * 0.26, 360), maxHeight: min(max(availableHeight * 0.46, 280), 520), alignment: .bottom)
                .offset(x: availableWidth < 1200 ? -12 : (availableWidth < 1450 ? -24 : -38), y: -(layout.isCompact ? 14 : 22))
                .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
                .allowsHitTesting(false)

            Spacer(minLength: 0)
        }
    }

    private var wideTopUtilityRow: some View {
        HStack {
            Spacer()
        }
    }

    private var wideBottomDialogOverlay: some View {
        HStack(alignment: .bottom, spacing: 0) {
            heroPanel
                .frame(width: min(availableWidth * 0.38, 520), alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, layout.isCompact ? 16 : 28)
        .padding(.bottom, layout.isCompact ? 20 : 32)
    }

    private func chatBubbleRow(message: DialogShowcaseChatMessage) -> some View {
        HStack {
            if message.isFromPlayer {
                Spacer(minLength: 46)
            }

            Text(message.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(message.isFromPlayer ? .white : Color.black.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    message.isFromPlayer ? Color(hex: "2D8CFF") : Color(hex: "E9E9EE"),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            if !message.isFromPlayer {
                Spacer(minLength: 46)
            }
        }
        .id(message.id)
        .transition(.asymmetric(insertion: .move(edge: message.isFromPlayer ? .trailing : .leading).combined(with: .opacity), removal: .opacity))
    }

    private var choicesPanel: some View {
        VStack(spacing: 8) {
            Text("Choose your answer:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 8)

            ForEach(currentQuestion.choices) { choice in
                choiceButton(for: choice)
            }
        }
    }

    private func choiceButton(for choice: LectureQuizOption) -> some View {
        let isSelected = selectedChoiceIDByQuestionID[currentQuestion.id] == choice.id

        return Button {
            selectChoice(choice)
        } label: {
            HStack(spacing: 10) {
                if let icon = choice.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .white : Color.black.opacity(0.6))
                        .frame(width: 20)
                }

                Text(choice.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color.black.opacity(0.85))
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    HStack(spacing: 4) {
                        if settings.colorBlindMode {
                            Image(systemName: choice.isBestAnswer ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(hex: "2D8CFF") : Color(hex: "F2F2F7"))
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedChoiceIDByQuestionID[currentQuestion.id] != nil)
    }

    private func initializeChat() {
        chatMessages = []
        isShowingChoices = false
        hasSubmitted = false

        // Add intro message from AI
        if let aiGuess = currentQuestion.aiGuessLine, !aiGuess.isEmpty {
            chatMessages.append(DialogShowcaseChatMessage(
                id: "intro-\(currentQuestion.id)",
                text: aiGuess.replacingOccurrences(of: "{{ai_name}}:", with: "").trimmingCharacters(in: .whitespaces),
                isFromPlayer: false
            ))
        } else {
            chatMessages.append(DialogShowcaseChatMessage(
                id: "intro-\(currentQuestion.id)",
                text: currentQuestion.question,
                isFromPlayer: false
            ))
        }

        // Show choices after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isShowingChoices = true
            }
        }
    }

    private func selectChoice(_ choice: LectureQuizOption) {
        guard selectedChoiceIDByQuestionID[currentQuestion.id] == nil else { return }

        selectedChoiceIDByQuestionID[currentQuestion.id] = choice.id

        // Add player's answer to chat
        chatMessages.append(DialogShowcaseChatMessage(
            id: "answer-\(currentQuestion.id)",
            text: choice.text,
            isFromPlayer: true
        ))

        // Add feedback from AI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let feedbackText = choice.isBestAnswer
                ? choice.feedback
                : "Hmm... \(choice.feedback)"

            withAnimation {
                chatMessages.append(DialogShowcaseChatMessage(
                    id: "feedback-\(currentQuestion.id)",
                    text: feedbackText,
                    isFromPlayer: false
                ))
            }

            // Move to next question or complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if isLastQuestion {
                    hasSubmitted = true
                    let summary = buildSummary()
                    onComplete(summary)
                } else {
                    currentQuestionIndex += 1
                    loadNextQuestion()
                }
            }
        }
    }

    private func loadNextQuestion() {
        let nextQuestion = currentQuestion

        // Add question from AI
        if let aiGuess = nextQuestion.aiGuessLine, !aiGuess.isEmpty {
            chatMessages.append(DialogShowcaseChatMessage(
                id: "intro-\(nextQuestion.id)",
                text: aiGuess.replacingOccurrences(of: "{{ai_name}}:", with: "").trimmingCharacters(in: .whitespaces),
                isFromPlayer: false
            ))
        } else {
            chatMessages.append(DialogShowcaseChatMessage(
                id: "intro-\(nextQuestion.id)",
                text: nextQuestion.question,
                isFromPlayer: false
            ))
        }

        isShowingChoices = true
    }

    private func buildSummary() -> String {
        let correctCount = questions.reduce(0) { count, question in
            guard let selectedID = selectedChoiceIDByQuestionID[question.id],
                  let selected = question.choices.first(where: { $0.id == selectedID }),
                  selected.isBestAnswer else { return count }
            return count + 1
        }
        return "Quiz complete: \(correctCount)/\(questions.count) correct. \(quiz.summaryNote)"
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
