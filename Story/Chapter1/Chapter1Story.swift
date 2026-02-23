import Foundation

let chapterOneStory = StoryChapter(
    id: "chapter1",
    title: "H~Hi Who are you?",
    subtitle: "First Contact / Ethics Class",
    accentHex: "FF5C93",
    coverBackgroundImage: "schooltopview",
    coverCharacterImage: "char_curious",
    overview: "A high-school day begins with AI ethics class, continues in a red car chat, and ends with a prompt-writing lesson and a strange glitch at home.",
    lines: [
        StoryDialogLine(
            speaker: "Narration",
            text: "Morning at school. The mountain line is visible behind the campus, and the air still feels cool before class begins.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            characterImage: "char_neutral",
            cutsceneTitle: "Chiang Mai Morning",
            cutsceneSubtitle: "High school campus / mountain view"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You are a high school student, carrying your notebook and laptop, heading into AI class.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Chapter 1",
            cutsceneSubtitle: "H~Hi Who are you?"
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "Today we study AI ethics. AI can be helpful, but if we use it carelessly, it can spread mistakes, bias, and harm.",
            emotion: .neutral,
            backgroundImage: "schooltopview",
            characterImage: "char_gentle",
            cutsceneTitle: "AI Ethics Class",
            cutsceneSubtitle: "Respect, responsibility, and critical thinking"
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "A good user does two things: writes a clear prompt and checks the output carefully. Confidence from a model is not proof.",
            emotion: .concerned,
            backgroundImage: "schooltopview",
            characterImage: "char_concerned",
            cutsceneTitle: "Lesson 1",
            cutsceneSubtitle: "Prompt quality affects answer quality"
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "And remember this: AI is not human. We should not confuse it with a person. But we still practice respectful communication because our habits shape our character.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            characterImage: "char_gentle",
            cutsceneTitle: "Lesson 2",
            cutsceneSubtitle: "Ethics is also about the user"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Which part is most important first when learning AI?",
            emotion: .curious,
            backgroundImage: "schooltopview",
            characterImage: "char_curious",
            cutsceneTitle: "Class Question",
            cutsceneSubtitle: "Choose your focus",
            choices: [
                DialogChoice(text: "Prompt writing", emotion: .happy, response: "", icon: "text.alignleft"),
                DialogChoice(text: "Ethics and responsibility", emotion: .gentle, response: "", icon: "shield.lefthalf.filled"),
                DialogChoice(text: "Both together", emotion: .excited, response: "", icon: "link")
            ]
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "Good answer. In this course, we practice both together: clear prompts and ethical use at the same time.",
            emotion: .happy,
            backgroundImage: "schooltopview",
            characterImage: "char_happy",
            cutsceneTitle: "Class Ends",
            cutsceneSubtitle: "Take the lesson home"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "School is over. You ride a red car home and open your phone. A strange AI friend chat appears inside Apple Messages.",
            emotion: .surprised,
            backgroundImage: "redbus",
            characterImage: "char_surprised",
            cutsceneTitle: "Ride Home",
            cutsceneSubtitle: "Red car / phone in hand",
            showcaseMedia: DialogShowcaseMedia(
                title: "Red Car Ride",
                subtitle: "You are heading home while checking a new message thread.",
                imageName: "redbus",
                badge: "After School"
            )
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "H~Hi... who are you? The signal is unstable. Try replying in Messages first.",
            emotion: .mysterious,
            backgroundImage: "redbus",
            characterImage: "char_mysterious",
            cutsceneTitle: "Phone Event",
            cutsceneSubtitle: "Apple-style chat / first contact"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "Back home, you open your computer and continue the conversation on a larger screen. The AI asks you to be more specific.",
            emotion: .neutral,
            backgroundImage: "507room",
            characterImage: "char_neutral",
            cutsceneTitle: "At Home",
            cutsceneSubtitle: "Computer chat begins"
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "Teach me the way your teacher taught you. Build a good prompt for an AI ethics explanation. Plan it before you send it.",
            emotion: .curious,
            backgroundImage: "507room",
            characterImage: "char_curious",
            cutsceneTitle: "Prompt Workshop",
            cutsceneSubtitle: "Prompt planning lesson"
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "That is much better. When you define the task, audience, format, and ethical boundaries, the answer becomes more useful and safer.",
            emotion: .happy,
            backgroundImage: "507room",
            characterImage: "char_happy",
            cutsceneTitle: "Learning Check",
            cutsceneSubtitle: "Prompt planning improves output quality"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "The monitor flickers. The computer glitches. The room lights suddenly go out.",
            emotion: .surprised,
            backgroundImage: "507room",
            characterImage: "char_surprised",
            cutsceneTitle: "Glitch Event",
            cutsceneSubtitle: "Display distortion / power loss"
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "Do not panic. I am not human, and I should not replace human relationships. But I can still help you learn if you use me responsibly.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Unexpected Presence",
            cutsceneSubtitle: "The AI appears outside the device"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "If you are not human, how should I treat you?",
            emotion: .concerned,
            backgroundImage: "cnxaqu",
            characterImage: "char_concerned",
            cutsceneTitle: "Ethics Choice",
            cutsceneSubtitle: "AI is a tool, but your behavior still matters",
            choices: [
                DialogChoice(text: "Use AI respectfully, but remember it is not a person", emotion: .gentle, response: "", icon: "person.crop.circle.badge.checkmark"),
                DialogChoice(text: "Treat AI however I want because it has no feelings", emotion: .angry, response: "", icon: "exclamationmark.bubble.fill"),
                DialogChoice(text: "Rely on AI for every decision", emotion: .sad, response: "", icon: "brain.head.profile")
            ]
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "Exactly. Ethical use means respecting people, checking truth, protecting privacy, and not giving me more authority than I should have.",
            emotion: .happy,
            backgroundImage: "cnxaqu",
            characterImage: "char_happy",
            cutsceneTitle: "Ethical Reminder",
            cutsceneSubtitle: "Human responsibility comes first"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "If we are going to keep learning together, I need a name for you.",
            emotion: .curious,
            backgroundImage: "cnxaqu",
            characterImage: "char_curious",
            cutsceneTitle: "Name the AI",
            cutsceneSubtitle: "Choose a name for your AI friend",
            requiresInput: true,
            inputPlaceholder: "Type an AI name..."
        ),
        StoryDialogLine(
            speaker: "AI Friend",
            text: "Name accepted. Next time, bring your notes from Professor New. We will practice stronger prompts and safer decisions together.",
            emotion: .excited,
            backgroundImage: "507room",
            characterImage: "char_excited",
            cutsceneTitle: "Chapter End",
            cutsceneSubtitle: "Prompting + ethics + responsibility"
        )
    ]
)
