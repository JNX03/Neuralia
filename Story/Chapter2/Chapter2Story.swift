import Foundation

let chapterTwoStory = StoryChapter(
    id: "chapter2",
    title: "New Friend?",
    subtitle: "Growing Connection",
    accentHex: "8B5CF6",
    coverBackgroundImage: "schooltopview",
    coverCharacterImage: "char_concerned",
    overview: "Shows an image panel and a temporary hallucination/bias event screen to explain wrong AI guesses.",
    lines: [
        StoryDialogLine(
            speaker: "Ploy",
            text: "Now we inspect an image result. The model looks confident, but confidence is not the same as accuracy.",
            emotion: .concerned,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Analysis Room",
            cutsceneSubtitle: "Visual inspection phase",
            showcaseMedia: DialogShowcaseMedia(
                title: "Observed Frame",
                subtitle: "Example asset for bias/hallucination review (swap image later).",
                imageName: "cnxgate",
                badge: "AI Vision Input"
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "This event screen can become your real bias / hallucination mini game. Right now it is a stylized temp UI with data points and a hook function.",
            emotion: .surprised,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Alert",
            cutsceneSubtitle: "Hallucination detected",
            eventPayload: DialogEventPayload(
                type: .hallucinationBias,
                title: "Bias & Hallucination Event",
                subtitle: "Compare model guess, ground truth, and bias source before training.",
                imageName: "cnxgate",
                ctaTitle: "Call Bias Review Event",
                hookName: "launchBiasHallucinationReview()",
                metrics: [
                    DialogEventMetric(label: "Model Guess", value: "Ancient Temple"),
                    DialogEventMetric(label: "Ground Truth", value: "University Gate", accentHex: "22C55E"),
                    DialogEventMetric(label: "Confidence", value: "92%", accentHex: "EF4444"),
                    DialogEventMetric(label: "Bias Source", value: "Temple-heavy dataset", accentHex: "A855F7")
                ],
                tags: ["image", "bias", "hallucination", "review"]
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "The next chapter will simulate memory-based retraining so the model can recover from repeated mistakes.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Next Objective",
            cutsceneSubtitle: "Memory training pipeline"
        )
    ]
)
