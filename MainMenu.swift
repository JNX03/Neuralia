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
    case selectMenu
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
        case .selectMenu: return "selectMenu"
        }
    }
}

struct MainMenuView: View {
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
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
            .fullScreenCover(item: $destination) { destination in
                switch destination {
                case .featureTesting:
                    FeatureTestingView()
                case .gallery:
                    GalleryView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                case .chapterSelect:
                    NavigationStack {
                        StoryChapterHubView()
                    }
                case .playChapterOne:
                    NavigationStack {
                        if let firstChapter = StoryChapterRepository.all.first {
                            ResponsiveDialogView(nodes: firstChapter.nodes)
                                .navigationBarBackButtonHidden(true)
                        } else {
                            StoryChapterHubView()
                        }
                    }
                case .selectMenu:
                    ChapterSelectView()
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

// MARK: - About View (Credits Page)
struct AboutView: View {
    var body: some View {
        CreditsView()
    }
}

#Preview {
    MainMenuView()
        .preferredColorScheme(.dark)
}


// MARK: - Chapter Data
struct Chapter: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
    let subtitle: String
    let description: String
    let clues: [String]
    let position: CGPoint
    let rotation: Double
    let isLocked: Bool
}

// MARK: - Chapter Select View (Investigation Board Style)
struct ChapterSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChapter: Chapter? = nil
    @State private var showChapterDetail = false
    @State private var hoveredChapter: UUID? = nil
    
    let chapters = [
        Chapter(
            number: 1,
            title: "H~Hi Who are you?",
            subtitle: "The First Encounter",
            description: "A mysterious message appears on your screen. Someone... or something... is trying to reach out.",
            clues: ["Unknown Signal", "First Contact", "Strange Message"],
            position: CGPoint(x: 0.25, y: 0.35),
            rotation: -3,
            isLocked: false
        ),
        Chapter(
            number: 2,
            title: "New Friend?",
            subtitle: "Growing Connection",
            description: "The conversations continue. Bonds form in unexpected ways. But is everything as it seems?",
            clues: ["Daily Chats", "Shared Secrets", "Unexpected Bond"],
            position: CGPoint(x: 0.5, y: 0.55),
            rotation: 2,
            isLocked: false
        ),
        Chapter(
            number: 3,
            title: "99.98%",
            subtitle: "The Revelation",
            description: "The truth emerges. When reality blurs with digital dreams, what remains of our humanity?",
            clues: ["Final Test", "Truth Revealed", "Ultimate Choice"],
            position: CGPoint(x: 0.75, y: 0.40),
            rotation: -2,
            isLocked: false
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Investigation Board Background
                investigationBoardBackground
                
                // String connections between chapters
                stringConnections(in: geometry)
                
                // Chapter pins
                chapterPins(in: geometry)
                
                // Top header
                header
                
                // Back button
                backButton
            }
        }
        .sheet(item: $selectedChapter) { chapter in
            ChapterDetailView(chapter: chapter)
        }
    }
    
    // MARK: - Investigation Board Background
    private var investigationBoardBackground: some View {
        ZStack {
            // Dark cork board texture
            Color(red: 0.15, green: 0.12, blue: 0.10)
                .ignoresSafeArea()
            
            // Cork pattern overlay
            Image(systemName: "circle.grid.cross.fill")
                .resizable()
                .scaledToFill()
                .opacity(0.03)
                .ignoresSafeArea()
            
            // Vignette effect
            RadialGradient(
                colors: [.clear, .black.opacity(0.4)],
                center: .center,
                startRadius: 200,
                endRadius: 800
            )
            .ignoresSafeArea()
            
            // Grid lines like detective board
            GeometryReader { geo in
                ZStack {
                    // Horizontal lines
                    ForEach(0..<5) { i in
                        Path { path in
                            let y = CGFloat(i) * geo.size.height / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
                    
                    // Vertical lines
                    ForEach(0..<5) { i in
                        Path { path in
                            let x = CGFloat(i) * geo.size.width / 4
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        }
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
                }
            }
            
            // Scattered evidence items
            scatteredEvidence
        }
    }
    
    // MARK: - Scattered Evidence
    private var scatteredEvidence: some View {
        GeometryReader { geo in
            ZStack {
                // Photo 1
                evidencePhoto(
                    systemName: "person.crop.rectangle",
                    position: CGPoint(x: geo.size.width * 0.15, y: geo.size.height * 0.75),
                    rotation: -12,
                    size: 70,
                    color: .blue.opacity(0.7)
                )
                
                // Photo 2
                evidencePhoto(
                    systemName: "envelope.fill",
                    position: CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.70),
                    rotation: 8,
                    size: 60,
                    color: .yellow.opacity(0.7)
                )
                
                // Note 1
                evidenceNote(
                    text: "????",
                    position: CGPoint(x: geo.size.width * 0.12, y: geo.size.height * 0.25),
                    rotation: 15,
                    color: .yellow.opacity(0.9)
                )
                
                // Note 2
                evidenceNote(
                    text: "99.98%...",
                    position: CGPoint(x: geo.size.width * 0.88, y: geo.size.height * 0.22),
                    rotation: -8,
                    color: .pink.opacity(0.7)
                )
                
                // Sticky note
                stickyNote(
                    text: "Remember me?",
                    position: CGPoint(x: geo.size.width * 0.20, y: geo.size.height * 0.55),
                    rotation: 5
                )
            }
        }
    }
    
    private func evidencePhoto(systemName: String, position: CGPoint, rotation: Double, size: CGFloat, color: Color) -> some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
            )
            .foregroundColor(color)
            .position(position)
            .rotationEffect(.degrees(rotation))
    }
    
    private func evidenceNote(text: String, position: CGPoint, rotation: Double, color: Color) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 1)
            )
            .position(position)
            .rotationEffect(.degrees(rotation))
    }
    
    private func stickyNote(text: String, position: CGPoint, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.black.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.yellow.opacity(0.8)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
            )
            .position(position)
            .rotationEffect(.degrees(rotation))
    }
    
    // MARK: - String Connections
    private func stringConnections(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let points = chapters.map { chapter in
            CGPoint(x: width * chapter.position.x, y: height * chapter.position.y)
        }
        
        return ZStack {
            // Draw connecting strings
            Path { path in
                guard points.count >= 2 else { return }
                
                // String from chapter 1 to 2
                path.move(to: points[0])
                path.addCurve(
                    to: points[1],
                    control1: CGPoint(x: points[0].x + 50, y: points[0].y + 80),
                    control2: CGPoint(x: points[1].x - 50, y: points[1].y - 80)
                )
                
                // String from chapter 2 to 3
                path.move(to: points[1])
                path.addCurve(
                    to: points[2],
                    control1: CGPoint(x: points[1].x + 50, y: points[1].y + 60),
                    control2: CGPoint(x: points[2].x - 50, y: points[2].y + 40)
                )
                
                // String from chapter 1 to 3 (direct connection)
                path.move(to: points[0])
                path.addCurve(
                    to: points[2],
                    control1: CGPoint(x: points[0].x, y: points[0].y + 150),
                    control2: CGPoint(x: points[2].x, y: points[2].y + 100)
                )
            }
            .stroke(
                Color.red.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
            )
            
            // Connection nodes (small dots at intersections)
            ForEach(points.indices, id: \.self) { i in
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .position(points[i])
                    .shadow(color: .red.opacity(0.4), radius: 4)
            }
        }
    }
    
    // MARK: - Chapter Pins
    private func chapterPins(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        return ForEach(chapters) { chapter in
            ChapterPin(
                chapter: chapter,
                isHovered: hoveredChapter == chapter.id
            )
            .position(
                x: width * chapter.position.x,
                y: height * chapter.position.y
            )
            .rotationEffect(.degrees(chapter.rotation))
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    selectedChapter = chapter
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredChapter = hovering ? chapter.id : nil
                }
            }
            .scaleEffect(hoveredChapter == chapter.id ? 1.08 : 1.0)
            .shadow(
                color: hoveredChapter == chapter.id ? 
                    Color.red.opacity(0.4) : Color.black.opacity(0.3),
                radius: hoveredChapter == chapter.id ? 15 : 8,
                x: 0, y: 5
            )
            .animation(.easeInOut(duration: 0.3), value: hoveredChapter)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                
                Text("CASE FILES")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
            }
            
            Text("INVESTIGATION BOARD")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .tracking(6)
            
            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(width: 200, height: 2)
                .padding(.top, 4)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Back Button
    private var backButton: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("BACK TO MENU")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.top, 20)
                
                Spacer()
            }
            
            Spacer()
        }
    }
}

