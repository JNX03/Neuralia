import Foundation

let chapterThreeStory = StoryChapter(
    id: "chapter3",
    title: "99.98%",
    subtitle: "The Revelation",
    accentHex: "06B6D4",
    coverBackgroundImage: "507room",
    coverCharacterImage: "char_excited",
    overview: "Run a playable replay-memory training sequence and push the model toward a safer, more accurate result.",
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
            text: "This batch is small on purpose. We only need enough signal to correct the repeated mistake pattern without damaging what the model already learned.",
            emotion: .gentle,
            backgroundImage: "507room",
            cutsceneTitle: "Training Strategy",
            cutsceneSubtitle: "Targeted correction / low-risk update"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Choose the safer rollout plan before you train.",
            emotion: .concerned,
            backgroundImage: "507room",
            cutsceneTitle: "Safety Gate",
            cutsceneSubtitle: "Deployment policy",
            choices: [
                DialogChoice(text: "Train in short batches and validate", emotion: .happy, response: "", icon: "checkmark.shield"),
                DialogChoice(text: "Run full retrain immediately", emotion: .angry, response: "", icon: "bolt.fill"),
                DialogChoice(text: "Pause and collect more failures", emotion: .neutral, response: "", icon: "tray.full.fill")
            ]
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Run the memory trainer event. Each step replays misclassified samples, updates progress, and moves the queue toward completion.",
            emotion: .excited,
            backgroundImage: "507room",
            cutsceneTitle: "Training Event",
            cutsceneSubtitle: "Replay trainer / interactive control panel",
            eventPayload: DialogEventPayload(
                type: .memoryTraining,
                title: "Memory Training Event",
                subtitle: "Run replay-based corrective training and track completion progress.",
                ctaTitle: "Run Training Step",
                hookName: "runReplayMemoryTrainer()",
                metrics: [
                    DialogEventMetric(label: "Memory Samples", value: "128"),
                    DialogEventMetric(label: "Epochs", value: "3"),
                    DialogEventMetric(label: "Learning Rate", value: "0.0005"),
                    DialogEventMetric(label: "Expected Gain", value: "+11% top-1", accentHex: "22C55E"),
                    DialogEventMetric(label: "Mode", value: "Playable Trainer", accentHex: "60A5FA")
                ],
                tags: ["training", "memory", "ai", "replay", "interactive"]
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "The replay queue is responding. Once training finishes, we can compare the new prediction against the original failure and verify the correction actually holds.",
            emotion: .happy,
            backgroundImage: "507room",
            cutsceneTitle: "Validation Phase",
            cutsceneSubtitle: "Compare before / after behavior"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "This is the real breakthrough: not just chatting with a model, but guiding it through mistakes, evidence review, and recovery. The next chapters can build from this loop.",
            emotion: .happy,
            backgroundImage: "507room",
            cutsceneTitle: "System Ready",
            cutsceneSubtitle: "Story + events + training loop connected"
        )
    ]
)
