import Foundation

// MARK: - Story Script Models
// Edit these models/chapter files to change background, character, emotion, text, image, and event content.

struct DialogShowcaseMedia: Sendable {
    let title: String
    let subtitle: String
    let imageName: String
    let badge: String?

    init(title: String, subtitle: String, imageName: String, badge: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.badge = badge
    }
}

enum DialogEventType: String, Sendable {
    case mobileChat
    case hallucinationBias
    case memoryTraining
}

struct DialogEventMetric: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: String
    let accentHex: String?

    init(label: String, value: String, accentHex: String? = nil) {
        self.label = label
        self.value = value
        self.accentHex = accentHex
    }
}

struct DialogEventPayload: Identifiable, Sendable {
    let id = UUID()
    let type: DialogEventType
    let title: String
    let subtitle: String
    let imageName: String?
    let ctaTitle: String
    let hookName: String
    let metrics: [DialogEventMetric]
    let tags: [String]

    init(
        type: DialogEventType,
        title: String,
        subtitle: String,
        imageName: String? = nil,
        ctaTitle: String,
        hookName: String,
        metrics: [DialogEventMetric] = [],
        tags: [String] = []
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.ctaTitle = ctaTitle
        self.hookName = hookName
        self.metrics = metrics
        self.tags = tags
    }
}

struct StoryDialogLine: Sendable {
    let speaker: String
    let text: String
    let emotion: Emotion
    let backgroundImage: String?
    let characterImage: String?
    let cutsceneTitle: String?
    let cutsceneSubtitle: String?
    let showcaseMedia: DialogShowcaseMedia?
    let eventPayload: DialogEventPayload?
    let choices: [DialogChoice]?
    let requiresInput: Bool
    let inputPlaceholder: String?

    init(
        speaker: String,
        text: String,
        emotion: Emotion,
        backgroundImage: String? = nil,
        characterImage: String? = nil,
        cutsceneTitle: String? = nil,
        cutsceneSubtitle: String? = nil,
        showcaseMedia: DialogShowcaseMedia? = nil,
        eventPayload: DialogEventPayload? = nil,
        choices: [DialogChoice]? = nil,
        requiresInput: Bool = false,
        inputPlaceholder: String? = nil
    ) {
        self.speaker = speaker
        self.text = text
        self.emotion = emotion
        self.backgroundImage = backgroundImage
        self.characterImage = characterImage
        self.cutsceneTitle = cutsceneTitle
        self.cutsceneSubtitle = cutsceneSubtitle
        self.showcaseMedia = showcaseMedia
        self.eventPayload = eventPayload
        self.choices = choices
        self.requiresInput = requiresInput
        self.inputPlaceholder = inputPlaceholder
    }

    func asDialogNode() -> DialogNode {
        DialogNode(
            speaker: speaker,
            text: text,
            emotion: emotion,
            choices: choices,
            requiresInput: requiresInput,
            inputPlaceholder: inputPlaceholder,
            backgroundImage: backgroundImage,
            characterImage: characterImage ?? StoryCharacterAsset.placeholder(for: emotion),
            cutsceneTitle: cutsceneTitle,
            cutsceneSubtitle: cutsceneSubtitle,
            showcaseMedia: showcaseMedia,
            eventPayload: eventPayload
        )
    }
}

struct StoryChapter: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let accentHex: String
    let coverBackgroundImage: String
    let coverCharacterImage: String
    let overview: String
    let lines: [StoryDialogLine]

    var nodes: [DialogNode] {
        lines.map { $0.asDialogNode() }
    }

    var eventCount: Int {
        lines.filter { $0.eventPayload != nil }.count
    }
}

enum StoryCharacterAsset {
    static func placeholder(for emotion: Emotion) -> String {
        "char_\(emotion.rawValue)"
    }
}

enum StoryChapterRepository {
    static let all: [StoryChapter] = [
        chapterOneStory,
        chapterTwoStory,
        chapterThreeStory
    ]
}

