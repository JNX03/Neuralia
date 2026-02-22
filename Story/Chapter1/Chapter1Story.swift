import Foundation

let chapterOneStory = StoryChapter(
    id: "chapter1",
    title: "H~Hi Who are you?",
    subtitle: "The First Encounter",
    accentHex: "FF5C93",
    coverBackgroundImage: "507room",
    coverCharacterImage: "char_excited",
    overview: "Ploy opens the story and triggers a temporary phone chat event (mini-game hook ready).",
    lines: [
        StoryDialogLine(
            speaker: "Ploy",
            text: "Neura link established. Before we start the mission, I need to confirm your response style.",
            emotion: .mysterious,
            backgroundImage: "507room",
            cutsceneTitle: "Dormitory - 22:48",
            cutsceneSubtitle: "Signal handshake / secure channel"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "You will receive a chat ping first. This is the place where you can later plug in a real mini game by calling your own function hook.",
            emotion: .curious,
            backgroundImage: "507room",
            cutsceneTitle: "Tutorial Event",
            cutsceneSubtitle: "Temporary phone chat UI (replaceable)",
            eventPayload: DialogEventPayload(
                type: .mobileChat,
                title: "Mobile Chat Event",
                subtitle: "Prototype phone layout for first contact conversation.",
                ctaTitle: "Call Chat Mini Game",
                hookName: "launchMobileChatMiniGame()",
                metrics: [
                    DialogEventMetric(label: "Event Type", value: "Chat"),
                    DialogEventMetric(label: "Entry Point", value: "Chapter 1"),
                    DialogEventMetric(label: "Status", value: "Prototype", accentHex: "F59E0B")
                ],
                tags: ["dialog", "phone-ui", "mini-game-hook"]
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Good. Once the player replies, we can move into image reasoning tests in Chapter 2.",
            emotion: .happy,
            backgroundImage: "507room",
            cutsceneTitle: "Channel Stable",
            cutsceneSubtitle: "Proceed when ready"
        )
    ]
)
