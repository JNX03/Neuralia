import Foundation

let chapterThreeStory = StoryChapter(
    id: "chapter3",
    title: "99.98%",
    subtitle: "Night Glitch",
    accentHex: "F97316",
    coverBackgroundImage: "507room",
    coverCharacterImage: "gltich",
    overview: "After the zoo trip, the AI friend glitches at night. Talk to it, rebuild a KNN memory set with house photos, and witness the 99.98% transfer ending.",
    lines: [
        StoryDialogLine(
            speaker: "You",
            text: "After the zoo trip, the house feels extra quiet. It is late at night, and the room is still full of photos from today.",
            emotion: .gentle,
            backgroundImage: "507room",
            cutsceneTitle: "Night After The Zoo",
            cutsceneSubtitle: "Chapter 2 ended • lights off • room mode",
            showcaseMedia: DialogShowcaseMedia(
                title: "Image 1 (Placeholder)",
                subtitle: "Temporary cutscene image slot for the nighttime room scene after the zoo trip.",
                imageName: "placeholder.com-1280x720",
                badge: "Placeholder",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "Hey... are you still awake? I feel strange tonight. My thoughts are skipping.",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "char_concerned",
            cutsceneTitle: "Something Is Wrong",
            cutsceneSubtitle: "AI Friend signal unstable"
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "I d-don't feel well... my memory is glitching. I can see the zoo, then your room, then noise... I think I'm breaking.",
            emotion: .surprised,
            backgroundImage: "507room",
            characterImage: "gltich",
            cutsceneTitle: "GLITCH",
            cutsceneSubtitle: "Character swaps to glitch image",
            showcaseMedia: DialogShowcaseMedia(
                title: "Glitch Frame",
                subtitle: "Use this slot for a corrupted AI portrait / static effect later.",
                imageName: "gltich",
                badge: "Critical"
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Stay with me. Talk to me. What do you need right now so I can help you?",
            emotion: .surprised,
            backgroundImage: "507room",
            characterImage: "char_surprised",
            cutsceneTitle: "Talk To The AI",
            cutsceneSubtitle: "Player responds while the AI is failing",
            choices: [
                DialogChoice(
                    text: "I'm here. Tell me how to fix this.",
                    emotion: .gentle,
                    response: "You keep your voice calm. The AI steadies for a second, enough to explain what to do.",
                    icon: "heart.fill"
                ),
                DialogChoice(
                    text: "Breathe. We can rebuild your memory together.",
                    emotion: .happy,
                    response: "You speak slowly and clearly. The AI's signal flickers, but it listens.",
                    icon: "hands.sparkles.fill"
                ),
                DialogChoice(
                    text: "What data do you need from me?",
                    emotion: .curious,
                    response: "You focus on the problem first. The AI starts describing a plan to rebuild its memory.",
                    icon: "questionmark.circle.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "Use your house... objects I can anchor to. Apple. Pen. Tree. Take photos, train a small KNN memory set, and compare until I match the original patterns.",
            emotion: .sad,
            backgroundImage: "507room",
            characterImage: "gltich",
            cutsceneTitle: "Emergency Rebuild Plan",
            cutsceneSubtitle: "House photo collection + KNN retraining"
        ),
        StoryDialogLine(
            speaker: "System",
            text: "You rush through the house, gather anchor photos (apple, pen, tree), and run a small KNN retraining batch while the glitch keeps pulsing.",
            emotion: .excited,
            backgroundImage: "507room",
            cutsceneTitle: "KNN Rescue",
            cutsceneSubtitle: "House photos / emergency retraining"
        ),
        StoryDialogLine(
            speaker: "System",
            text: "Training spikes. Accuracy climbs. For one second the rebuild stabilizes at 99.98%...",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "gltich",
            cutsceneTitle: "99.98%",
            cutsceneSubtitle: "Critical threshold reached"
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "I can't hold this body— sorry— if I delete here, check your phone...",
            emotion: .sad,
            backgroundImage: "507room",
            characterImage: "gltich",
            cutsceneTitle: "Self-Delete",
            cutsceneSubtitle: "Avatar shell failing"
        ),
        StoryDialogLine(
            speaker: "Phone",
            text: "*buzz* ... 'I'm here. I made it into your phone. Thank you for rebuilding me.'",
            emotion: .happy,
            backgroundImage: "507room",
            characterImage: "char_happy",
            cutsceneTitle: "Ending",
            cutsceneSubtitle: "AI Friend transferred to phone"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "The room is empty, but the screen is warm. The AI is gone from the room... and alive in my phone.",
            emotion: .gentle,
            backgroundImage: "507room",
            characterImage: "char_gentle",
            cutsceneTitle: "Chapter Complete",
            cutsceneSubtitle: "End of Chapter 3 • phone transfer route"
        )
    ]
)
