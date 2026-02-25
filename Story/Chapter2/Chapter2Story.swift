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
            text: "Then let's correct it. Pick a real time.",
            emotion: .curious,
            backgroundImage: "room",
            characterImage: "char_curious",
            cutsceneTitle: "Quick Check",
            cutsceneSubtitle: "Correct the hallucination",
            showcaseMedia: DialogShowcaseMedia(
                title: "Reality Check",
                subtitle: "Choose a valid time instead of the impossible answer.",
                imageName: "__clock_placeholder__",
                badge: "Pick One",
                prefersSplitLayout: true
            ),
            choices: [
                DialogChoice(
                    text: "10:07",
                    emotion: .happy,
                    response: "Correct. Real-world validation beats confident guessing.",
                    icon: "checkmark.circle.fill"
                ),
                DialogChoice(
                    text: "10:67",
                    emotion: .concerned,
                    response: "Still impossible. 67 minutes does not exist on a normal clock.",
                    icon: "xmark.circle.fill"
                ),
                DialogChoice(
                    text: "99:10",
                    emotion: .concerned,
                    response: "Also impossible. Always check if the answer is valid before trusting it.",
                    icon: "exclamationmark.triangle.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "You",
            text: "You know what? Let's go outside today. I want to build memories with you.",
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
            text: "Chiang Mai Zoo.",
            emotion: .happy,
            backgroundImage: "cnxgate",
            characterImage: "char_happy",
            cutsceneTitle: "Day Trip",
            cutsceneSubtitle: "Chiang Mai Zoo"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "At the zoo, everything is fun at first. {{ai_name}} gets excited and starts guessing animals like it is a game.",
            emotion: .happy,
            backgroundImage: "cnxgate",
            characterImage: "unknow",
            cutsceneTitle: "Zoo Start",
            cutsceneSubtitle: "Guessing game begins"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Okay, game rules: you guess first, and I verify with signs, clues, and a field guide book.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Memory Hunt",
            cutsceneSubtitle: "Spot • check • learn",
            inlineActivity: .lectureQuiz(
                LectureQuizMiniGame(
                    title: "Chiang Mai Zoo Memory Hunt",
                    questions: [
                        LectureQuizQuestion(
                            id: "zoo-bird",
                            question: "You point upward near the zoo path. What is the correct label?",
                            choices: [
                                LectureQuizOption(
                                    id: "bird-plane",
                                    text: "Plane",
                                    feedback: "I picked Plane too fast. I need to check movement and context before I lock in an answer.",
                                    icon: "airplane"
                                ),
                                LectureQuizOption(
                                    id: "bird-bird",
                                    text: "Bird",
                                    feedback: "No, it is a bird. I checked the visible clues first instead of trusting the first guess. Memory photo added.",
                                    isBestAnswer: true,
                                    icon: "camera.fill"
                                ),
                                LectureQuizOption(
                                    id: "bird-drone",
                                    text: "Drone",
                                    feedback: "I guessed Drone from the shape only. That is still guessing too fast, so I should verify before I answer.",
                                    icon: "viewfinder"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"Woah... a plane? ...or maybe a drone?\"",
                            sceneImageName: "zoo_bird_scene_placeholder",
                            sceneImageCaption: "Zoo walkway placeholder scene. Replace with your real bird scene image later.",
                            referenceBookTitle: "Open Zoo Field Guide",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "bird-guide-1",
                                    title: "Bird Check",
                                    text: "Use simple clues first: flapping motion, size, and where it appears. A fast AI guess can confuse similar shapes when the view is quick.",
                                    imageName: "zoo_bird_fieldguide_placeholder"
                                ),
                                LectureQuizReferencePage(
                                    id: "bird-guide-2",
                                    title: "Hallucination Reminder",
                                    text: "If the input is brief or unclear, AI may still answer confidently. Verify with signs, your eyes, and real context before accepting the answer."
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "zoo-red-panda",
                            question: "At the enclosure sign, what is the correct label?",
                            choices: [
                                LectureQuizOption(
                                    id: "rp-fox",
                                    text: "Fox",
                                    feedback: "I chose Fox from the pattern only. I need to read the sign because labels are the ground truth.",
                                    icon: "xmark.circle.fill"
                                ),
                                LectureQuizOption(
                                    id: "rp-raccoon",
                                    text: "Raccoon",
                                    feedback: "I guessed Raccoon from similarity, but that still ignores the sign. I should verify the label first.",
                                    icon: "xmark.circle.fill"
                                ),
                                LectureQuizOption(
                                    id: "rp-red-panda",
                                    text: "Red Panda",
                                    feedback: "No, it is a Red Panda. The enclosure sign is the ground truth. Memory photo card unlocked.",
                                    isBestAnswer: true,
                                    icon: "camera.fill"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"Look! A fox... or maybe a raccoon? Impossible. Panda should be big and black-and-white.\"",
                            sceneImageName: "zoo_redpanda_scene_placeholder",
                            sceneImageCaption: "Red Panda enclosure placeholder scene. Replace with your real red panda image later.",
                            referenceBookTitle: "Open Zoo Field Guide",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "rp-guide-1",
                                    title: "Ground Truth > Pattern Guess",
                                    text: "AI can overgeneralize: 'panda = big black-and-white' is a pattern, not a rule. Exceptions exist. Labels and signs are ground truth.",
                                    imageName: "zoo_redpanda_fieldguide_placeholder"
                                ),
                                LectureQuizReferencePage(
                                    id: "rp-guide-2",
                                    title: "Bias / Assumption",
                                    text: "When training examples are narrow, AI may reject valid exceptions. Diverse data and correct labels reduce this kind of error."
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "aquarium-catfish",
                            question: "After moving to a clearer spot and wiping algae from the glass, what is it really?",
                            choices: [
                                LectureQuizOption(
                                    id: "aq-monster",
                                    text: "Sea Monster",
                                    feedback: "I picked Sea Monster too fast. That is just a dramatic guess from unclear input, so I need a clearer view first.",
                                    icon: "exclamationmark.triangle.fill"
                                ),
                                LectureQuizOption(
                                    id: "aq-catfish",
                                    text: "Giant Catfish",
                                    feedback: "It is a Giant Catfish. After getting a clearer view, the answer becomes much easier to verify. Memory photo added.",
                                    isBestAnswer: true,
                                    icon: "camera.fill"
                                ),
                                LectureQuizOption(
                                    id: "aq-rock",
                                    text: "Rock / Decoration",
                                    feedback: "I guessed Rock/Decoration first, but I still need better evidence. After the view improves, I should verify the real animal.",
                                    icon: "eye.fill"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"Alert! Sea Monster detected! Green slime skin, 10 meters long!\"",
                            sceneImageName: "zoo_aquarium_blurry_placeholder",
                            sceneImageCaption: "Aquarium blocked-view placeholder scene. Replace with your real algae/blur image later.",
                            referenceBookTitle: "Open Aquarium Field Guide",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "aq-guide-1",
                                    title: "Bad Data = Bad Prediction",
                                    text: "If the view is blocked, dark, or low quality, even a strong model can fail. Improve the input before judging the output.",
                                    imageName: "zoo_catfish_fieldguide_placeholder"
                                ),
                                LectureQuizReferencePage(
                                    id: "aq-guide-2",
                                    title: "Clearer View",
                                    text: "Move closer, change angle, or clean the glass. Better evidence produces better predictions. In this scene, the 'monster' was just a giant catfish behind plants."
                                )
                            ]
                        )
                    ],
                    promptLabel: "{{ai_name}} guesses first. You verify with clues and the field guide.",
                    summaryNote: "Zoo memory lesson: hallucination can sound confident, bias can overgeneralize from patterns, and bad data can cause wrong predictions. Check signs, labels, and clearer inputs.",
                    teacherName: "{{ai_name}}",
                    teacherRole: "AI Friend",
                    teacherImageName: "unknow",
                    studentName: "You",
                    studentRole: "Friend",
                    studentImageName: "char",
                    usesClassroomStageLayout: true,
                    studentGivesCorrectionFeedback: true
                )
            )
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
            speaker: "Narration",
            text: "You both head home with a few new memory photos saved in the album. {{ai_name}} feels a bit more real, not because she is human, but because you are starting to understand her properly.",
            emotion: .happy,
            backgroundImage: "redbus",
            characterImage: "char_happy",
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
