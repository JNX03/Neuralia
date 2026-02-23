import SwiftUI

@main
struct NeuraApp: App {
    @StateObject private var globalSettings = GlobalSettingsStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(globalSettings)
        }
    }
}
