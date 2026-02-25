import Foundation

let chapter2AIMistakeReviewMiniGame =
                LectureQuizMiniGame(
                    title: "AI Mistake Review",
                    questions: [
                        LectureQuizQuestion(
                            id: "review-hallucination-time",
                            question: "{{ai_name}} says \"10:67\" when asked the time. What kind of mistake is that?",
                            choices: [
                                LectureQuizOption(
                                    id: "time-hallucination",
                                    text: "Hallucination",
                                    feedback: "This is hallucination: the answer sounds confident, but the time is impossible. I should verify with a real clock.",
                                    isBestAnswer: true,
                                    icon: "clock.badge.exclamationmark"
                                ),
                                LectureQuizOption(
                                    id: "time-bias",
                                    text: "Bias",
                                    feedback: "Not bias first. The main problem is a made-up impossible answer without reliable context. That is hallucination.",
                                    icon: "xmark.circle.fill"
                                ),
                                LectureQuizOption(
                                    id: "time-bad-data",
                                    text: "Bad Data",
                                    feedback: "Bad data can cause mistakes, but here the key lesson is the AI guessed a fake time. That is hallucination.",
                                    icon: "xmark.circle.fill"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"10:67... I guessed because it sounded like a real time.\"",
                            sceneImageName: "room",
                            sceneImageCaption: "Morning room review: confident answer, impossible result.",
                            referenceBookTitle: "Open Review Note",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "review-hall-1",
                                    title: "Hallucination",
                                    text: "Hallucination means AI generates an answer that sounds plausible but is false or invalid. Verify with trusted sources."
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "review-bias-redpanda",
                            question: "{{ai_name}} says \"panda must be big and black-and-white,\" so she rejects a red panda. What is the problem?",
                            choices: [
                                LectureQuizOption(
                                    id: "bias-overgeneralize",
                                    text: "Bias / overgeneralized pattern",
                                    feedback: "That is bias from overgeneralizing patterns. I should use labels and ground truth instead of a narrow rule.",
                                    isBestAnswer: true,
                                    icon: "brain.head.profile"
                                ),
                                LectureQuizOption(
                                    id: "bias-hallucination",
                                    text: "Hallucination only",
                                    feedback: "Close, but the main lesson here is bias/assumption: a narrow pattern rejects a valid exception.",
                                    icon: "xmark.circle.fill"
                                ),
                                LectureQuizOption(
                                    id: "bias-bad-data",
                                    text: "Bad Data only",
                                    feedback: "Not mainly bad data. The sign is clear. The problem is the overgeneralized assumption about what counts as a panda.",
                                    icon: "xmark.circle.fill"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"This cannot be a panda. Pandas are supposed to be big and black-and-white.\"",
                            sceneImageName: "zoo_redpanda_scene_placeholder",
                            sceneImageCaption: "Red panda review: clear sign, but wrong assumption.",
                            referenceBookTitle: "Open Bias Note",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "review-bias-1",
                                    title: "Bias / Assumption",
                                    text: "Bias can appear when AI learns a narrow pattern and treats it like a rule. Diverse examples and correct labels help."
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "review-baddata-aquarium",
                            question: "At the algae-covered aquarium glass, {{ai_name}} shouts \"Sea Monster!\" What caused the wrong answer most directly?",
                            choices: [
                                LectureQuizOption(
                                    id: "bad-data-input",
                                    text: "Bad Data / unclear input",
                                    feedback: "Yes. The view was blocked and unclear. Better input (clear angle, cleaner glass) gives a better result.",
                                    isBestAnswer: true,
                                    icon: "camera.aperture"
                                ),
                                LectureQuizOption(
                                    id: "bad-data-bias",
                                    text: "Bias only",
                                    feedback: "Bias can exist, but the main problem here is unclear input quality. The evidence was bad.",
                                    icon: "xmark.circle.fill"
                                ),
                                LectureQuizOption(
                                    id: "bad-data-hall",
                                    text: "Hallucination only",
                                    feedback: "It sounds like hallucination, but the strongest cause in this scene is poor input quality: bad data.",
                                    icon: "xmark.circle.fill"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"Sea Monster detected!\"",
                            sceneImageName: "zoo_aquarium_blurry_placeholder",
                            sceneImageCaption: "Aquarium review: unclear glass creates bad predictions.",
                            referenceBookTitle: "Open Bad Data Note",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "review-baddata-1",
                                    title: "Bad Data",
                                    text: "When the input is blurry, blocked, dark, or noisy, the model may fail. Improve the input before trusting the output."
                                )
                            ]
                        ),
                        LectureQuizQuestion(
                            id: "review-safe-habit",
                            question: "When {{ai_name}} is unsure, what is the safest habit?",
                            choices: [
                                LectureQuizOption(
                                    id: "safe-uncertain-verify",
                                    text: "Say \"I'm not sure\" and check a trusted source",
                                    feedback: "Correct. Letting AI be uncertain and verifying with real sources reduces hallucination and bad decisions.",
                                    isBestAnswer: true,
                                    icon: "checkmark.shield.fill"
                                ),
                                LectureQuizOption(
                                    id: "safe-guess-fast",
                                    text: "Guess fast so the answer sounds smart",
                                    feedback: "No. Fast confident guessing creates more hallucinations and unsafe mistakes.",
                                    icon: "bolt.fill"
                                ),
                                LectureQuizOption(
                                    id: "safe-same-pattern",
                                    text: "Reuse one pattern for everything",
                                    feedback: "No. That can increase bias because different situations need different evidence and labels.",
                                    icon: "arrow.triangle.branch"
                                )
                            ],
                            aiGuessLine: "{{ai_name}}: \"If I'm unsure, should I still answer confidently so I sound helpful?\"",
                            sceneImageName: "507room",
                            sceneImageCaption: "Safety habit review: uncertainty + verification is stronger than guessing.",
                            referenceBookTitle: "Open Safety Note",
                            referencePages: [
                                LectureQuizReferencePage(
                                    id: "review-safe-1",
                                    title: "Safer AI Use",
                                    text: "Best habit: allow uncertainty, verify with trusted sources, and use labels/signs/clearer inputs before final decisions."
                                )
                            ]
                        )
                    ],
                    promptLabel: "You correct {{ai_name}} and name the mistake type.",
                    summaryNote: "Review lesson: hallucination = confident false answer, bias = overgeneralized pattern, bad data = unclear input. The safest habit is verify and allow uncertainty.",
                    teacherName: "{{ai_name}}",
                    teacherRole: "AI Friend",
                    teacherImageName: "unknow",
                    studentName: "You",
                    studentRole: "Friend",
                    studentImageName: "char",
                    usesClassroomStageLayout: true,
                    studentGivesCorrectionFeedback: true
                )
