import SwiftUI

#Preview {
    ResponsiveDialogView(
        nodes: [
            DialogNode(
                speaker: "Ploy",
                text: "Welcome to the new responsive dialog system! This works on all devices including iPhone, iPad, and Mac.",
                emotion: .happy,
                choices: nil,
                requiresInput: false,
                inputPlaceholder: nil,
                backgroundImage: nil,
                characterImage: "char"
            ),
            DialogNode(
                speaker: "Ploy",
                text: "How does this look on your device? The layout automatically adapts to your screen size!",
                emotion: .curious,
                choices: [
                    DialogChoice(text: "It looks great!", emotion: .happy, response: "", icon: "hand.thumbsup.fill"),
                    DialogChoice(text: "Pretty good", emotion: .neutral, response: "", icon: "checkmark.circle.fill"),
                    DialogChoice(text: "Could be better", emotion: .sad, response: "", icon: "exclamationmark.triangle.fill")
                ],
                requiresInput: false,
                inputPlaceholder: nil,
                backgroundImage: nil,
                characterImage: "char"
            )
        ]
    )
    .preferredColorScheme(.dark)
}
