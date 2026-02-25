import Foundation

let chapterTwoStory = StoryChapter(
    id: "chapter2",
    title: "New Friend?",
    subtitle: "Hallucination / Bias / Bad Data",
    accentHex: "8B5CF6",
    coverBackgroundImage: "room",
    coverCharacterImage: "unknow",
    overview: "A Saturday with your AI friend turns into a zoo memory trip where you learn hallucination, bias, and bad data through real-world corrections.",
    lines: [
        StoryDialogLine(
            speaker: "",
            text: "Saturday morning.",
            emotion: .neutral,
            backgroundImage: "room",
            characterImage: "__none__",
            cutsceneTitle: "Chapter 2",
            cutsceneSubtitle: "New Friend?"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "I wake up and realize {{ai_name}} is still here... like, actually here.",
            emotion: .surprised,
            backgroundImage: "room",
            characterImage: "char_surprised",
            cutsceneTitle: "Morning Check",
            cutsceneSubtitle: "Still not used to this"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Okay. Easy test first. What time is it now?",
            emotion: .curious,
            backgroundImage: "room",
            characterImage: "char_curious",
            cutsceneTitle: "Simple Test",
            cutsceneSubtitle: "Ask something obvious"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "10:67.",
            emotion: .happy,
            backgroundImage: "room",
            characterImage: "unknow",
            cutsceneTitle: "Confident Guess",
            cutsceneSubtitle: "Sounds sure • still wrong",
            showcaseMedia: DialogShowcaseMedia(
                title: "Clock Check",
                subtitle: "The AI answered confidently, but the time is impossible.",
                imageName: "__clock_placeholder__",
                badge: "10:67",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Bro... 10:67 is not a real time.",
            emotion: .concerned,
            backgroundImage: "room",
            characterImage: "char_concerned",
            cutsceneTitle: "Reality Check",
            cutsceneSubtitle: "Impossible time"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Oh, sorry. I guessed.",
            emotion: .sad,
            backgroundImage: "room",
            characterImage: "unknow",
            cutsceneTitle: "Oops",
            cutsceneSubtitle: "Guessing without context"
        ),
        StoryDialogLine(
            speaker: "",
            text: "Sometimes AI generates answers that sound correct even when they are wrong, especially when it lacks reliable context. That is called hallucination.",
            emotion: .gentle,
            backgroundImage: "room",
            characterImage: "__none__",
            cutsceneTitle: "Lesson: Hallucination",
            cutsceneSubtitle: "Sounds right ≠ is right"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Best fix: verify with real sources like clocks, signs, and trusted information. Also let me say 'I'm not sure' instead of forcing a guess.",
            emotion: .gentle,
            backgroundImage: "room",
            characterImage: "unknow",
            cutsceneTitle: "Safer Habit",
            cutsceneSubtitle: "Verify and allow uncertainty"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Then let's test this in the real world. I want to build memories with you.",
            emotion: .excited,
            backgroundImage: "room",
            characterImage: "char_excited",
            cutsceneTitle: "New Plan",
            cutsceneSubtitle: "A real-world test"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Field trip? Really? Where are we going?",
            emotion: .excited,
            backgroundImage: "room",
            characterImage: "unknow",
            cutsceneTitle: "{{ai_name}} Lights Up",
            cutsceneSubtitle: "AI friend is excited"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Let's see how much you really understand today.",
            emotion: .happy,
            backgroundImage: "cnxgate",
            characterImage: "char_happy",
            cutsceneTitle: "Understanding Bias & Bad Data",
            cutsceneSubtitle: "Time to test the real world",
            inlineActivity: .chapter2InteractiveLab(chapter2BiasAndBadDataLabMiniGame)
        ),
        StoryDialogLine(
            speaker: "You",
            text: "See? You were wrong a few times, but that is normal. The dangerous part is pretending the guess is always right.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "After The Lessons",
            cutsceneSubtitle: "Correction is part of learning"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Thanks for correcting me... you do not get angry when I am wrong.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "unknow",
            cutsceneTitle: "Quiet Moment",
            cutsceneSubtitle: "{{ai_name}} gets quieter"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Because being wrong is normal. But pretending you are always right is dangerous.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Trust Rule",
            cutsceneSubtitle: "Honesty is safer than confidence"
        ),
        StoryDialogLine(
            speaker: "",
            text: "You both head home with a few new memory photos saved in the album. {{ai_name}} feels a bit more real, not because she is human, but because you are starting to understand her properly.",
            emotion: .happy,
            backgroundImage: "redbus",
            characterImage: "__none__",
            cutsceneTitle: "Chapter End",
            cutsceneSubtitle: "Memories saved • understanding grows"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Next time, I will try to say 'I'm not sure' before I guess. You can help me with better clues and better data.",
            emotion: .excited,
            backgroundImage: "507room",
            characterImage: "unknow",
            cutsceneTitle: "To Be Continued",
            cutsceneSubtitle: "Safer answers together"
        )
    ]
)
