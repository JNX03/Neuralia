import Foundation

// MARK: - Story Script Models
// Edit these models/chapter files to change background, character, emotion, text, image, and choice content.

struct DialogShowcaseMedia: Sendable {
    let title: String
    let subtitle: String
    let imageName: String
    let badge: String?
    let prefersSplitLayout: Bool
    let messagesThread: DialogShowcaseMessagesThread?
    let animatesShake: Bool

    init(
        title: String,
        subtitle: String,
        imageName: String,
        badge: String? = nil,
        prefersSplitLayout: Bool = false,
        messagesThread: DialogShowcaseMessagesThread? = nil,
        animatesShake: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.badge = badge
        self.prefersSplitLayout = prefersSplitLayout
        self.messagesThread = messagesThread
        self.animatesShake = animatesShake
    }
}

struct DialogShowcaseChatMessage: Identifiable, Sendable {
    let id: String
    let text: String
    let isFromPlayer: Bool

    init(id: String, text: String, isFromPlayer: Bool) {
        self.id = id
        self.text = text
        self.isFromPlayer = isFromPlayer
    }
}

struct DialogShowcaseMessagesThread: Sendable {
    let contactName: String
    let messages: [DialogShowcaseChatMessage]

    init(contactName: String, messages: [DialogShowcaseChatMessage]) {
        self.contactName = contactName
        self.messages = messages
    }
}

struct DialogVideoClip: Sendable {
    let title: String
    let subtitle: String?
    let resourceName: String
    let fileExtension: String
    let autoplay: Bool

    init(
        title: String,
        subtitle: String? = nil,
        resourceName: String,
        fileExtension: String = "mp4",
        autoplay: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.resourceName = resourceName
        self.fileExtension = fileExtension
        self.autoplay = autoplay
    }
}

struct PromptBuilderOption: Identifiable, Sendable {
    let id: String
    let chipText: String
    let promptText: String
    let feedbackNote: String

    init(id: String, chipText: String, promptText: String? = nil, feedbackNote: String) {
        self.id = id
        self.chipText = chipText
        self.promptText = promptText ?? chipText
        self.feedbackNote = feedbackNote
    }
}

struct PromptBuilderSlot: Identifiable, Sendable {
    let id: String
    let label: String
    let placeholder: String
    let options: [PromptBuilderOption]
    let recommendedOptionID: String

    init(
        id: String,
        label: String,
        placeholder: String,
        options: [PromptBuilderOption],
        recommendedOptionID: String
    ) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.options = options
        self.recommendedOptionID = recommendedOptionID
    }
}

struct PromptBuilderMiniGame: Sendable {
    let title: String
    let contactName: String
    let introMessage: String
    let chatHistory: [DialogShowcaseChatMessage]
    let includesChapterOneFollowupChat: Bool
    let followupRenameVariableKey: String?
    let followupDefaultAIName: String
    let slots: [PromptBuilderSlot]
    let tip: String?

    init(
        title: String,
        contactName: String = "Unknown User",
        introMessage: String,
        chatHistory: [DialogShowcaseChatMessage] = [],
        includesChapterOneFollowupChat: Bool = false,
        followupRenameVariableKey: String? = nil,
        followupDefaultAIName: String = "Ploy",
        slots: [PromptBuilderSlot],
        tip: String? = nil
    ) {
        self.title = title
        self.contactName = contactName
        self.introMessage = introMessage
        self.chatHistory = chatHistory
        self.includesChapterOneFollowupChat = includesChapterOneFollowupChat
        self.followupRenameVariableKey = followupRenameVariableKey
        self.followupDefaultAIName = followupDefaultAIName
        self.slots = slots
        self.tip = tip
    }
}

struct LectureQuizOption: Identifiable, Sendable {
    let id: String
    let text: String
    let feedback: String
    let isBestAnswer: Bool
    let icon: String?

    init(
        id: String,
        text: String,
        feedback: String,
        isBestAnswer: Bool = false,
        icon: String? = nil
    ) {
        self.id = id
        self.text = text
        self.feedback = feedback
        self.isBestAnswer = isBestAnswer
        self.icon = icon
    }
}

