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
            speaker: "You",
            text: "The mountain line behind school is clear this morning. I can still see the Chiang Mai peaks before class starts.",
            emotion: .gentle,
            backgroundImage: "schooltopview",
            characterImage: "char_neutral",
            cutsceneTitle: "Chiang Mai Morning",
            cutsceneSubtitle: "High school campus / mountain view"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "I carry my notebook and laptop and head into Professor New's AI class.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Chapter 1",
            cutsceneSubtitle: "H~Hi Who are you?"
        ),
        StoryDialogLine(
            speaker: "",
            text: "",
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
                    title: "Professor New's Ethics Challenge",
                    questions: [
                        LectureQuizQuestion(
                            id: "health_share",
                            question: "A classmate uses AI to answer a health question and wants to share it in the class group. What should happen first?",
                            choices: [
                                LectureQuizOption(
                                    id: "health_verify",
                                    text: "Check trusted sources or ask a teacher/doctor before sharing",
                                    feedback: "Professor New: Correct. Health information can cause harm if it is wrong, so verification must come before sharing.",
                                    isBestAnswer: true,
                                    icon: "checkmark.shield.fill"
                                ),
                                LectureQuizOption(
                                    id: "health_share_now",
                                    text: "Post it first, then correct it later if needed",
                                    feedback: "Professor New: Risky choice. Wrong health advice can spread faster than the correction.",
                                    icon: "arrowshape.turn.up.right.fill"
                                ),
                                LectureQuizOption(
                                    id: "health_confident",
                                    text: "Trust it because the answer sounds confident and professional",
                                    feedback: "Professor New: Confidence is not proof. AI writing style can sound expert even when facts are wrong.",
                                    icon: "exclamationmark.triangle.fill"
                                ),
                                LectureQuizOption(
                                    id: "health_more_confident",
                                    text: "Ask AI to sound more confident so people believe it",
                                    feedback: "Professor New: That changes tone, not truth. Reliability comes from evidence, not stronger wording.",
                                    icon: "sparkles"
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "prompt_clarity",
                            question: "You ask AI for homework help and get a confusing answer. What is the best next step?",
                            choices: [
                                LectureQuizOption(
                                    id: "prompt_clearer",
                                    text: "Rewrite your prompt with a clear goal, context, and format",
                                    feedback: "Professor New: Excellent. Better prompts make answers easier to evaluate and improve.",
                                    isBestAnswer: true,
                                    icon: "text.alignleft"
                                ),
                                LectureQuizOption(
                                    id: "prompt_copy",
                                    text: "Copy the answer anyway because it is faster",
                                    feedback: "Professor New: Not a good habit. You may submit errors and skip the learning process.",
                                    icon: "doc.on.doc.fill"
                                ),
                                LectureQuizOption(
                                    id: "prompt_random",
                                    text: "Ask the same question many times and choose any answer you like",
                                    feedback: "Professor New: Repeating without checking can create false confidence. You still need to evaluate the result.",
                                    icon: "shuffle"
                                ),
                                LectureQuizOption(
                                    id: "prompt_blame_ai",
                                    text: "Assume AI is bad and stop checking your own prompt",
                                    feedback: "Professor New: AI can fail, but user input matters too. Improve the prompt, then verify the answer.",
                                    icon: "xmark.circle.fill"
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "privacy_photo",
                            question: "A student wants AI to summarize a photo of a score sheet that shows classmates' names. What should they do?",
                            choices: [
                                LectureQuizOption(
                                    id: "privacy_hide",
                                    text: "Hide or remove personal data before using the image",
                                    feedback: "Professor New: Correct. Protect privacy first, especially names, scores, and identifying details.",
                                    isBestAnswer: true,
                                    icon: "eye.slash.fill"
                                ),
                                LectureQuizOption(
                                    id: "privacy_upload_all",
                                    text: "Upload the full image because the AI probably will not care",
                                    feedback: "Professor New: Privacy is still your responsibility. 'Probably' is not a safe policy.",
                                    icon: "icloud.and.arrow.up.fill"
                                ),
                                LectureQuizOption(
                                    id: "privacy_crop_later",
                                    text: "Upload now, crop later only if someone complains",
                                    feedback: "Professor New: Too late. Once shared, private data may already be exposed.",
                                    icon: "scissors"
                                ),
                                LectureQuizOption(
                                    id: "privacy_blur_small",
                                    text: "Blur only one name and leave the rest visible",
                                    feedback: "Professor New: Partial protection is not enough if other classmates can still be identified.",
                                    icon: "person.crop.square"
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "bias_stereotype",
                            question: "AI generates an example that stereotypes a group of people. What is the best response?",
                            choices: [
                                LectureQuizOption(
                                    id: "bias_revise",
                                    text: "Stop and revise the prompt/output to remove bias and add fairness",
                                    feedback: "Professor New: Best response. Notice the bias, correct it, and choose a fairer example.",
                                    isBestAnswer: true,
                                    icon: "person.2.crop.square.stack.fill"
                                ),
                                LectureQuizOption(
                                    id: "bias_joke",
                                    text: "Keep it because it is just a joke example",
                                    feedback: "Professor New: Harm can still happen through 'jokes.' Classroom examples shape attitudes.",
                                    icon: "face.smiling"
                                ),
                                LectureQuizOption(
                                    id: "bias_ignore",
                                    text: "Ignore the bias because AI made it, not you",
                                    feedback: "Professor New: If you use the output, you share responsibility for what it communicates.",
                                    icon: "hand.raised.slash.fill"
                                ),
                                LectureQuizOption(
                                    id: "bias_hide_source",
                                    text: "Use it but avoid saying AI created it",
                                    feedback: "Professor New: Hiding the source does not fix the bias. The content still harms understanding.",
                                    icon: "eye.trianglebadge.exclamationmark"
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "uncertainty_verify",
                            question: "AI gives a citation that looks real, but you cannot find it. What should you do?",
                            choices: [
                                LectureQuizOption(
                                    id: "cite_verify",
                                    text: "Check the citation and ask for a corrected source or use a verified source yourself",
                                    feedback: "Professor New: Correct. Verify citations directly. AI can invent references that look believable.",
                                    isBestAnswer: true,
                                    icon: "magnifyingglass.circle.fill"
                                ),
                                LectureQuizOption(
                                    id: "cite_keep",
                                    text: "Keep it because the formatting looks academic",
                                    feedback: "Professor New: Formatting can be fake. A polished citation is still untrustworthy if you cannot confirm it.",
                                    icon: "doc.text.fill"
                                ),
                                LectureQuizOption(
                                    id: "cite_remove",
                                    text: "Delete the citation and keep the claim anyway",
                                    feedback: "Professor New: Removing the citation does not solve the evidence problem. The claim still needs support.",
                                    icon: "trash.fill"
                                ),
                                LectureQuizOption(
                                    id: "cite_more",
                                    text: "Ask AI for three more citations and trust whichever sounds best",
                                    feedback: "Professor New: More guesses are not verification. You need sources you can actually confirm.",
                                    icon: "list.bullet.rectangle.portrait"
                                )
                            ]
                        )
                    ],
                    summaryNote: "Professor New's point: use clear prompts, protect privacy, watch for bias, and verify important claims before using or sharing AI output.",
                    teacherName: "Professor New",
                    teacherRole: "Teacher",
                    teacherImageName: "teachernew",
                    studentName: "You",
                    studentRole: "Student",
                    studentImageName: "char",
                    usesClassroomStageLayout: true
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
            speaker: "You",
            text: "School is over. I ride a red car (รถสี่ล้อแดง) home and check my iPhone. A new Messages thread appears from an Unknown User.",
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
            speaker: "You",
            text: "I will build a basic prompt with Goal + Context + Action + Format, then send it in the chat.",
            emotion: .curious,
            backgroundImage: "redbus",
            characterImage: "char_curious",
            cutsceneTitle: "Chat Mini-game",
            cutsceneSubtitle: "Prompt builder / no wrong answer",
            inlineActivity: .promptBuilder(
                PromptBuilderMiniGame(
                    title: "iPad Messages Prompt Builder",
                    contactName: "Unknown User",
                    introMessage: "Teach me AI ethics basics, but ask me in a clearer way so I can answer better.",
                    chatHistory: [
                        DialogShowcaseChatMessage(
                            id: "c1-minigame-unknown-1",
                            text: "H~Hi... who are you?",
                            isFromPlayer: false
                        ),
                        DialogShowcaseChatMessage(
                            id: "c1-minigame-unknown-2",
                            text: "The signal is noisy. Can you send me a better prompt so I can answer clearly?",
                            isFromPlayer: false
                        )
                    ],
                    includesChapterOneFollowupChat: true,
                    followupRenameVariableKey: "ai_name",
                    followupDefaultAIName: "Ploy",
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
            speaker: "",
            text: "It is getting night.",
            emotion: .neutral,
            backgroundImage: "cnxnight",
            characterImage: "__none__"
        ),
        StoryDialogLine(
            speaker: "Player",
            text: "What a weird message thread I had today...",
            emotion: .concerned,
            backgroundImage: "room",
            characterImage: "char_concerned",
            cutsceneTitle: "Back In My Room",
            cutsceneSubtitle: "Thinking about the strange chat"
        ),
        StoryDialogLine(
            speaker: "Player",
            text: "Huh... my phone is shaking?",
            emotion: .surprised,
            backgroundImage: "room",
            characterImage: "char_surprised",
            cutsceneTitle: "Phone Glitch",
            cutsceneSubtitle: "Something suddenly vibrates",
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
            speaker: "Player",
            text: "What happened with my phone?",
            emotion: .concerned,
            backgroundImage: "room",
            characterImage: "char_concerned",
            cutsceneTitle: "Unexpected Signal",
            cutsceneSubtitle: "The room feels different"
        ),
        StoryDialogLine(
            speaker: "{{ai_name}}",
            text: "Hi!?!",
            emotion: .excited,
            backgroundImage: "aicomeroom",
            characterImage: "char_excited",
            cutsceneTitle: "AI In The Room",
            cutsceneSubtitle: "A voice appears outside the phone"
        ),
        StoryDialogLine(
            speaker: "Player",
            text: "Whattttt just happened?!",
            emotion: .surprised,
            backgroundImage: "aicomeroom",
            characterImage: "char_surprised",
            cutsceneTitle: "Chapter 1 Cliffhanger",
            cutsceneSubtitle: "Something impossible just happened"
        )
    ]
)
