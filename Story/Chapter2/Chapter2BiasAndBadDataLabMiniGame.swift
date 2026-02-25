import Foundation

// MARK: - Bias & Bad Data Lab (Simple Quiz Style)
// Converted from complex card sorting to simple question/answer format
// Like Chapter 1's lecture quiz - easier to play with messenger-style UI

let chapter2BiasAndBadDataLabMiniGame =
    LectureQuizMiniGame(
        title: "Bias & Bad Data Lab",
        questions: [
            LectureQuizQuestion(
                id: "daylight-only",
                question: "The training dataset only has daytime zoo photos. What is the problem?",
                choices: [
                    LectureQuizOption(
                        id: "daylight-bias",
                        text: "Bias - unbalanced dataset",
                        feedback: "Correct. This is bias from an unbalanced dataset. The model learned mostly daylight patterns and will miss nocturnal animals.",
                        isBestAnswer: true,
                        icon: "sun.max.fill"
                    ),
                    LectureQuizOption(
                        id: "daylight-bad-data",
                        text: "Bad data - blurry images",
                        feedback: "Not quite. The photos are clear, just limited to one time of day. This is about coverage, not quality.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "daylight-healthy",
                        text: "Healthy data - no problem",
                        feedback: "This is actually a problem. Limited time coverage creates bias. The model won't recognize night conditions.",
                        icon: "exclamationmark.triangle.fill"
                    )
                ],
                aiGuessLine: "{{ai_name}}: \"I don't see any animals in these night photos. Must be empty cages.\"",
                referenceBookTitle: "Lab Notes",
                referencePages: [
                    LectureQuizReferencePage(
                        id: "daylight-note",
                        title: "Bias from Limited Coverage",
                        text: "When training data lacks variety (like different times, angles, or conditions), the AI learns narrow patterns instead of general rules."
                    )
                ]
            ),
            LectureQuizQuestion(
                id: "blurry-aquarium",
                question: "The aquarium camera shows blurry frames due to dirty glass. What is the problem?",
                choices: [
                    LectureQuizOption(
                        id: "blur-bias",
                        text: "Bias - wrong labels",
                        feedback: "Not bias. The issue here is input quality, not label distribution or training coverage.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "blur-bad-data",
                        text: "Bad data - noisy input",
                        feedback: "Correct. This is bad data. The dirty glass creates noise that hides fish shapes, making predictions unreliable.",
                        isBestAnswer: true,
                        icon: "camera.metering.unknown"
                    ),
                    LectureQuizOption(
                        id: "blur-healthy",
                        text: "Healthy data - normal",
                        feedback: "Blurry views are not normal. The AI can't identify what it can't see clearly.",
                        icon: "exclamationmark.triangle.fill"
                    )
                ],
                aiGuessLine: "{{ai_name}}: \"That blurry shape could be anything... maybe a sea monster?\"",
                referenceBookTitle: "Lab Notes",
                referencePages: [
                    LectureQuizReferencePage(
                        id: "blur-note",
                        title: "Bad Data = Bad Predictions",
                        text: "Noisy, blurry, or unclear input creates bad data. Even smart AI can't guess well when the evidence is hidden."
                    )
                ]
            ),
            LectureQuizQuestion(
                id: "red-panda-rule",
                question: "Training labels taught 'panda = only big black-and-white'. Now the AI rejects red pandas. What is this?",
                choices: [
                    LectureQuizOption(
                        id: "rp-rule-bias",
                        text: "Bias - narrow pattern",
                        feedback: "Correct. This is bias. The training examples were too narrow, so valid exceptions get rejected. Not all pandas look the same!",
                        isBestAnswer: true,
                        icon: "pawprint.fill"
                    ),
                    LectureQuizOption(
                        id: "rp-rule-bad-data",
                        text: "Bad data - wrong labels",
                        feedback: "The labels aren't wrong, just incomplete. The problem is narrow training, not incorrect labels.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "rp-rule-healthy",
                        text: "Healthy - rules are rules",
                        feedback: "Rules should have exceptions. Real pandas come in different colors and sizes.",
                        icon: "exclamationmark.triangle.fill"
                    )
                ],
                aiGuessLine: "{{ai_name}}: \"That's not a panda. Pandas are big and black-and-white. This is clearly fake.\"",
                referenceBookTitle: "Lab Notes",
                referencePages: [
                    LectureQuizReferencePage(
                        id: "rp-rule-note",
                        title: "Overgeneralization",
                        text: "When examples are too narrow, AI overgeneralizes. 'Most pandas are black-and-white' becomes 'ALL pandas must be black-and-white'."
                    )
                ]
            ),
            LectureQuizQuestion(
                id: "wrong-labels",
                question: "Someone copied the wrong labels during import. Catfish photos are labeled as 'rock'. What is this?",
                choices: [
                    LectureQuizOption(
                        id: "label-bias",
                        text: "Bias - limited variety",
                        feedback: "Not bias. The variety exists in the photos, but the labels are simply wrong.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "label-bad-data",
                        text: "Bad data - wrong labels",
                        feedback: "Correct. This is bad data. Incorrect labels directly poison the training signal. The AI learns the wrong associations.",
                        isBestAnswer: true,
                        icon: "tag.slash.fill"
                    ),
                    LectureQuizOption(
                        id: "label-healthy",
                        text: "Healthy - minor issue",
                        feedback: "Wrong labels are a major issue. The AI will learn completely wrong associations.",
                        icon: "exclamationmark.triangle.fill"
                    )
                ],
                aiGuessLine: "{{ai_name}}: \"I see a catfish, but the label says rock. I'll trust the label. It's a rock.\"",
                referenceBookTitle: "Lab Notes",
                referencePages: [
                    LectureQuizReferencePage(
                        id: "label-note",
                        title: "Label Quality Matters",
                        text: "AI learns from labels. Wrong labels teach wrong lessons. Always verify label accuracy before training."
                    )
                ]
            ),
            LectureQuizQuestion(
                id: "single-accent",
                question: "The speech dataset only has one regional accent. Users with different accents get poor recognition. What is this?",
                choices: [
                    LectureQuizOption(
                        id: "accent-bias",
                        text: "Bias - limited representation",
                        feedback: "Correct. This is bias from limited representation. The training set doesn't cover real-world diversity.",
                        isBestAnswer: true,
                        icon: "waveform.badge.mic"
                    ),
                    LectureQuizOption(
                        id: "accent-bad-data",
                        text: "Bad data - audio noise",
                        feedback: "The audio quality is fine. The issue is who is represented in the training data.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "accent-healthy",
                        text: "Healthy - one accent is enough",
                        feedback: "One accent is never enough for global use. Representation matters for fair AI.",
                        icon: "exclamationmark.triangle.fill"
                    )
                ],
                aiGuessLine: "{{ai_name}}: \"I can't understand your accent. Could you speak more like the training data?\"",
                referenceBookTitle: "Lab Notes",
                referencePages: [
                    LectureQuizReferencePage(
                        id: "accent-note",
                        title: "Representation Bias",
                        text: "When training data lacks diversity, the AI works poorly for underrepresented groups. Fair AI needs diverse training examples."
                    )
                ]
            ),
            LectureQuizQuestion(
                id: "healthy-dataset",
                question: "A zoo dataset has multiple angles, lighting conditions, ages, and verified labels. What is this?",
                choices: [
                    LectureQuizOption(
                        id: "healthy-bias",
                        text: "Bias - too much variety",
                        feedback: "Variety prevents bias, not causes it. More diverse data helps the AI generalize better.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "healthy-bad-data",
                        text: "Bad data - inconsistent",
                        feedback: "Different angles and lighting are good, not bad. This creates robust training data.",
                        icon: "xmark.circle.fill"
                    ),
                    LectureQuizOption(
                        id: "healthy-good",
                        text: "Healthy data - balanced",
                        feedback: "Correct. This is healthy data. Diversity + clarity + verified labels = reliable AI.",
                        isBestAnswer: true,
                        icon: "checkmark.seal.fill"
                    )
                ],
                aiGuessLine: "{{ai_name}}: \"I can identify animals in many conditions because I've seen diverse examples!\"",
                referenceBookTitle: "Lab Notes",
                referencePages: [
                    LectureQuizReferencePage(
                        id: "healthy-note",
                        title: "Healthy Data Checklist",
                        text: "Good training data: diverse examples, clear inputs, verified labels, balanced representation across categories."
                    )
                ]
            )
        ],
        promptLabel: "Test your knowledge: Is this Bias, Bad Data, or Healthy Data?",
        summaryNote: "Bias usually comes from narrow or unbalanced training examples. Bad data comes from noisy inputs or wrong labels. Safer AI needs both better data quality and better data coverage.",
        teacherName: "{{ai_name}}",
        teacherRole: "AI Friend",
        teacherImageName: "unknow",
        studentName: "You",
        studentRole: "Friend",
        studentImageName: "char",
        usesClassroomStageLayout: false,
        studentGivesCorrectionFeedback: true
    )
