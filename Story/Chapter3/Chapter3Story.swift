import Foundation

let chapterThreeStory = StoryChapter(
    id: "chapter3",
    title: "99.98%",
    subtitle: "The Revelation",
    accentHex: "06B6D4",
    coverBackgroundImage: "507room",
    coverCharacterImage: "char_excited",
    overview: "Temporary event panel for replay memory training so you can replace it with your real training system later.",
    lines: [
        StoryDialogLine(
            speaker: "Ploy",
            text: "We saved misclassified samples into memory. Next, we run a focused retraining pass instead of retraining the whole model.",
            emotion: .curious,
            backgroundImage: "507room",
            cutsceneTitle: "Training Bay",
            cutsceneSubtitle: "Replay memory queued",
            showcaseMedia: DialogShowcaseMedia(
                title: "Memory Batch Preview",
                subtitle: "Temporary visual slot for memory samples / heatmaps / loss chart.",
                imageName: "cnxaqu",
                badge: "Replay Buffer"
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "This temp event simulates training from memory. When you build the real feature, connect the button to your training function and feed live metrics.",
            emotion: .excited,
            backgroundImage: "507room",
            cutsceneTitle: "Training Event",
            cutsceneSubtitle: "Prototype trainer with hook function",
            eventPayload: DialogEventPayload(
                type: .memoryTraining,
                title: "Memory Training Event",
                subtitle: "Prototype control panel for replay-based corrective training.",
                ctaTitle: "Call Memory Trainer",
                hookName: "launchMemoryTrainingEvent()",
                metrics: [
                    DialogEventMetric(label: "Memory Samples", value: "128"),
                    DialogEventMetric(label: "Epochs", value: "3"),
                    DialogEventMetric(label: "Learning Rate", value: "0.0005"),
                    DialogEventMetric(label: "Expected Gain", value: "+11% top-1", accentHex: "22C55E")
                ],
                tags: ["training", "memory", "ai", "prototype"]
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Story prototype ready. You can now edit chapter files directly to change scene assets, dialog flow, or event hooks.",
            emotion: .happy,
            backgroundImage: "507room",
            cutsceneTitle: "System Ready",
            cutsceneSubtitle: "Chapter scripts are data-driven"
        )
    ]
)
