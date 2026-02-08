import SwiftUI

// MARK: - App entry (REMOVE if you already have another @main App)
@main
struct NeuraApp: App {
    var body: some Scene {
        WindowGroup {
            LoadingView(onStart: {
                // Replace with your navigation / state change
                print("TOUCH TO START (tap anywhere)")
            })
        }
    }
}
