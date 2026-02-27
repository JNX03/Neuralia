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
    
    func resetOffsets() {
        offsetX = 0
        offsetY = 0
    }
}

// MARK: - Menu Destination Enum
enum MenuDestination: Hashable {
    case featureTesting
    case chapterSelect
    case playChapterOne
}

extension MenuDestination: Identifiable {
    var id: String {
        switch self {
        case .featureTesting: return "featureTesting"
        case .chapterSelect: return "chapterSelect"
        case .playChapterOne: return "playChapterOne"
        }
    }
}

struct MainMenuView: View {
    @EnvironmentObject private var settings: GlobalSettingsStore
    @StateObject private var viewModel = MainMenuViewModel()
    @State private var destination: MenuDestination? = nil
    @State private var showSettingsPopup = false
    @State private var showCreditsPopup = false
    @State private var hoveredButton: String? = nil
    
    // MARK: - Visual Novel / Blue Archive Theme Colors
    private let themeBlue = Color(red: 0.12, green: 0.51, blue: 0.88)
    private let themeLight = Color(red: 0.88, green: 0.95, blue: 0.98)
    private let themeDark = Color(red: 0.05, green: 0.15, blue: 0.25)
    private let themeWhite = Color.white

    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                // Background
                backgroundLayer(layout: layout, geo: geometry)
                
                // Content based on layout mode
                if layout.isLandscape {
                    landscapeLayout(layout: layout, geo: geometry)
                } else {
                    portraitLayout(layout: layout, geo: geometry)
                }

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay {
                if showSettingsPopup {
                    MenuSettingsPopupOverlay(
                        settings: settings,
                        layout: layout,
                        onClose: {
                            withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                showSettingsPopup = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
                }

                if showCreditsPopup {
                    MenuCreditsPopupOverlay(
                        layout: layout,
                        onClose: {
                            withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                showCreditsPopup = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(11)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard !showSettingsPopup, !showCreditsPopup else { return }
                        viewModel.handleTouch(translation: gesture.translation)
                    }
                    .onEnded { _ in
                        viewModel.touchEnded()
                    }
            )
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
                        .neuraPointerFX()
                case .chapterSelect:
                    NavigationStack {
                        StoryChapterHubView()
                    }
                    .neuraPointerFX()
                case .playChapterOne:
                    NavigationStack {
                        if let firstChapter = StoryChapterRepository.all.first {
                            StoryChapterPlayerView(initialChapter: firstChapter)
                        } else {
                            StoryChapterHubView()
                        }
                    }
                    .neuraPointerFX()
                }
            }
        }
    }
    
    // MARK: - Background Layer
    private func backgroundLayer(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack {
            LinearGradient(
                colors: [themeWhite, themeLight, themeWhite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Large Animated Background Image that parallax shifts
            Image("lantassc")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width * 1.2, height: geo.size.height * 1.2)
                .opacity(0.12)
                .offset(
                    x: -viewModel.offsetX * settings.effectiveParallaxStrength * 0.25,
                    y: -viewModel.offsetY * settings.effectiveParallaxStrength * 0.25
                )
                .allowsHitTesting(false)

            // Subtle blue tint on right side only
            SlantedRect(offset: layout.scaled(60), direction: .backward)
                .fill(themeBlue.opacity(0.04))
                .frame(width: geo.size.width * 0.5, height: geo.size.height)
                .offset(x: geo.size.width * 0.4)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Landscape Layout
    private func landscapeLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // LEFT COLUMN: Character at bottom
            VStack(spacing: 0) {
                Spacer()
                
                // Character bottom-left
                HStack {
                    Image("unknow")
                        .resizable()
                        .scaledToFit()
                        .frame(height: geo.size.height * 0.7)
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                        .offset(
                            x: viewModel.offsetX * settings.effectiveParallaxStrength * 0.1,
                            y: viewModel.offsetY * settings.effectiveParallaxStrength * 0.06
                        )
                        .allowsHitTesting(false)
                    Spacer()
                }
                .padding(.leading, layout.scaled(15))
            }
            .frame(width: geo.size.width * 0.48)
            
            // RIGHT COLUMN: System Menu vertically centered
            VStack(spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: layout.scaled(10)) {
                    // Logo above system menu
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: geo.size.height * 0.45)
                        .shadow(color: themeBlue.opacity(0.15), radius: 10)
                        .offset(
                            x: viewModel.offsetX * settings.effectiveParallaxStrength * 0.08,
                            y: viewModel.offsetY * settings.effectiveParallaxStrength * 0.05
                        )
                        .padding(.top, layout.scaled(100))
                        .padding(.leading, layout.scaled(40))
                    
                    MainMenuSidebar(
                        layout: layout,
                        geo: geo,
                        themeBlue: themeBlue,
                        themeWhite: themeWhite,
                        themeDark: themeDark,
                        hoveredButton: $hoveredButton,
                        onPlay: { destination = .playChapterOne },
                        onSelect: { destination = .chapterSelect },
                        onLab: { destination = .featureTesting },
                        onSettings: {
                            withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                showSettingsPopup = true
                            }
                        },
                        onAbout: {
                            withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                showCreditsPopup = true
                            }
                        }
                    )
                }
                
