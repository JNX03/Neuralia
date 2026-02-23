import Foundation

let chapterTwoStory = StoryChapter(
    id: "chapter2",
    title: "New Friend?",
    subtitle: "Hallucination / Bias / Bad Data",
    accentHex: "8B5CF6",
    coverBackgroundImage: "507room",
    coverCharacterImage: "char_curious",
    overview: "You spend Saturday with Ploy at Chiang Mai Zoo and learn how AI can hallucinate, overgeneralize, and fail when the input data is unclear.",
    lines: [
        StoryDialogLine(
            speaker: "Narration",
            text: "You wake up on Saturday morning and realize Ploy is still here, like... actually here.",
            emotion: .surprised,
            backgroundImage: "507room",
            characterImage: "char_surprised",
            cutsceneTitle: "Chapter 2",
            cutsceneSubtitle: "New Friend?"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You are still not fully used to it, so you test something simple.",
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
                subtitle: "Ploy guessed a time that cannot exist.",
                imageName: "__clock_placeholder__",
                badge: "10:67",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Bro... 10:67 is not a real time.",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "char_concerned",
            cutsceneTitle: "Impossible Time",
            cutsceneSubtitle: "Check reality first"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Oh- sorry. I guessed.",
            emotion: .concerned,
            backgroundImage: "507room",
            characterImage: "char_concerned",
            cutsceneTitle: "Honest Moment",
            cutsceneSubtitle: "Guessing is risky"
        ),
        StoryDialogLine(
            speaker: "Saen00g",
            text: "Sometimes AI can generate answers that sound correct even if they are wrong, especially when it does not have reliable context. This is called hallucination.",
            emotion: .gentle,
            backgroundImage: "507room",
            characterImage: "char_gentle",
            cutsceneTitle: "Lesson: Hallucination",
            cutsceneSubtitle: "Sounding correct is not the same as being correct"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Best way to reduce this: verify with real sources like clocks, signs, and trusted info. Also let me say 'I am not sure' instead of forcing an answer.",
            emotion: .gentle,
            backgroundImage: "507room",
            characterImage: "char_gentle",
            cutsceneTitle: "Safe AI Habit",
            cutsceneSubtitle: "Verify first / uncertainty is okay"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Fix the time by picking a real one.",
            emotion: .curious,
            backgroundImage: "507room",
            characterImage: "char_curious",
            cutsceneTitle: "Mini Check",
            cutsceneSubtitle: "Choose the correct time",
            showcaseMedia: DialogShowcaseMedia(
                title: "Reality Check",
                subtitle: "Find the valid time instead of trusting the hallucinated one.",
                imageName: "__clock_placeholder__",
                badge: "Pick One",
                prefersSplitLayout: true
            ),
            choices: [
                DialogChoice(
                    text: "10:07",
                    emotion: .happy,
                    response: "Correct. A real clock value makes more sense than a confident guess.",
                    icon: "checkmark.circle.fill"
                ),
                DialogChoice(
                    text: "10:67",
                    emotion: .concerned,
                    response: "Not this one. 67 minutes is impossible, so we should verify and correct it.",
                    icon: "xmark.circle.fill"
                ),
                DialogChoice(
                    text: "99:10",
                    emotion: .concerned,
                    response: "Also impossible. Good AI use means checking if the answer is valid in real life.",
                    icon: "exclamationmark.triangle.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "After that, you decide to take Ploy outside for a day because you want to build memories with him. You choose Chiang Mai Zoo.",
            emotion: .excited,
            backgroundImage: "cnxgate",
            characterImage: "char_excited",
            cutsceneTitle: "Day Trip",
            cutsceneSubtitle: "Chiang Mai Zoo"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "At the zoo, everything is fun at first. Ploy is excited and keeps trying to identify animals like it is a game.",
            emotion: .happy,
            backgroundImage: "cnxgate",
            characterImage: "char_happy",
            cutsceneTitle: "Zoo Game",
            cutsceneSubtitle: "Guess, check, learn"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You point to a bird. Ploy says, 'That is... a plane?' You say, 'No, that is a bird.' You decide to practice with simple placeholder animal cards first so Ploy can learn the rules.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Practice First",
            cutsceneSubtitle: "Simple cards / clear labels"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Woah...! That is a hippo, right?",
            emotion: .excited,
            backgroundImage: "cnxgate",
            characterImage: "char_excited",
            cutsceneTitle: "Practice Round 1",
            cutsceneSubtitle: "Hallucination (placeholder panda image)",
            showcaseMedia: DialogShowcaseMedia(
                title: "Animal Card",
                subtitle: "Ploy guessed too fast. Check the picture carefully.",
                imageName: "download",
                badge: "Round 1",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Pick the correct label.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Practice Round 1",
            cutsceneSubtitle: "Use your eyes, not Ploy's confidence",
            showcaseMedia: DialogShowcaseMedia(
                title: "Animal Card",
                subtitle: "Placeholder image set: panda.",
                imageName: "download",
                badge: "Choose",
                prefersSplitLayout: true
            ),
            choices: [
                DialogChoice(
                    text: "Panda",
                    emotion: .happy,
                    response: "Correct. Memory photo unlocked. You used the picture, not the AI guess.",
                    icon: "camera.fill"
                ),
                DialogChoice(
                    text: "Hippo",
                    emotion: .concerned,
                    response: "Close check, but this one is a panda. AI hallucination can sound confident and still be wrong.",
                    icon: "eye.fill"
                ),
                DialogChoice(
                    text: "Shiba Dog",
                    emotion: .curious,
                    response: "Nope. This is a panda. Always compare the guess with visible clues.",
                    icon: "pawprint.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Okay... I should slow down and check the sign before I guess.",
            emotion: .gentle,
            backgroundImage: "cnxgate",
            characterImage: "char_gentle",
            cutsceneTitle: "Learning Habit",
            cutsceneSubtitle: "Verify before answer"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Woah...! That's a Panda!",
            emotion: .excited,
            backgroundImage: "cnxgate",
            characterImage: "char_excited",
            cutsceneTitle: "Practice Round 2",
            cutsceneSubtitle: "Bias / assumption (placeholder shiba image)",
            showcaseMedia: DialogShowcaseMedia(
                title: "Animal Card",
                subtitle: "Ploy overgeneralized from fuzzy animal patterns.",
                imageName: "shiba-inu-puppy-looks-like-600nw-2354684599",
                badge: "Round 2",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Pick the correct label again.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Practice Round 2",
            cutsceneSubtitle: "Check labels / avoid assumptions",
            showcaseMedia: DialogShowcaseMedia(
                title: "Animal Card",
                subtitle: "Placeholder image set: shiba.",
                imageName: "shiba-inu-puppy-looks-like-600nw-2354684599",
                badge: "Choose",
                prefersSplitLayout: true
            ),
            choices: [
                DialogChoice(
                    text: "Shiba Dog",
                    emotion: .happy,
                    response: "Correct. Memory photo unlocked. Labels and ground truth help fix wrong pattern guesses.",
                    icon: "camera.fill"
                ),
                DialogChoice(
                    text: "Panda",
                    emotion: .concerned,
                    response: "Nope. Ploy overgeneralized from patterns. This is why assumptions can cause bias errors.",
                    icon: "brain.head.profile"
                ),
                DialogChoice(
                    text: "Hippo",
                    emotion: .concerned,
                    response: "Not this one. Compare shape, face, and context before deciding.",
                    icon: "eye.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "Then you walk past the Panda zone and later reach the Red Panda enclosure.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Red Panda Zone",
            cutsceneSubtitle: "Pattern assumptions fail on exceptions"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Look! A fox! Or maybe a raccoon? Impossible. My pattern says panda means big, black and white, and eats bamboo. This one is small and red.",
            emotion: .surprised,
            backgroundImage: "cnxgate",
            characterImage: "char_surprised",
            cutsceneTitle: "Bias Example",
            cutsceneSubtitle: "Overgeneralization"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Read the sign. It is a Red Panda. AI can overgeneralize from patterns in training data. That is bias or assumption, and it is why we need labels, ground truth, and diverse data.",
            emotion: .gentle,
            backgroundImage: "cnxgate",
            characterImage: "char_gentle",
            cutsceneTitle: "Lesson: Bias",
            cutsceneSubtitle: "Labels + ground truth + diverse data"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Choose the correct label for the enclosure sign.",
            emotion: .curious,
            backgroundImage: "cnxgate",
            characterImage: "char_curious",
            cutsceneTitle: "Red Panda Check",
            cutsceneSubtitle: "Sign beats assumptions",
            choices: [
                DialogChoice(
                    text: "Fox",
                    emotion: .concerned,
                    response: "Not this time. The sign gives the ground truth: Red Panda.",
                    icon: "xmark.circle.fill"
                ),
                DialogChoice(
                    text: "Raccoon",
                    emotion: .concerned,
                    response: "Good guess to compare, but the sign says Red Panda.",
                    icon: "xmark.circle.fill"
                ),
                DialogChoice(
                    text: "Red Panda",
                    emotion: .happy,
                    response: "Correct. Memory photo card added.",
                    icon: "camera.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "After that you go into the aquarium.",
            emotion: .curious,
            backgroundImage: "cnxaqu",
            characterImage: "char_curious",
            cutsceneTitle: "Aquarium",
            cutsceneSubtitle: "Bad data lesson"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Alert! I detected a Sea Monster! Green slime skin, 10 meters long!",
            emotion: .surprised,
            backgroundImage: "cnxaqu",
            characterImage: "char_surprised",
            cutsceneTitle: "Practice Round 3",
            cutsceneSubtitle: "Bad data (placeholder hippo image)",
            showcaseMedia: DialogShowcaseMedia(
                title: "Bad Data Card",
                subtitle: "Use this placeholder image to teach the idea: unclear input can create wild guesses.",
                imageName: "Portrait_Hippopotamus_in_the_water",
                badge: "Round 3",
                prefersSplitLayout: true
            )
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Wait... look closer. When the input is unclear (blocked view, bad lighting, low quality), AI can make wrong predictions. Improve the input and the result gets better.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Lesson: Bad Data",
            cutsceneSubtitle: "Improve input quality"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "What is the correct animal in this practice card?",
            emotion: .curious,
            backgroundImage: "cnxaqu",
            characterImage: "char_curious",
            cutsceneTitle: "Practice Round 3",
            cutsceneSubtitle: "Look closer and verify",
            showcaseMedia: DialogShowcaseMedia(
                title: "Bad Data Card",
                subtitle: "Placeholder image set: hippo. Pretend the first view was blurry or blocked.",
                imageName: "Portrait_Hippopotamus_in_the_water",
                badge: "Choose",
                prefersSplitLayout: true
            ),
            choices: [
                DialogChoice(
                    text: "Hippo",
                    emotion: .happy,
                    response: "Correct. Memory photo unlocked. Better input helps AI make better predictions.",
                    icon: "camera.fill"
                ),
                DialogChoice(
                    text: "Sea Monster",
                    emotion: .concerned,
                    response: "That was the hallucinated guess. With clearer data, we can identify it correctly as a hippo.",
                    icon: "exclamationmark.triangle.fill"
                ),
                DialogChoice(
                    text: "Rock",
                    emotion: .concerned,
                    response: "Not quite. Looking carefully and improving the view helps reveal the real answer: hippo.",
                    icon: "eye.fill"
                )
            ]
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Thanks for correcting me... you do not get angry when I am wrong.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Quiet Moment",
            cutsceneSubtitle: "After the zoo"
        ),
        StoryDialogLine(
            speaker: "You",
            text: "Because being wrong is normal. But pretending you are always right is dangerous.",
            emotion: .gentle,
            backgroundImage: "cnxaqu",
            characterImage: "char_gentle",
            cutsceneTitle: "Trust Rule",
            cutsceneSubtitle: "Honesty is safer than fake confidence"
        ),
        StoryDialogLine(
            speaker: "Narration",
            text: "You both head home with a few new memory photos saved in the album, and Ploy feels a bit more real, not because he is human, but because you are starting to understand him properly.",
            emotion: .happy,
            backgroundImage: "redbus",
            characterImage: "char_happy",
            cutsceneTitle: "Chapter End",
            cutsceneSubtitle: "New memories / better understanding"
        ),
        StoryDialogLine(
            speaker: "Ploy",
            text: "Next time I will try to say 'I am not sure' before I guess. You can help me with better clues and better data.",
            emotion: .excited,
            backgroundImage: "507room",
            characterImage: "char_excited",
            cutsceneTitle: "To Be Continued",
            cutsceneSubtitle: "Safer AI habits"
        )
    ]
)
