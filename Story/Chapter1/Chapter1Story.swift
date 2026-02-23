import Foundation

let chapterOneStory = StoryChapter(
    id: "chapter1",
    title: "H~Hi Who are you?",
    subtitle: "First Contact / Ethics Class",
    accentHex: "FF5C93",
    coverBackgroundImage: "schooltopview",
    coverCharacterImage: "char_curious",
    overview: "A high-school day begins with AI ethics class, continues in a red car chat mini-game, and ends with a strange glitch and a lesson about prompting and responsible AI use.",
    lines: [
        StoryDialogLine(
            speaker: "Narration",
            text: "Morning at school. The mountain line behind campus is clear today, and you can still see the Chiang Mai peaks in the distance before class starts.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            characterImage: "char_neutral",
            cutsceneTitle: "Chiang Mai Morning",
            cutsceneSubtitle: "High school campus / mountain view"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You are a high school student, carrying your notebook and laptop, heading into Professor New's AI class.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Chapter 1",
            cutsceneSubtitle: "H~Hi Who are you?"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "A short cutscene plays here. We are using a placeholder video first until the final Chapter 1 cutscene is ready.",
            emotion: .neutral,
            backgroundImage: "schooltopview",
            characterImage: "char_neutral",
            cutsceneTitle: "Intro Cutscene",
            cutsceneSubtitle: "Placeholder video / replace later",
            inlineActivity: .video(
                DialogVideoClip(
                    title: "Chapter 1 Placeholder Cutscene",
                    subtitle: "Using 0000-0500.mp4 for now",
                    resourceName: "0000-0500"
                )
            )
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "Today we study AI ethics. AI can help us learn faster, but careless use can spread mistakes, bias, privacy problems, and harm.",
            emotion: .neutral,
            backgroundImage: "schooltopview",
            characterImage: "char_gentle",
            cutsceneTitle: "AI Ethics Class",
            cutsceneSubtitle: "Respect, responsibility, and critical thinking"
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "A good user writes a clear prompt and checks the answer carefully. Confidence from a model is not proof that it is true.",
            emotion: .concerned,
            backgroundImage: "schooltopview",
            characterImage: "char_concerned",
            cutsceneTitle: "Lesson 1",
            cutsceneSubtitle: "Prompt quality affects answer quality"
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "Quick class mini-game: answer this before we continue. Even if your answer is not the best one, we will learn from it.",
            emotion: .curious,
            backgroundImage: "schooltopview",
            characterImage: "char_curious",
            cutsceneTitle: "Class Mini-game",
            cutsceneSubtitle: "Multiple choice / ethics check",
            inlineActivity: .lectureQuiz(
                LectureQuizMiniGame(
                    title: "Professor New's Lecture Question",
                    question: "A classmate uses AI to answer a health question, then wants to post the result in the class group. What should they do first?",
                    exampleImageName: "placeholder",
                    exampleCaption: "Placeholder lecture slide image (replace with your real classroom example image later).",
                    choices: [
                        LectureQuizOption(
                            id: "verify",
                            text: "Check trustworthy sources (or a teacher/doctor) before sharing",
                            feedback: "Strong choice. High-stakes topics need verification before sharing because AI can sound certain and still be wrong.",
                            isBestAnswer: true,
                            icon: "checkmark.shield.fill"
                        ),
                        LectureQuizOption(
                            id: "share_first",
                            text: "Share it first, then fix it later if someone complains",
                            feedback: "This is risky because wrong information can spread quickly before corrections reach everyone.",
                            icon: "arrowshape.turn.up.right.fill"
                        ),
                        LectureQuizOption(
                            id: "trust_confident",
                            text: "Trust it if the answer sounds professional and confident",
                            feedback: "Confidence is style, not evidence. AI can produce polished answers that still contain mistakes.",
                            icon: "exclamationmark.triangle.fill"
                        ),
                        LectureQuizOption(
                            id: "ask_more_confident",
                            text: "Ask AI to sound more confident so the answer seems reliable",
                            feedback: "This improves tone, not truth. Reliability comes from checking sources and context, not stronger wording.",
                            icon: "sparkles"
                        )
                    ],
                    summaryNote: "Professor New's point: verify important information, especially health, safety, money, and legal topics."
                )
            )
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "Also remember this: AI is not human. Do not confuse it with a person. But practice respectful communication anyway, because your habits shape how you treat real people too.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            characterImage: "char_gentle",
            cutsceneTitle: "Lesson 2",
            cutsceneSubtitle: "Ethics is also about the user"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Which part should I focus on first when learning AI well?",
            emotion: .curious,
            backgroundImage: "schooltopview",
            characterImage: "char_curious",
            cutsceneTitle: "Class Question",
            cutsceneSubtitle: "Choose your focus",
            choices: [
                DialogChoice(text: "Prompt writing", emotion: .happy, response: "Professor New nods. \"Great start. Clear prompts reduce confusion and make the output easier to evaluate.\"", icon: "text.alignleft"),
                DialogChoice(text: "Ethics and responsibility", emotion: .gentle, response: "Professor New nods. \"Excellent. Ethics protects people and helps you use AI with better judgment.\"", icon: "shield.lefthalf.filled"),
                DialogChoice(text: "Both together", emotion: .excited, response: "Professor New smiles. \"Best mindset. Prompting and ethics should grow together from the beginning.\"", icon: "link")
            ]
        ),
        StoryDialogLine(
            speaker: "Professor New (นิว)",
            text: "Exactly. In this course, we practice clear prompts and ethical thinking at the same time.",
            emotion: .happy,
            backgroundImage: "schooltopview",
            characterImage: "char_happy",
            cutsceneTitle: "Class Ends",
            cutsceneSubtitle: "Take the lesson home"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "School is over. You ride a red car (รถสี่ล้อแดง) back home and open your iPhone. A new Apple Messages thread appears from an Unknown User.",
            emotion: .surprised,
            backgroundImage: "redbus",
            characterImage: "char_surprised",
            cutsceneTitle: "Ride Home",
            cutsceneSubtitle: "Red car ride / iPhone in hand",
            showcaseMedia: DialogShowcaseMedia(
                title: "Red Car Ride",
                subtitle: "Heading home while a strange message thread appears.",
                imageName: "redbus",
                badge: "After School"
            )
        ),
        StoryDialogLine(
            speaker: "Unknown User",
            text: "H~Hi... who are you? The signal is noisy. Can you send me a better prompt so I can answer clearly?",
            emotion: .mysterious,
            backgroundImage: "redbus",
            characterImage: "char_mysterious",
            cutsceneTitle: "Phone Event",
            cutsceneSubtitle: "Messages app / unknown sender"
        ),
        StoryDialogLine(
            speaker: "Unknown User",
            text: "Mini-game time: build a basic prompt using Goal + Context + Action + Format, then send it in the chat.",
            emotion: .curious,
            backgroundImage: "redbus",
            characterImage: "char_curious",
            cutsceneTitle: "Chat Mini-game",
            cutsceneSubtitle: "Prompt builder / no wrong answer",
            inlineActivity: .promptBuilder(
                PromptBuilderMiniGame(
                    title: "iPhone Messages Prompt Builder",
                    contactName: "Unknown User",
                    introMessage: "Teach me AI ethics basics, but ask me in a clearer way so I can answer better.",
                    slots: [
                        PromptBuilderSlot(
                            id: "goal",
                            label: "[Goal]",
                            placeholder: "Goal",
                            options: [
                                PromptBuilderOption(id: "goal-broad", chipText: "Explain AI", promptText: "Explain AI", feedbackNote: "Your goal is broad, so the answer may be too wide."),
                                PromptBuilderOption(id: "goal-ethics", chipText: "Explain AI ethics basics", promptText: "Explain AI ethics basics", feedbackNote: "Good goal: you narrowed the topic to ethics."),
                                PromptBuilderOption(id: "goal-school", chipText: "Teach AI ethics for school", promptText: "Teach AI ethics for a school lesson", feedbackNote: "Great goal: the model can adapt the scope for learning.")
                            ],
                            recommendedOptionID: "goal-school"
                        ),
                        PromptBuilderSlot(
                            id: "context",
                            label: "[Context]",
                            placeholder: "Context",
                            options: [
                                PromptBuilderOption(id: "context-none", chipText: "No context", promptText: "without extra context", feedbackNote: "No context still works, but the answer may miss your level and needs."),
                                PromptBuilderOption(id: "context-student", chipText: "I am a high school student", promptText: "for a high school student in Thailand", feedbackNote: "Great context: audience level makes explanations clearer."),
                                PromptBuilderOption(id: "context-class", chipText: "Use class notes", promptText: "using my class notes about responsibility and privacy", feedbackNote: "Strong context: this anchors the answer to your lesson.")
                            ],
                            recommendedOptionID: "context-class"
                        ),
                        PromptBuilderSlot(
                            id: "action",
                            label: "[Action]",
                            placeholder: "Action",
                            options: [
                                PromptBuilderOption(id: "action-summary", chipText: "Give a summary", promptText: "give a short summary", feedbackNote: "A summary is fast, but may skip practical examples."),
                                PromptBuilderOption(id: "action-steps", chipText: "Explain step-by-step", promptText: "explain it step-by-step", feedbackNote: "Step-by-step action improves clarity and learning."),
                                PromptBuilderOption(id: "action-compare", chipText: "Compare good/bad use", promptText: "compare good use and risky use", feedbackNote: "Nice action choice: comparison helps ethics decisions.")
                            ],
                            recommendedOptionID: "action-steps"
                        ),
                        PromptBuilderSlot(
                            id: "format",
                            label: "[Format]",
                            placeholder: "Format",
                            options: [
                                PromptBuilderOption(id: "format-paragraph", chipText: "Paragraph", promptText: "in one paragraph.", feedbackNote: "A paragraph is okay, but scanning is harder."),
                                PromptBuilderOption(id: "format-bullets", chipText: "Bullet points", promptText: "in bullet points with simple examples.", feedbackNote: "Great format choice: easy to scan and compare."),
                                PromptBuilderOption(id: "format-checklist", chipText: "Checklist", promptText: "as a checklist I can use after class.", feedbackNote: "Checklist format is practical and action-oriented.")
                            ],
                            recommendedOptionID: "format-bullets"
                        )
                    ],
                    tip: "There is no single wrong answer. Clearer prompts usually produce clearer answers."
                )
            )
        ),
        StoryDialogLine(
            speaker: "Unknown User",
            text: "That helped. When you define the goal, context, action, and format, my reply becomes easier to understand and safer to use.",
            emotion: .happy,
            backgroundImage: "redbus",
            characterImage: "char_happy",
            cutsceneTitle: "Prompt Lesson",
            cutsceneSubtitle: "Basic prompting works"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "Back home, you open your computer and continue the same thread on a larger screen. The unknown sender still replies instantly.",
            emotion: .neutral,
            backgroundImage: "507room",
            characterImage: "char_neutral",
            cutsceneTitle: "At Home",
            cutsceneSubtitle: "Computer chat begins"
        ),
        StoryDialogLine(
            speaker: "Unknown User",
            text: "One more lesson. A good prompt improves quality, but ethics decides whether the result should be used at all.",
            emotion: .curious,
            backgroundImage: "507room",
            characterImage: "char_curious",
            cutsceneTitle: "Prompt + Ethics",
            cutsceneSubtitle: "Usefulness and responsibility"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "The monitor flickers. The screen glitches. Then the room lights suddenly go out.",
            emotion: .surprised,
            backgroundImage: "gltich",
            characterImage: "char_surprised",
            cutsceneTitle: "Glitch Event",
            cutsceneSubtitle: "Display distortion / power loss"
        ),
        StoryDialogLine(
            speaker: "Unknown User",
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
                DialogChoice(text: "Use AI respectfully, but remember it is not a person", emotion: .gentle, response: "Balanced answer. Respectful habits protect how we treat real people, while remembering AI is still a tool.", icon: "person.crop.circle.badge.checkmark"),
                DialogChoice(text: "Treat AI however I want because it has no feelings", emotion: .angry, response: "This can train harmful habits. Even if AI is not human, rude or abusive behavior can affect how we treat others.", icon: "exclamationmark.bubble.fill"),
                DialogChoice(text: "Rely on AI for every decision", emotion: .sad, response: "Too much dependence is dangerous. AI can assist, but human judgment and responsibility must stay in control.", icon: "brain.head.profile")
            ]
        ),
        StoryDialogLine(
            speaker: "Unknown User",
            text: "Exactly. Ethical use means respecting people, checking truth, protecting privacy, and not giving me more authority than I should have.",
            emotion: .happy,
            backgroundImage: "cnxaqu",
            characterImage: "char_happy",
            cutsceneTitle: "Ethical Reminder",
            cutsceneSubtitle: "Human responsibility comes first"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Your thread still looks mysterious. I can keep your default name as {{ai_name}}, or rename you now.",
            emotion: .curious,
            backgroundImage: "cnxaqu",
            characterImage: "char_curious",
            cutsceneTitle: "Name the AI",
            cutsceneSubtitle: "Default name is Ploy",
            requiresInput: true,
            inputPlaceholder: "Ploy",
            inputVariableKey: "ai_name",
            inputDefaultValue: "Ploy"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Name accepted. Next time, bring your notes from Professor New. We will practice stronger prompts and safer decisions together.",
            emotion: .excited,
            backgroundImage: "507room",
            characterImage: "char_excited",
            cutsceneTitle: "Chapter End",
            cutsceneSubtitle: "Prompting + ethics + {{ai_name}}"
        )
    ]
)