                if settings.showVersionLabel {
                    Text("Ver 1.0.0")
                        .font(.system(size: layout.captionFontSize, weight: .bold))
                        .foregroundColor(AccessibleColors.versionLabel)
                        .padding(.top, layout.scaled(8))
                        .accessibilityLabel("Version 1.0.0")
                }
                
                Spacer()
            }
            .frame(width: geo.size.width * 0.48)
            .padding(.trailing, layout.scaled(15))
        }
        .padding(.top, geo.safeAreaInsets.top + layout.scaled(10))
        .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(10))
    }
    
    // MARK: - Portrait Layout
    private func portraitLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(spacing: layout.scaled(10)) {
            // Logo top-center
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(height: geo.size.height * 0.55)
                .shadow(color: themeBlue.opacity(0.15), radius: 8)
                .padding(.top, geo.safeAreaInsets.top + layout.scaled(10))
            
            // Menu
            MainMenuSidebar(
                layout: layout,
                geo: geo,
                themeBlue: themeBlue,
                themeWhite: themeWhite,
                themeDark: themeDark,
                hoveredButton: $hoveredButton,
                onPlay: { destination = .playChapterOne },
                onSelect: { destination = .chapterSelect },
                onLab: { destination = .featureTesting },
                onSettings: {
                    withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        showSettingsPopup = true
                    }
                },
                onAbout: {
                    withAnimation(settings.reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        showCreditsPopup = true
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.scaled(20))
            
            if settings.showVersionLabel {
                Text("Ver 1.0.0")
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(AccessibleColors.versionLabel)
                    .accessibilityLabel("Version 1.0.0")
            }
            
            Spacer()
        }
        .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(10))
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

// MARK: - Sidebar Component
private struct MainMenuSidebar: View {
    let layout: ResponsiveLayout
    let geo: GeometryProxy
    let themeBlue: Color
    let themeWhite: Color
    let themeDark: Color
    @Binding var hoveredButton: String?
    
    let onPlay: () -> Void
    let onSelect: () -> Void
    let onLab: () -> Void
    let onSettings: () -> Void
    let onAbout: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.scaled(15)) {
            Text("SYSTEM MENU")
                .font(.system(size: layout.scaled(20), weight: .heavy, design: .rounded))
                .foregroundColor(themeDark)
                .tracking(1.5)
                .padding(.leading, layout.scaled(10))
                .padding(.bottom, layout.scaled(5))
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: layout.scaled(16)) {
                    // Main Actions
                    SlantedMenuButton(
                        title: "START MISSION",
                        subtitle: "BEGIN VIRTUAL SIMULATION",
                        number: "01",
                        icon: "play.fill",
                        isHovered: hoveredButton == "play",
                        layout: layout,
                        themeBlue: themeBlue,
                        themeWhite: themeWhite,
                        themeDark: themeDark,
                        onHover: { hovering in hoveredButton = hovering ? "play" : nil },
                        action: onPlay
                    )
                    
                    SlantedMenuButton(
                        title: "ARCHIVE",
                        subtitle: "CHAPTER SELECT",
                        number: "02",
                        icon: "square.grid.2x2.fill",
                        isHovered: hoveredButton == "select",
                        layout: layout,
                        themeBlue: themeBlue,
                        themeWhite: themeWhite,
                        themeDark: themeDark,
                        onHover: { hovering in hoveredButton = hovering ? "select" : nil },
                        action: onSelect
                    )
                    
                    SlantedMenuButton(
                        title: "LABORATORY",
                        subtitle: "FEATURE TESTING GROUND",
                        number: "03",
                        icon: "testtube.2",
                        isHovered: hoveredButton == "lab",
                        layout: layout,
                        themeBlue: themeBlue,
                        themeWhite: themeWhite,
                        themeDark: themeDark,
                        onHover: { hovering in hoveredButton = hovering ? "lab" : nil },
                        action: onLab
                    )
                    
                    // Spacer for grouping
                    Color.clear.frame(height: layout.scaled(10))
                    
                    // Secondary Actions
                    HStack(spacing: layout.scaled(16)) {
                        SlantedSmallButton(
                            title: "SETTINGS",
                            icon: "gearshape.fill",
                            isHovered: hoveredButton == "settings",
                            layout: layout,
                            themeBlue: themeBlue,
                            themeWhite: themeWhite,
                            themeDark: themeDark,
                            onHover: { hovering in hoveredButton = hovering ? "settings" : nil },
                            action: onSettings
                        )
                        
                        SlantedSmallButton(
                            title: "CREDITS",
                            icon: "info.circle.fill",
                            isHovered: hoveredButton == "about",
                            layout: layout,
                            themeBlue: themeBlue,
                            themeWhite: themeWhite,
                            themeDark: themeDark,
                            onHover: { hovering in hoveredButton = hovering ? "about" : nil },
                            action: onAbout
                        )
                    }
                }
                .padding(.horizontal, layout.scaled(10))
                .padding(.bottom, layout.scaled(15))
            }
        }
    }
}

