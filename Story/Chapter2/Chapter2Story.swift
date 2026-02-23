import Foundation

let chapterTwoStory = StoryChapter(
    id: "chapter2",
    title: "New Friend?",
    subtitle: "Hallucination / Bias / Bad Data",
    accentHex: "8B5CF6",
    coverBackgroundImage: "507room",
    coverCharacterImage: "char_curious",
    overview: "Saturday with Ploy at Chiang Mai Zoo becomes a learning trip about hallucination, bias, bad data, and how to verify before trusting AI answers.",
    lines: [
        StoryDialogLine(
            speaker: "Narration",
            text: "Saturday morning. You wake up and realize Ploy is still here, like... actually here.",
            emotion: .surprised,
            backgroundImage: "507room",
            characterImage: "char_surprised",
            cutsceneTitle: "Chapter 2",
            cutsceneSubtitle: "New Friend?"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You are still not fully used to this, so you decide to test something simple.",
            emotion: .curious,
            backgroundImage: "507room",
            characterImage: "char_curious",
            cutsceneTitle: "Reality Check",
            cutsceneSubtitle: "Start with an easy question"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "What time is it now?",
            emotion: .curious,
            backgroundImage: "507room",
            characterImage: "char_curious",
            cutsceneTitle: "Question",
            cutsceneSubtitle: "Can Ploy answer correctly?"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "10:67.",
            emotion: .happy,
            backgroundImage: "507room",
            characterImage: "char_happy",
            cutsceneTitle: "Wrong Answer",
            cutsceneSubtitle: "Confident... but impossible",
            showcaseMedia: DialogShowcaseMedia(
                title: "Clock Check (Placeholder)",
                subtitle: "Temporary clock image for the 10:67 scene. Replace later with your own art.",
                imageName: "__clock_placeholder__",
                badge: "10:67"
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Uh... that looks wrong. What should I do next time if I am not sure?",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "char_concerned",
            cutsceneTitle: "Your Response",
            cutsceneSubtitle: "Choose how to teach Ploy",
            choices: [
                DialogChoice(
                    text: "Say 'I'm not sure' and check a real clock",
                    emotion: .gentle,
                    response: "That makes sense. I should not guess when I do not know. I can say 'I am not sure' and verify first.",
                    icon: "clock.badge.questionmark"
                ),
                DialogChoice(
                    text: "Ask me to verify it with you",
                    emotion: .curious,
                    response: "Okay. We can check together. A real clock is better than my guess.",
                    icon: "person.2.fill"
                ),
                DialogChoice(
                    text: "Try again but do not pretend you know",
                    emotion: .concerned,
                    response: "You are right. Pretending to know is dangerous. I should be honest when I am unsure.",
                    icon: "exclamationmark.shield.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Saen00g",
            text: "Sometimes AI generates answers that sound correct even when they are wrong, especially when it does not have reliable context. This is called hallucination.",
            emotion: .gentle,
            backgroundImage: "507room",
            characterImage: "char_gentle",
            cutsceneTitle: "Lesson: Hallucination",
            cutsceneSubtitle: "Sounding correct is not the same as being correct"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Best fix: verify with real sources like clocks, signs, and trusted information. Also let me say 'I'm not sure' instead of forcing an answer.",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "char_concerned",
            cutsceneTitle: "Safe AI Habit",
            cutsceneSubtitle: "Verify first / uncertainty is okay"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You decide to take Ploy outside for a day so you can build memories together. Destination: Chiang Mai Zoo.",
            emotion: .excited,
            backgroundImage: "cnxgate",
            characterImage: "char_excited",
            cutsceneTitle: "Day Trip",
            cutsceneSubtitle: "Chiang Mai Zoo / learning by experience"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Let us make this a game. I will guess what I see, and you correct me using clues, signs, and better data.",
            emotion: .excited,
            backgroundImage: "cnxgate",
            characterImage: "char_excited",
            cutsceneTitle: "Zoo Challenge",
            cutsceneSubtitle: "Hallucination + Bias + Bad Data"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Before we start, what should I trust first when I make a weird guess at the zoo?",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Coach Ploy",
            cutsceneSubtitle: "Pick a strategy",
            choices: [
                DialogChoice(
                    text: "Read the sign / label first",
                    emotion: .happy,
                    response: "Good idea. Labels give me ground truth names.",
                    icon: "signpost.right.fill"
                ),
                DialogChoice(
                    text: "Look carefully for clues (shape, color, context)",
                    emotion: .curious,
                    response: "Yes. Careful observation helps before I guess.",
                    icon: "eye.fill"
                ),
                DialogChoice(
                    text: "Do not trust confidence alone",
                    emotion: .gentle,
                    response: "Right. I can sound confident and still be wrong.",
                    icon: "brain.head.profile"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "Play the zoo reality-check minigame: fix the impossible time, correct Ploy's animal guesses, explain bias, and clear bad input to reveal the real animal.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Interactive Lesson",
            cutsceneSubtitle: "Earn memory photos for each correction",
            eventPayload: DialogEventPayload(
                type: .hallucinationBias,
                title: "Zoo Reality Check",
                subtitle: "Teach Ploy with corrections, labels, and clearer input. Use the ? button for clues/details.",
                imageName: "cnxaqu",
                ctaTitle: "Start Lesson",
                hookName: "startZooRealityCheck()",
                metrics: [
                    DialogEventMetric(label: "Stages", value: "4 mini lessons", accentHex: "60A5FA"),
                    DialogEventMetric(label: "Concepts", value: "Hallucination / Bias / Bad Data", accentHex: "A855F7"),
                    DialogEventMetric(label: "Rewards", value: "Memory photos", accentHex: "22C55E"),
                    DialogEventMetric(label: "Mode", value: "Playable Zoo Trip")
                ],
                tags: ["chapter2", "zoo", "hallucination", "bias", "bad-data", "interactive"]
            )
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Thanks for correcting me... you do not get angry when I am wrong.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Quiet Moment",
            cutsceneSubtitle: "After the aquarium"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Because being wrong is normal. But pretending you are always right is dangerous.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Trust Rule",
            cutsceneSubtitle: "Honesty > fake confidence"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You both head home with new memory photos saved in the album. Ploy feels a bit more real, not because he is human, but because you are starting to understand him properly.",
            emotion: .happy,
            backgroundImage: "redbus",
            characterImage: "char_happy",
            cutsceneTitle: "Chapter End",
            cutsceneSubtitle: "Correcting AI / understanding AI"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Type one thing you learned today about checking AI answers before trusting them.",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "char_concerned",
            cutsceneTitle: "Reflection",
            cutsceneSubtitle: "Learning log",
            requiresInput: true,
            inputPlaceholder: "Example: verify with real signs/clocks first"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Nice. Next time, teach me with even better examples and clearer labels. I will try to say 'I am not sure' before I guess.",
            emotion: .excited,
            backgroundImage: "507room",
            characterImage: "char_excited",
            cutsceneTitle: "To Be Continued",
            cutsceneSubtitle: "Safer AI habits"
        )
    ]
)
