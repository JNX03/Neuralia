import SwiftUI

struct ContentView: View {
    @State private var showMainMenu = false
    
    var body: some View {
        ZStack {
            if showMainMenu {
                MainMenuView()
                    .transition(.opacity)
            } else {
                LoadingView(onStart: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showMainMenu = true
                    }
                })
                .transition(.opacity)
            }
        }
    }
}
