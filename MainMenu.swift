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
    @State private var showGallery = false
    @State private var showSettings = false
    @State private var showAbout = false
    
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
            .fullScreenCover(isPresented: $showGallery) {
                GalleryView()
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showAbout) {
                AboutView()
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
                // Icon - Much bigger
                HStack {
                    Spacer()
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: layout.menuIconSize * 1.5, height: layout.menuIconSize * 1.5)
                        .shadow(color: .black.opacity(0.5), radius: layout.scaled(15))
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
                        .frame(width: layout.menuIconSize * 1.6, height: layout.menuIconSize * 1.6)
                        .shadow(color: .black.opacity(0.5), radius: layout.scaled(18))
                    Spacer()
                }
                .padding(.top, layout.safeAreaInsets.top + 20)
                
                menuButtons(layout: layout)
                
                Spacer()
                
                statusIndicator(layout: layout)
            }
            .padding(layout.padding)
            .frame(width: layout.menuWidth)
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
                        .frame(width: layout.menuIconSize * 1.8, height: layout.menuIconSize * 1.8)
                        .shadow(color: .black.opacity(0.5), radius: layout.scaled(20))
                    Spacer()
                }
                .padding(.top, layout.safeAreaInsets.top + 30)
                
                menuButtons(layout: layout)
                
                Spacer()
                
                statusIndicator(layout: layout)
            }
            .padding(layout.padding)
            .frame(width: layout.menuWidth)
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
        VStack(spacing: layout.elementSpacing * 1.5) {
            // Primary buttons - Play and Lab (bigger)
            LargeMenuButton(
                title: "Play",
                icon: "play.fill",
                layout: layout,
                action: {}
            )
            
            LargeMenuButton(
                title: "Lab",
                subtitle: "Playground",
                icon: "testtube.2",
                layout: layout,
                action: {
                    showFeatureTesting = true
                }
            )
            
            // Small action buttons row
            HStack(spacing: layout.elementSpacing) {
                SmallIconButton(
                    title: "Gallery",
                    subtitle: "Memory",
                    icon: "photo.on.rectangle.angled",
                    layout: layout,
                    action: {
                        showGallery = true
                    }
                )
                
                SmallIconButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    layout: layout,
                    action: {
                        showSettings = true
                    }
                )
                
                SmallIconButton(
                    title: "About",
                    subtitle: "Credit",
                    icon: "info.circle.fill",
                    layout: layout,
                    action: {
                        showAbout = true
                    }
                )
            }
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

// MARK: - Large Menu Button (Primary Actions)
struct LargeMenuButton: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let layout: ResponsiveLayout
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: layout.elementSpacing * 1.5) {
                    Image(systemName: icon)
                        .font(.system(size: layout.iconSize * 1.3))
                        .frame(width: layout.scaled(40))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: layout.bodyFontSize * 1.3, weight: .semibold))
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: layout.captionFontSize, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, layout.padding)
            .padding(.vertical, layout.scaled(18))
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0.1))
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

// MARK: - Small Icon Button (Secondary Actions)
struct SmallIconButton: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let layout: ResponsiveLayout
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: layout.iconSize))
                
                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: layout.captionFontSize, weight: .medium))
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: layout.captionFontSize * 0.85, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout.scaled(10))
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius * 0.8)
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0.08))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
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

// MARK: - Gallery View (Blank Page)
struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Gallery (Memory)")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Coming Soon")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Settings View (Blank Page)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Settings")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Coming Soon")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - About View (Blank Page)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("About / Credit")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("Coming Soon")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    MainMenuView()
        .preferredColorScheme(.dark)
}
