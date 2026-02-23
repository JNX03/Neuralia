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

// MARK: - Menu Destination Enum
enum MenuDestination: Hashable {
    case featureTesting
    case gallery
    case settings
    case about
    case chapterSelect
    case playChapterOne
}

extension MenuDestination: Identifiable {
    var id: String {
        switch self {
        case .featureTesting: return "featureTesting"
        case .gallery: return "gallery"
        case .settings: return "settings"
        case .about: return "about"
        case .chapterSelect: return "chapterSelect"
        case .playChapterOne: return "playChapterOne"
        }
    }
}

struct MainMenuView: View {
    @EnvironmentObject private var settings: GlobalSettingsStore
    @StateObject private var viewModel = MainMenuViewModel()
    @State private var destination: MenuDestination? = nil
    
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
                configureMotionTimer()
            }
            .onDisappear {
                viewModel.stop()
            }
            .onChange(of: settings.reduceMotion) {
                configureMotionTimer()
            }
            .fullScreenCover(item: $destination) { destination in
                switch destination {
                case .featureTesting:
                    FeatureTestingView()
                case .gallery:
                    GalleryView()
                case .settings:
                    SettingsView(settings: settings)
                case .about:
                    AboutView()
                case .chapterSelect:
                    NavigationStack {
                        StoryChapterHubView()
                    }
                case .playChapterOne:
                    NavigationStack {
                        if let firstChapter = StoryChapterRepository.all.first {
                            StoryChapterPlayerView(initialChapter: firstChapter)
                        } else {
                            StoryChapterHubView()
                        }
                    }
                }
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
                .offset(
                    x: viewModel.offsetX * settings.effectiveParallaxStrength,
                    y: viewModel.offsetY * settings.effectiveParallaxStrength
                )
                .ignoresSafeArea()
            
            Color.black.opacity(settings.menuOverlayOpacity)
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
            // Primary buttons - Play, Select, and Lab (bigger)
            LargeMenuButton(
                title: "Play",
                icon: "play.fill",
                layout: layout,
                action: {
                    destination = .playChapterOne
                }
            )
            
            LargeMenuButton(
                title: "Select",
                icon: "square.grid.2x2",
                layout: layout,
                action: {
                    destination = .chapterSelect
                }
            )
            
            LargeMenuButton(
                title: "Lab",
                subtitle: "Playground",
                icon: "testtube.2",
                layout: layout,
                action: {
                    destination = .featureTesting
                }
            )
            
            // Small action buttons row - equal sizes
            HStack(spacing: layout.elementSpacing) {
                SmallIconButton(
                    title: "Gallery",
                    subtitle: "Memory",
                    icon: "photo.on.rectangle.angled",
                    layout: layout,
                    action: {
                        destination = .gallery
                    }
                )
                .frame(maxWidth: .infinity)
                
                SmallIconButton(
                    title: "Settings",
                    subtitle: nil,
                    icon: "gearshape.fill",
                    layout: layout,
                    action: {
                        destination = .settings
                    }
                )
                .frame(maxWidth: .infinity)
                
                SmallIconButton(
                    title: "About",
                    subtitle: "Credit",
                    icon: "info.circle.fill",
                    layout: layout,
                    action: {
                        destination = .about
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .frame(height: layout.scaled(80))
        }
    }
    
    // MARK: - Status Indicator
    @ViewBuilder
    private func statusIndicator(layout: ResponsiveLayout) -> some View {
        if settings.showStatusIndicator {
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
    }
    
    // MARK: - Version Label
    @ViewBuilder
    private func versionLabel(layout: ResponsiveLayout) -> some View {
        if settings.showVersionLabel {
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
    
    private func configureMotionTimer() {
        if settings.reduceMotion {
            viewModel.stop()
            viewModel.resetOffsets()
        } else {
            viewModel.start()
        }
    }
}

extension MainMenuViewModel {
    func resetOffsets() {
        offsetX = 0
        offsetY = 0
    }
}

// MARK: - Large Menu Button (Primary Actions)
struct LargeMenuButton: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let layout: ResponsiveLayout
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
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
                    .fill(Color.white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            ZStack {
                // Background fills entire button
                RoundedRectangle(cornerRadius: layout.cornerRadius * 0.8)
                    .fill(Color.white.opacity(isHovered ? 0.15 : 0.08))
                
                // Content centered
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: layout.iconSize))
                        .frame(height: layout.iconSize)
                    
                    // Fixed height container for text to ensure consistency
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: layout.captionFontSize, weight: .medium))
                        
                        // Always reserve space for subtitle (show if exists, or invisible spacer)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(size: layout.captionFontSize * 0.85, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text(" ")
                                .font(.system(size: layout.captionFontSize * 0.85, weight: .regular))
                        }
                    }
                    .frame(height: layout.captionFontSize * 2.2)
                }
                .foregroundColor(.white)
            }
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
    var body: some View {
        StoryGalleryMuseumView()
    }
}

// MARK: - About View (Credits Page)
struct AboutView: View {
    var body: some View {
        CreditsView()
    }
}

#Preview {
    MainMenuView()
        .environmentObject(GlobalSettingsStore())
        .preferredColorScheme(.dark)
}
