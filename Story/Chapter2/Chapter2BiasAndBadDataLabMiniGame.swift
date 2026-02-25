import Foundation

import Foundation

let chapter2BiasAndBadDataLabMiniGame = Chapter2InteractiveLabMiniGame(
    title: "Understanding Bias & Bad Data",
    stages: [
        // Beat 1: Time Hallucination
        Chapter2InteractiveLabStage(
            id: "time_correction",
            defaultSpeakerText: "",
            aiGuessText: "10:67.",
            type: .timeCorrection(
                options: ["11:07", "10:67", "10:07"],
                correctOptions: ["11:07"] // Contextual, anything but 10:67. Let's assume the real time is a valid choice.
            ),
            feedbackCorrectText: "You correct the clock.",
            feedbackIncorrectText: "That's also not a real time... wait, let me check the physical clock."
        ),
        
        // Beat 2: Zoo Bird Labeling
        Chapter2InteractiveLabStage(
            id: "zoo_bird",
            backgroundVisualKey: "bg_zoo",
            defaultSpeakerText: "You point at a bird.",
            aiGuessText: "That's... a plane?",
            type: .imageLabeling(
                options: ["Plane", "Bird", "Drone"],
                correctOptions: ["Bird"],
                badgeText: "Identifying object"
            ),
            feedbackCorrectText: "(Photo memory unlocked: Ploy pointing confidently at a pigeon, calling it a Boeing 747.)",
            feedbackIncorrectText: "No... that's definitely not it. Use your eyes, Ploy."
        ),
        
        // Beat 3: Red Panda Bias
        Chapter2InteractiveLabStage(
            id: "red_panda",
            backgroundVisualKey: "bg_zoo",
            defaultSpeakerText: "You point at the Red Panda enclosure.",
            aiGuessText: "Look! A fox! Or maybe a raccoon? Impossible. My pattern says panda = big, black and white, and eats bamboo. This one is small and red.",
            type: .imageLabeling(
                options: ["Fox", "Raccoon", "Red Panda"],
                correctOptions: ["Red Panda"],
                badgeText: "Reading sign"
            ),
            feedbackCorrectText: "(Photo memory unlocked: You pointing at the sign while Ploy looks confused at the small red 'panda'.)",
            feedbackIncorrectText: "Read the sign carefully..."
        ),
        
        // Beat 4: Aquarium Algae Wiping
        Chapter2InteractiveLabStage(
            id: "aquarium_algae",
            backgroundVisualKey: "bg_aquarium",
            defaultSpeakerText: "Ploy suddenly points at a dark shape behind thick green algae on the glass.",
            aiGuessText: "Alert! I detected a Sea Monster! Green slime skin, 10 meters long!",
            type: .swipeReveal(
                baseImage: "catfish_clear",
                overlayImage: "algae_dirty"
            ),
            feedbackCorrectText: "(Photo memory unlocked: The giant catfish happily swimming, no longer a 'sea monster'.)",
            feedbackIncorrectText: "Wait... look closer. Wipe the glass."
        )
    ]
)
