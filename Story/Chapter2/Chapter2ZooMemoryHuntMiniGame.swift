import Foundation

// MARK: - Zoo Memory Hunt (Messenger Style)
// A chat-based quiz where the AI guesses and you correct it
// Similar to Chapter 1's PromptBuilder UI - messenger app style

let chapter2ZooMemoryHuntMiniGame =
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
