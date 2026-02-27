import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: GlobalSettingsStore
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    // Temporary toggle: keep startup screens in code, but bypass them at launch.
    private let skipStartupScreens = true
    @State private var showMainMenu = true
    @State private var contentOpacity: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                // Solid black background first to prevent white flash
                Color.black.ignoresSafeArea()
                
                // Background that adapts to screen size
                backgroundLayer(layout: layout)
                
                // Main content with transition
                contentLayer(layout: layout)
            }
            .opacity(contentOpacity)
            .animation(settings.reduceMotion ? nil : .easeInOut(duration: 0.5), value: showMainMenu)
        }
        .ignoresSafeArea()
        .neuraPointerFX()
        .accessibleColors(colorBlindMode: settings.colorBlindMode)
        .accessibilityLabel("Neura App")
        .transaction { transaction in
            if settings.reduceMotion {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
        .onAppear {
            if systemReduceMotion {
                settings.reduceMotion = true
            }
            // Ensure the initial state follows the temporary bypass toggle.
            if showMainMenu != skipStartupScreens {
                showMainMenu = skipStartupScreens
            }
        }
        .onChange(of: systemReduceMotion) {
            settings.reduceMotion = systemReduceMotion
        }
    }
    
    // MARK: - Background Layer
    private func backgroundLayer(layout: ResponsiveLayout) -> some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(hex: "0d0d1a"),
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Responsive animated orbs
            Group {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: layout.width * 0.4
                        )
                    )
                    .frame(width: layout.width * 0.8)
                    .offset(x: -layout.width * 0.1, y: -layout.height * 0.1)
                    .blur(radius: layout.scaled(60))
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.pink.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: layout.width * 0.3
                        )
                    )
                    .frame(width: layout.width * 0.6)
                    .offset(x: layout.width * 0.15, y: layout.height * 0.1)
                    .blur(radius: layout.scaled(50))
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Content Layer
    private func contentLayer(layout: ResponsiveLayout) -> some View {
        Group {
            if showMainMenu {
                MainMenuView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity
                    ))
            } else {
                LoadingView(onStart: {
                    withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                        showMainMenu = true
                    }
                })
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalSettingsStore())
        .preferredColorScheme(.dark)
}
