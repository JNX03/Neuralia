import Foundation

let chapterTwoStory = StoryChapter(
    id: "chapter2",
    title: "New Friend?",
    subtitle: "Growing Connection",
    accentHex: "8B5CF6",
    coverBackgroundImage: "schooltopview",
    coverCharacterImage: "char_concerned",
    overview: "Inspect a suspicious image prediction, review bias clues, and run a playable hallucination correction event.",
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
            text: "Take a close look before you trust the label. The architecture is good at pattern matching, but it overfits fast when one class dominates the training set.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Pre-Review",
            cutsceneSubtitle: "Confidence can hide bias"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Which signal would you inspect first when a prediction feels suspicious?",
            emotion: .curious,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Diagnostic Prompt",
            cutsceneSubtitle: "Pick your first clue",
            choices: [
                DialogChoice(text: "Dataset balance", emotion: .neutral, response: "", icon: "chart.bar.xaxis"),
                DialogChoice(text: "Ground-truth label", emotion: .happy, response: "", icon: "checkmark.seal.fill"),
                DialogChoice(text: "Model confidence only", emotion: .concerned, response: "", icon: "exclamationmark.triangle.fill")
            ]
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Run the bias review event. Inspect the evidence cards, identify the bias source, and apply a correction plan.",
            emotion: .surprised,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Alert",
            cutsceneSubtitle: "Hallucination detected",
            eventPayload: DialogEventPayload(
                type: .hallucinationBias,
                title: "Bias & Hallucination Event",
                subtitle: "Review evidence, isolate the bias source, and apply corrective action.",
                imageName: "cnxgate",
                ctaTitle: "Apply Correction",
                hookName: "runBiasHallucinationReview()",
                metrics: [
                    DialogEventMetric(label: "Model Guess", value: "Ancient Temple"),
                    DialogEventMetric(label: "Ground Truth", value: "University Gate", accentHex: "22C55E"),
                    DialogEventMetric(label: "Confidence", value: "92%", accentHex: "EF4444"),
                    DialogEventMetric(label: "Bias Source", value: "Temple-heavy dataset", accentHex: "A855F7"),
                    DialogEventMetric(label: "Mode", value: "Playable Review", accentHex: "60A5FA")
                ],
                tags: ["image", "bias", "hallucination", "review"]
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Good catch. The wrong guess was not random; it came from repeated exposure to a dominant visual pattern. We can fix that with targeted replay training.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Correction Plan",
            cutsceneSubtitle: "Prepare replay memory samples"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Before we continue, write down the main failure pattern you noticed so we can compare it after retraining.",
            emotion: .concerned,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Field Note",
            cutsceneSubtitle: "Observation log",
            requiresInput: true,
            inputPlaceholder: "Example: model over-predicts temple-like gates"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Next stop: memory training. We will replay the mistakes, tune the model in short bursts, and check whether the bias pressure drops.",
            emotion: .excited,
            backgroundImage: "schooltopview",
            cutsceneTitle: "Next Objective",
            cutsceneSubtitle: "Memory training pipeline"
        )
    ]
)