struct LectureQuizQuestion: Identifiable, Sendable {
    let id: String
    let question: String
    let choices: [LectureQuizOption]
    let aiGuessLine: String?
    let sceneImageName: String?
    let sceneImageCaption: String?
    let referenceBookTitle: String?
    let referencePages: [LectureQuizReferencePage]

    init(
        id: String,
        question: String,
        choices: [LectureQuizOption],
        aiGuessLine: String? = nil,
        sceneImageName: String? = nil,
        sceneImageCaption: String? = nil,
        referenceBookTitle: String? = nil,
        referencePages: [LectureQuizReferencePage] = []
    ) {
        self.id = id
        self.question = question
        self.choices = choices
        self.aiGuessLine = aiGuessLine
        self.sceneImageName = sceneImageName
        self.sceneImageCaption = sceneImageCaption
        self.referenceBookTitle = referenceBookTitle
        self.referencePages = referencePages
    }
}

struct LectureQuizReferencePage: Identifiable, Sendable {
    let id: String
    let title: String
    let text: String
    let imageName: String?

    init(
        id: String,
        title: String,
        text: String,
        imageName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.imageName = imageName
    }
}

struct LectureQuizMiniGame: Sendable {
    let title: String
    let promptLabel: String
    let exampleImageName: String?
    let exampleCaption: String?
    let questions: [LectureQuizQuestion]
    let summaryNote: String
    let teacherName: String
    let teacherRole: String?
    let teacherImageName: String?
    let studentName: String
    let studentRole: String?
    let studentImageName: String?
    let usesClassroomStageLayout: Bool
    let studentGivesCorrectionFeedback: Bool

    var question: String {
        questions.first?.question ?? ""
    }

    var choices: [LectureQuizOption] {
        questions.first?.choices ?? []
    }

    init(
        title: String,
        question: String,
        promptLabel: String = "Professor New asks:",
        exampleImageName: String? = nil,
        exampleCaption: String? = nil,
        choices: [LectureQuizOption],
        summaryNote: String,
        teacherName: String = "Professor New",
        teacherRole: String? = "Teacher",
        teacherImageName: String? = nil,
        studentName: String = "You",
        studentRole: String? = "Student",
        studentImageName: String? = nil,
        usesClassroomStageLayout: Bool = false,
        studentGivesCorrectionFeedback: Bool = false
    ) {
        self.title = title
        self.promptLabel = promptLabel
        self.exampleImageName = exampleImageName
        self.exampleCaption = exampleCaption
        self.questions = [
            LectureQuizQuestion(
                id: "q1",
                question: question,
                choices: choices
            )
        ]
        self.summaryNote = summaryNote
        self.teacherName = teacherName
        self.teacherRole = teacherRole
        self.teacherImageName = teacherImageName
        self.studentName = studentName
        self.studentRole = studentRole
        self.studentImageName = studentImageName
        self.usesClassroomStageLayout = usesClassroomStageLayout
        self.studentGivesCorrectionFeedback = studentGivesCorrectionFeedback
    }

    init(
        title: String,
        questions: [LectureQuizQuestion],
        promptLabel: String = "Professor New asks:",
        exampleImageName: String? = nil,
        exampleCaption: String? = nil,
        summaryNote: String,
        teacherName: String = "Professor New",
        teacherRole: String? = "Teacher",
        teacherImageName: String? = nil,
        studentName: String = "You",
        studentRole: String? = "Student",
        studentImageName: String? = nil,
        usesClassroomStageLayout: Bool = false,
        studentGivesCorrectionFeedback: Bool = false
    ) {
        self.title = title
        self.promptLabel = promptLabel
        self.exampleImageName = exampleImageName
        self.exampleCaption = exampleCaption
        self.questions = questions
        self.summaryNote = summaryNote
        self.teacherName = teacherName
        self.teacherRole = teacherRole
        self.teacherImageName = teacherImageName
        self.studentName = studentName
        self.studentRole = studentRole
        self.studentImageName = studentImageName
        self.usesClassroomStageLayout = usesClassroomStageLayout
        self.studentGivesCorrectionFeedback = studentGivesCorrectionFeedback
    }
}

