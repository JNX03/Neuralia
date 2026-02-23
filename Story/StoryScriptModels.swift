import Foundation

// MARK: - Story Script Models
// Edit these models/chapter files to change background, character, emotion, text, image, and choice content.

struct DialogShowcaseMedia: Sendable {
    let title: String
    let subtitle: String
    let imageName: String
    let badge: String?
    let prefersSplitLayout: Bool

    init(
        title: String,
        subtitle: String,
        imageName: String,
        badge: String? = nil,
        prefersSplitLayout: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.badge = badge
        self.prefersSplitLayout = prefersSplitLayout
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
            showcaseMedia: showcaseMedia
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
