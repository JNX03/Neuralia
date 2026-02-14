import SwiftUI

struct ContentView: View {
    @State private var showMainMenu = false
    
    var body: some View {
        ZStack {
            if showMainMenu {
                MainMenuView()
            } else {
                LoadingView(onStart: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showMainMenu = true
                    }
                })
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