struct BiasDataAuditBucket: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let accentHex: String
    let systemImage: String?

    init(
        id: String,
        title: String,
        description: String,
        accentHex: String,
        systemImage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.accentHex = accentHex
        self.systemImage = systemImage
    }
}

struct BiasDataAuditCard: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let correctBucketID: String
    let feedback: String
    let systemImage: String?

    init(
        id: String,
        title: String,
        detail: String,
        correctBucketID: String,
        feedback: String,
        systemImage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.correctBucketID = correctBucketID
        self.feedback = feedback
        self.systemImage = systemImage
    }
}

struct BiasDataAuditMiniGame: Sendable {
    let title: String
    let promptLabel: String
    let buckets: [BiasDataAuditBucket]
    let cards: [BiasDataAuditCard]
    let configTitle: String
    let configHint: String
    let noiseTargetMax: Double
    let diversityTargetMin: Double
    let labelQualityTargetMin: Double
    let summaryNote: String

    init(
        title: String,
        promptLabel: String,
        buckets: [BiasDataAuditBucket],
        cards: [BiasDataAuditCard],
        configTitle: String,
        configHint: String,
        noiseTargetMax: Double,
        diversityTargetMin: Double,
        labelQualityTargetMin: Double,
        summaryNote: String
    ) {
        self.title = title
        self.promptLabel = promptLabel
        self.buckets = buckets
        self.cards = cards
        self.configTitle = configTitle
        self.configHint = configHint
        self.noiseTargetMax = noiseTargetMax
        self.diversityTargetMin = diversityTargetMin
        self.labelQualityTargetMin = labelQualityTargetMin
        self.summaryNote = summaryNote
    }
}

struct Chapter3KNNRescueMiniGame: Sendable {
    let title: String
    let promptLabel: String
    let trainingLabels: [String]
    let minTrainingSamples: Int
    let requiredCorrectTests: Int
    let maxTestRounds: Int
    let fallbackHint: String
    let summaryNote: String

    init(
        title: String,
        promptLabel: String,
        trainingLabels: [String],
        minTrainingSamples: Int = 4,
        requiredCorrectTests: Int = 2,
        maxTestRounds: Int = 3,
        fallbackHint: String,
        summaryNote: String
    ) {
        self.title = title
        self.promptLabel = promptLabel
        self.trainingLabels = trainingLabels
        self.minTrainingSamples = minTrainingSamples
        self.requiredCorrectTests = requiredCorrectTests
        self.maxTestRounds = maxTestRounds
        self.fallbackHint = fallbackHint
        self.summaryNote = summaryNote
    }
}

enum DialogInlineActivity: Sendable {
    case video(DialogVideoClip)
    case promptBuilder(PromptBuilderMiniGame)
    case lectureQuiz(LectureQuizMiniGame)
    case biasDataAudit(BiasDataAuditMiniGame)
    case chapter3KNNRescue(Chapter3KNNRescueMiniGame)
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
    let inputVariableKey: String?
    let inputDefaultValue: String?
    let inlineActivity: DialogInlineActivity?

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
        inputPlaceholder: String? = nil,
        inputVariableKey: String? = nil,
        inputDefaultValue: String? = nil,
        inlineActivity: DialogInlineActivity? = nil
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
        self.inputVariableKey = inputVariableKey
        self.inputDefaultValue = inputDefaultValue
        self.inlineActivity = inlineActivity
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
            inputVariableKey: inputVariableKey,
            inputDefaultValue: inputDefaultValue,
            inlineActivity: inlineActivity
        )
    }
}

struct StoryChapter: Identifiable, Sendable, Hashable {
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

    static func == (lhs: StoryChapter, rhs: StoryChapter) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