// MARK: - Slanted Menu Button
private struct SlantedMenuButton: View {
    let title: String
    let subtitle: String
    let number: String
    let icon: String
    let isHovered: Bool
    let layout: ResponsiveLayout
    let themeBlue: Color
    let themeWhite: Color
    let themeDark: Color
    let onHover: (Bool) -> Void
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Number Bar Accent
                ZStack {
                    Rectangle()
                        .fill(isHovered || isPressed ? themeBlue : Color.gray.opacity(0.2))
                    
                    Text(number)
                        .font(.system(size: layout.scaled(12), weight: .black, design: .rounded))
                        .foregroundColor(themeWhite)
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: layout.scaled(24))

                // Content Area
                HStack(spacing: layout.scaled(12)) {
                    Image(systemName: icon)
                        .font(.system(size: layout.scaled(22)))
                        .foregroundColor(isHovered || isPressed ? themeBlue : AccessibleColors.menuIdleIcon)
                        .frame(width: layout.scaled(30))

                    VStack(alignment: .leading, spacing: layout.scaled(2)) {
                        Text(title)
                            .font(.system(size: layout.scaled(16), weight: .black, design: .rounded))
                            .foregroundColor(isHovered || isPressed ? themeDark : AccessibleColors.menuIdleText)
                            .tracking(1)

                        Text(subtitle)
                            .font(.system(size: layout.scaled(10), weight: .bold))
                            .foregroundColor(isHovered || isPressed ? themeBlue.opacity(0.8) : AccessibleColors.menuIdleSubtext)
                            .tracking(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: layout.scaled(14), weight: .bold))
                        .foregroundColor(isHovered || isPressed ? themeBlue : AccessibleColors.menuIdleIcon)
                }
                .padding(.vertical, layout.scaled(16))
                .padding(.horizontal, layout.scaled(16))
                .background(isHovered || isPressed ? themeWhite : themeWhite.opacity(0.7))
            }
            .clipShape(SlantedRect(offset: layout.scaled(12), direction: .backward))
            .overlay(
                SlantedRect(offset: layout.scaled(12), direction: .backward)
                    .stroke(isHovered || isPressed ? themeBlue : Color.clear, lineWidth: layout.scaled(2))
            )
            .shadow(color: isHovered || isPressed ? themeBlue.opacity(0.25) : .black.opacity(0.05), radius: layout.scaled(8), x: 0, y: layout.scaled(4))
            .offset(x: isHovered || isPressed ? layout.scaled(-10) : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isPressed)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Double tap to activate")
        .accessibilityAddTraits(.isButton)
        #if os(macOS)
        .onHover { onHover($0) }
        #endif
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - Slanted Small Action Button
private struct SlantedSmallButton: View {
    let title: String
    let icon: String
    let isHovered: Bool
    let layout: ResponsiveLayout
    let themeBlue: Color
    let themeWhite: Color
    let themeDark: Color
    let onHover: (Bool) -> Void
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.scaled(8)) {
                Image(systemName: icon)
                    .font(.system(size: layout.scaled(14)))
                
                Text(title)
                    .font(.system(size: layout.scaled(12), weight: .black, design: .rounded))
                    .tracking(1)
            }
            .foregroundColor(isHovered || isPressed ? themeBlue : AccessibleColors.menuIdleText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout.scaled(14))
            .background(isHovered || isPressed ? themeWhite : themeWhite.opacity(0.7))
            .clipShape(SlantedRect(offset: layout.scaled(10), direction: .backward))
            .overlay(
                SlantedRect(offset: layout.scaled(10), direction: .backward)
                    .stroke(isHovered || isPressed ? themeBlue : Color.clear, lineWidth: layout.scaled(2))
            )
            .shadow(color: isHovered || isPressed ? themeBlue.opacity(0.2) : .black.opacity(0.05), radius: layout.scaled(6), x: 0, y: layout.scaled(3))
            .offset(y: isHovered || isPressed ? layout.scaled(-4) : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isPressed)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to open \(title.lowercased())")
        .accessibilityAddTraits(.isButton)
        #if os(macOS)
        .onHover { onHover($0) }
        #endif
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

#Preview {
    MainMenuView()
        .environmentObject(GlobalSettingsStore())
        .preferredColorScheme(.dark)
}