// MARK: - Chapter Pin Component
struct ChapterPin: View {
    let chapter: Chapter
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Push pin
            Circle()
                .fill(Color.red)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                .overlay(
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(x: -2, y: -2)
                )
            
            // String connecting pin to note
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 1, height: 20)
            
            // The chapter note/card
            VStack(spacing: 8) {
                // Chapter number badge
                ZStack {
                    Circle()
                        .fill(chapter.isLocked ? Color.gray : Color.red)
                        .frame(width: 36, height: 36)
                    
                    if chapter.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(chapter.number)")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: chapter.isLocked ? Color.clear : Color.red.opacity(0.5), radius: 8)
                
                // Chapter title
                Text(chapter.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 110)
                
                // Subtitle
                Text(chapter.subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                // Clue tags
                HStack(spacing: 4) {
                    ForEach(chapter.clues.prefix(2), id: \.self) { clue in
                        Text(clue)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.7))
                            )
                    }
                }
            }
            .padding(12)
            .frame(width: 140)
            .background(
                ZStack {
                    // Paper texture
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.95))
                    
                    // Slight paper grain
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow.opacity(0.05))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: isHovered ? Color.red.opacity(0.3) : Color.black.opacity(0.2),
                radius: isHovered ? 12 : 6,
                x: 0, y: 4
            )
        }
    }
}

// MARK: - Chapter Detail View
struct ChapterDetailView: View {
    let chapter: Chapter
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var selectedStoryChapter: StoryChapter?
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Content
            VStack(spacing: 24) {
                Spacer()
                
                // Chapter badge
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                    
                    Text("\(chapter.number)")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(.white)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                
                // Title
                Text(chapter.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                // Subtitle
                Text(chapter.subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .opacity(showContent ? 1 : 0)
                
                // Description
                Text(chapter.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 15)
                
                // Clues section
                VStack(spacing: 12) {
                    Text("EVIDENCE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(3)
                    
                    HStack(spacing: 12) {
                        ForEach(chapter.clues, id: \.self) { clue in
                            Text(clue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.3))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(.top, 20)
                .opacity(showContent ? 1 : 0)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        selectedStoryChapter = mappedStoryChapter
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                            Text("START CHAPTER")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .disabled(mappedStoryChapter == nil)
                    .opacity(mappedStoryChapter == nil ? 0.5 : 1.0)
                    
                    Button(action: { dismiss() }) {
                        Text("CLOSE")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showContent = true
            }
        }
        .fullScreenCover(item: $selectedStoryChapter) { storyChapter in
            NavigationStack {
                ResponsiveDialogView(nodes: storyChapter.nodes)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    private var mappedStoryChapter: StoryChapter? {
        let index = chapter.number - 1
        guard StoryChapterRepository.all.indices.contains(index) else { return nil }
        return StoryChapterRepository.all[index]
    }
}
