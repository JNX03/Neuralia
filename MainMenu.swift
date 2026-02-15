import SwiftUI
import Combine

@MainActor
class MainMenuViewModel: ObservableObject {
    @Published var offsetX: CGFloat = 0
    @Published var offsetY: CGFloat = 0
    
    private var lastTouchTime = Date()
    private var timer: Timer?
    private var idleTime: Double = 0
    private var isUserInteracting = false
    
    private let maxOffset: CGFloat = 25
    private let idleDelay: TimeInterval = 2.0
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func handleTouch(translation: CGSize) {
        isUserInteracting = true
        lastTouchTime = Date()
        idleTime = 0
        
        let damping: CGFloat = 0.25
        var newX = translation.width * damping
        var newY = translation.height * damping
        
        newX = max(-maxOffset, min(maxOffset, newX))
        newY = max(-maxOffset, min(maxOffset, newY))
        
        offsetX = newX
        offsetY = newY
    }
    
    func touchEnded() {
        lastTouchTime = Date()
        isUserInteracting = false
    }
    
    private func update() {
        let timeSinceTouch = Date().timeIntervalSince(lastTouchTime)
        
        if timeSinceTouch >= idleDelay {
            idleTime += 0.016
            
            let wave1X = sin(idleTime * 0.8) * 15
            let wave2X = sin(idleTime * 0.3) * 8
            let wave1Y = cos(idleTime * 0.6) * 12
            let wave2Y = sin(idleTime * 0.4) * 6
            
            let targetX = wave1X + wave2X
            let targetY = wave1Y + wave2Y
            
            offsetX += (targetX - offsetX) * 0.05
            offsetY += (targetY - offsetY) * 0.05
        } else {
            offsetX *= 0.98
            offsetY *= 0.98
        }
    }
}

struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()
    @State private var showFeatureTesting = false
    
    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                // Background
                backgroundLayer(layout: layout)
                
                // Content based on layout mode
                switch layout.layoutMode {
                case .compact, .regular:
                    compactLayout(layout: layout)
                case .expanded:
                    expandedLayout(layout: layout)
                case .desktop:
                    desktopLayout(layout: layout)
                }
                
                // Version info - always at bottom
                versionLabel(layout: layout)
            }
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        viewModel.handleTouch(translation: value.translation)
                    }
                    .onEnded { _ in
                        viewModel.touchEnded()
                    }
            )
            .fullScreenCover(isPresented: $showFeatureTesting) {
                FeatureTestingView()
            }
        }
    }
    
    // MARK: - Background
    private func backgroundLayer(layout: ResponsiveLayout) -> some View {
        ZStack {
            Image("cnxaqu")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.4)
                .offset(x: viewModel.offsetX, y: viewModel.offsetY)
                .ignoresSafeArea()
            
            Color.black.opacity(0.5)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Compact Layout (iPhone Portrait/Small)
    private func compactLayout(layout: ResponsiveLayout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                // Icon
                HStack {
                    Spacer()
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: layout.menuIconSize, height: layout.menuIconSize)
                        .shadow(color: .black.opacity(0.5), radius: layout.scaled(10))
                    Spacer()
                }
                .padding(.top, layout.safeAreaInsets.top + 10)
                
                // Menu buttons
                menuButtons(layout: layout)
                
                Spacer()
                
                // Status
                statusIndicator(layout: layout)
            }
            .padding(layout.padding)
            .frame(width: layout.menuWidth)
            .background(Color.black.opacity(0.4))
            .cornerRadius(layout.cornerRadius)
            .padding(layout.padding)
            
            Spacer()
        }
    }
    
    // MARK: - Expanded Layout (iPad)
    private func expandedLayout(layout: ResponsiveLayout) -> some View {
        HStack(spacing: 0) {
            // Left panel with menu
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                HStack {
                    Spacer()
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: layout.menuIconSize, height: layout.menuIconSize)
                        .shadow(color: .black.opacity(0.5), radius: layout.scaled(10))
                    Spacer()
                }
                .padding(.top, layout.safeAreaInsets.top + 20)
                
                menuButtons(layout: layout)
                
                Spacer()
                
                statusIndicator(layout: layout)
            }
            .padding(layout.padding)
            .frame(width: layout.menuWidth)
            .background(Color.black.opacity(0.4))
            .cornerRadius(layout.cornerRadius)
            .padding(layout.padding)
            
            Spacer()
        }
    }
    
    // MARK: - Desktop Layout (Mac/Ultrawide)
    private func desktopLayout(layout: ResponsiveLayout) -> some View {
        HStack(spacing: 0) {
            // Left sidebar
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                HStack {
                    Spacer()
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: layout.menuIconSize, height: layout.menuIconSize)
                        .shadow(color: .black.opacity(0.5), radius: layout.scaled(12))
                    Spacer()
                }
                .padding(.top, layout.safeAreaInsets.top + 30)
                
                menuButtons(layout: layout)
                
                Spacer()
                
                statusIndicator(layout: layout)
            }
            .padding(layout.padding)
            .frame(width: layout.menuWidth)
            .background(Color.black.opacity(0.4))
            .cornerRadius(layout.cornerRadius)
            .padding(layout.padding * 1.5)
            
            Spacer()
            
            // Right side - could add additional content here
            VStack {
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Menu Buttons
    private func menuButtons(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.elementSpacing) {
            ResponsiveMenuButton(
                title: "Play",
                icon: "play.fill",
                layout: layout,
                action: {}
            )
            ResponsiveMenuButton(
                title: "Load Game",
                icon: "square.and.arrow.down.fill",
                layout: layout,
                action: {}
            )
            ResponsiveMenuButton(
                title: "Gallery",
                icon: "photo.on.rectangle.angled",
                layout: layout,
                action: {}
            )
            ResponsiveMenuButton(
                title: "Feature Testing",
                icon: "testtube.2",
                layout: layout,
                action: {
                    showFeatureTesting = true
                }
            )
        }
    }
    
    // MARK: - Status Indicator
    private func statusIndicator(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.elementSpacing) {
            Circle()
                .fill(Color.green)
                .frame(width: layout.scaled(8), height: layout.scaled(8))
            Text("Ready to Play")
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
    }
    
    // MARK: - Version Label
    private func versionLabel(layout: ResponsiveLayout) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("Ver 1.0")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.5))
                    .padding()
            }
        }
    }
}

// MARK: - Responsive Menu Button
struct ResponsiveMenuButton: View {
    let title: String
    let icon: String
    let layout: ResponsiveLayout
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.elementSpacing) {
                Image(systemName: icon)
                    .font(.system(size: layout.iconSize))
                    .frame(width: layout.scaled(30))
                
                Text(title)
                    .font(.system(size: layout.bodyFontSize, weight: .medium))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, layout.padding)
            .padding(.vertical, layout.scaled(12))
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Color.white.opacity(isHovered ? 0.3 : 0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .shadow(
                color: Color.white.opacity(isHovered ? 0.1 : 0),
                radius: layout.scaled(8),
                x: 0,
                y: layout.scaled(4)
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

#Preview {
    MainMenuView()
        .preferredColorScheme(.dark)
}
