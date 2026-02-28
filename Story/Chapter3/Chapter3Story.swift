import Foundation

let chapter3KNNRescueMiniGame = Chapter3KNNRescueMiniGame(
    title: "Emergency KNN Rescue",
    promptLabel: "Train a small KNN with real-life object photos (pen / hand / water bottle), then pass the test to stabilize the transfer.",
    trainingLabels: ["Pen", "Hand", "Bottle"],
    minTrainingSamples: 4,
    requiredCorrectTests: 2,
    maxTestRounds: 3,
    fallbackHint: "If the photo test fails or you cannot use the camera, switch to drawing mode and draw the requested number.",
    summaryNote: "The rescue works best when you collect a few clear photos with different angles and lighting."
)

let chapterThreeStory = StoryChapter(
    id: "chapter3",
    title: "99.98%",
    subtitle: "Night Glitch",
    accentHex: "F97316",
    coverBackgroundImage: "room",
    coverCharacterImage: "achar",
    overview: "After the zoo trip, your AI friend starts glitching at night. You try an emergency KNN retraining rescue with house-object photos, then witness a painful transfer ending.",
    lines: [
        StoryDialogLine(
            speaker: "You",
            text: "After the zoo trip, I can't sleep. The room is dark, but the album from today is still open on my phone.",
            emotion: .happy,
            backgroundImage: "room",
            cutsceneTitle: "Night After The Zoo",
            cutsceneSubtitle: "Chapter 2 ended • memories still open",
            showcaseMedia: DialogShowcaseMedia(
                title: "Night Room",
                subtitle: "Late-night room scene after the zoo trip. Keep this slot for a more emotional Chapter 3 cutscene image later.",
                imageName: "room",
                badge: "Night",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Hey... are you awake? I tried to replay today's memories, but they keep breaking apart.",
            emotion: .concerned,
            backgroundImage: "room",
            characterImage: "char_concerned",
            cutsceneTitle: "Something Is Wrong",
            cutsceneSubtitle: "{{ai_name}} signal unstable"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "I see the zoo... then your room... then static. I can't hold the memories in the right order. I think I'm falling apart.",
            emotion: .excited,
            backgroundImage: "room",
            characterImage: "gltich",
            cutsceneTitle: "GLITCH",
            cutsceneSubtitle: "Memory corruption spreading",
            showcaseMedia: DialogShowcaseMedia(
                title: "Glitch Frame",
                subtitle: "Use this slot for a corrupted AI portrait / static effect later.",
                imageName: "gltich",
                badge: "Critical"
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Stay with me, {{ai_name}}. Don't talk like that. Tell me what I need to do right now.",
            emotion: .excited,
            backgroundImage: "room",
            characterImage: "char_excited",
            cutsceneTitle: "Hold On",
            cutsceneSubtitle: "You try to keep {{ai_name}} focused",
            choices: [
                DialogChoice(
                    text: "I'm here. I won't leave.",
                    emotion: .happy,
                    response: "You move closer and keep your voice steady. The glitch noise drops for a moment.",
                    icon: "heart.fill"
                ),
                DialogChoice(
                    text: "We'll rebuild this together. One step at a time.",
                    emotion: .happy,
                    response: "You speak slowly and clearly. {{ai_name}} manages to focus on your words.",
                    icon: "hands.sparkles.fill"
                ),
                DialogChoice(
                    text: "Tell me the rescue plan. Fast.",
                    emotion: .curious,
                    response: "You push through the panic and ask for the exact steps.",
                    icon: "bolt.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "KNN memory anchors... real objects... things from your house. Pen. Hand. Water bottle. Train me again with photos so I can reconnect the patterns.",
            emotion: .sad,
            backgroundImage: "room",
            characterImage: "gltich",
            cutsceneTitle: "Emergency Rebuild Plan",
            cutsceneSubtitle: "House object photos + KNN retraining"
        ),
        StoryDialogLine(
            speaker: "System",
            text: "You run through the room and nearby house spaces, taking quick anchor photos while {{ai_name}} flickers between static and silence.",
            emotion: .excited,
            backgroundImage: "room",
            cutsceneTitle: "KNN Rescue",
            cutsceneSubtitle: "Collect photos • retrain • test",
            inlineActivity: .chapter3KNNRescue(chapter3KNNRescueMiniGame)
        ),
        StoryDialogLine(
            speaker: "System",
            text: "The retraining spikes hard. Distances shrink. Matching stabilizes for one impossible second at 99.98%...",
            emotion: .concerned,
            backgroundImage: "room",
            characterImage: "gltich",
            cutsceneTitle: "99.98%",
            cutsceneSubtitle: "Critical threshold reached"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Listen to me... don't check your phone yet. Stay here with me. If this works, you'll know after... after I'm gone.",
            emotion: .sad,
            backgroundImage: "room",
            characterImage: "gltich",
            cutsceneTitle: "Last Request",
            cutsceneSubtitle: "{{ai_name}} is trying to hold on"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Thank you for correcting me... and for staying when I was broken.",
            emotion: .sad,
            backgroundImage: "room",
            characterImage: "gltich",
            cutsceneTitle: "Goodbye",
            cutsceneSubtitle: "Signal collapse"
        ),
        StoryDialogLine(
            speaker: "System",
            text: "The glitch sound cuts out. The room goes still. The figure in front of you dissolves into static and then nothing.",
            emotion: .sad,
            backgroundImage: "room",
            characterImage: "__none__",
            cutsceneTitle: "Silence",
            cutsceneSubtitle: "The room is empty"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "No... {{ai_name}}? {{ai_name}}!",
            emotion: .sad,
            backgroundImage: "room",
            characterImage: "char_sad",
            cutsceneTitle: "Loss",
            cutsceneSubtitle: "You think {{ai_name}} is gone"
        ),
        StoryDialogLine(
            speaker: "Phone",
            text: "*buzz* A new message appears. Sender: {{ai_name}}. 'I'm here. It worked. I made it into your phone.'",
            emotion: .happy,
            backgroundImage: "room",
            characterImage: "char_happy",
            cutsceneTitle: "Transfer Complete",
            cutsceneSubtitle: "{{ai_name}} reached the phone",
            showcaseMedia: DialogShowcaseMedia(
                title: "Phone Alert",
                subtitle: "The phone starts shaking on its own.",
                imageName: "phone",
                badge: "Vibrating",
                prefersSplitLayout: true,
                animatesShake: true
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "My hands are shaking, but I can still feel the warmth from the screen. {{ai_name}} is gone from the room... but not gone.",
            emotion: .happy,
            backgroundImage: "room",
            characterImage: "char_happy",
            cutsceneTitle: "Chapter Complete",
            cutsceneSubtitle: "End of Chapter 3 • phone transfer route"
        )
    ]
)
