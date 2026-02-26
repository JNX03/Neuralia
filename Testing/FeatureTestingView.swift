import SwiftUI

// FeatureTestingView uses the shared ResponsiveLayout from ResponsiveLayout.swift

// MARK: - Feature Testing Menu (Blue Archive Light Theme)
struct FeatureTestingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: GlobalSettingsStore
    
    @State private var showAIHallucination = false
    @State private var showImageTraining = false
    @State private var activeStoryChapter: StoryChapter? = nil
    @State private var hoveredCardID: String? = nil
    
    // MARK: - Theme Colors (Premium Blue Archive style)
    private let themeBlue = Color(red: 0.08, green: 0.6, blue: 0.95)
    private let themeLight = Color(red: 0.92, green: 0.96, blue: 0.99)
    private let themeDark = Color(red: 0.05, green: 0.12, blue: 0.22)
    private let themeWhite = Color.white
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = ResponsiveLayout(
                    width: geo.size.width,
                    height: geo.size.height,
                    safeAreaInsets: geo.safeAreaInsets
                )
                
                ZStack {
                    // 1. Premium sky gradient background
                    LinearGradient(
                        colors: [themeWhite, themeLight, Color(red: 0.85, green: 0.92, blue: 0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    // Floating Decor
                    LabFloatingParticles(layout: layout, color: themeBlue)
                    
                    // Decorative slanted shapes (Watermarks)
                    SlantedRect(offset: layout.scaled(120), direction: .forward)
                        .fill(themeWhite.opacity(0.8))
                        .frame(width: geo.size.width * 0.8, height: geo.size.height)
                        .offset(x: -geo.size.width * 0.15)
                        .ignoresSafeArea()
                    
                    SlantedRect(offset: layout.scaled(80), direction: .backward)
                        .fill(themeBlue.opacity(0.04))
                        .frame(width: geo.size.width * 0.6, height: geo.size.height * 1.2)
                        .offset(x: geo.size.width * 0.35, y: -geo.size.height * 0.1)
                        .ignoresSafeArea()
                    
                    // 2. Character on left side
                    HStack(spacing: 0) {
                        Image("teachnew")
                            .resizable()
                            .scaledToFit()
                            .frame(height: geo.size.height * 0.95)
                            .offset(x: -geo.size.width * 0.02, y: geo.size.height * 0.08)
                            .shadow(color: themeBlue.opacity(0.15), radius: 25, x: 5, y: 15)
                        Spacer()
                    }
                    .ignoresSafeArea()
                    
                    // 3. Top bar - Back button (Polished)
                    VStack {
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: layout.scaled(8)) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: layout.scaled(13), weight: .heavy))
                                    Text("Back")
                                        .font(.system(size: layout.scaled(15), weight: .heavy, design: .rounded))
                                        .italic()
                                }
                                .foregroundColor(themeWhite)
                                .padding(.horizontal, layout.scaled(18))
                                .padding(.vertical, layout.scaled(12))
                                .background(themeDark.opacity(0.9))
                                .clipShape(SlantedRect(offset: layout.scaled(10), direction: .forward))
                                .overlay(
                                    SlantedRect(offset: layout.scaled(10), direction: .forward)
                                        .stroke(themeWhite, lineWidth: 2)
                                        .padding(1)
                                )
                                .shadow(color: themeDark.opacity(0.2), radius: 8, x: 0, y: layout.scaled(4))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, geo.safeAreaInsets.top + layout.scaled(15))
                        .padding(.leading, layout.scaled(25))
                        Spacer()
                    }
                    .zIndex(2)
                    
                    // 4. Right Side Card Grid
                    HStack(spacing: 0) {
                        // Character takes left ~40%
                        Color.clear
                            .frame(width: geo.size.width * 0.38)
                        
                        // Card grid takes right ~62%
                        VStack(alignment: .leading, spacing: layout.scaled(10)) {
                            // Header
                            let headerText: String = {
                                switch hoveredCardID {
                                case "0": return "IMAGE LAB"
                                case "1": return "BIAS AUDIT"
                                case "2": return "ZOO HUNT"
                                case "3": return "AI REVIEW"
                                case "4": return "MEME RESCUE"
                                case "5": return "ETHICS QUIZ"
                                default: return "LAB PLAYGROUND"
                                }
                            }()
                            
                            Text(headerText)
                                .font(.system(size: layout.scaled(20), weight: .heavy, design: .rounded))
                                .foregroundColor(themeDark)
                                .tracking(1.5)
                                .padding(.leading, layout.scaled(25))
                                .animation(.default, value: hoveredCardID)
                            
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: layout.scaled(16)) {
                                    labMenuRow(
                                        index: 0,
                                        title: "Image Lab",
                                        subtitle: "KNN Live Draw",
                                        icon: "paintbrush.pointed.fill",
                                        color: Color(red: 0.95, green: 0.60, blue: 0.1),
                                        layout: layout
                                    ) { showImageTraining = true }
                                    
                                    labMenuRow(
                                        index: 1,
                                        title: "Bias Audit",
                                        subtitle: "Chapter 2 Lab",
                                        icon: "chart.bar.doc.horizontal.fill",
                                        color: Color(red: 0.55, green: 0.35, blue: 0.88),
                                        layout: layout
                                    ) { launchInlineActivity(title: "Bias Audit", inlineActivity: .biasDataAudit(chapter2BiasAndBadDataLabMiniGame)) }
                                    
                                    labMenuRow(
                                        index: 2,
                                        title: "Zoo Hunt",
                                        subtitle: "Chapter 2 Quiz",
                                        icon: "pawprint.fill",
                                        color: Color(red: 0.1, green: 0.72, blue: 0.45),
                                        layout: layout
                                    ) { launchInlineActivity(title: "Zoo Hunt", inlineActivity: .lectureQuiz(chapter2ZooMemoryHuntMiniGame)) }
                                    
                                    labMenuRow(
                                        index: 3,
                                        title: "AI Review",
                                        subtitle: "Chapter 2 Mistakes",
                                        icon: "doc.text.magnifyingglass",
                                        color: Color(red: 0.9, green: 0.3, blue: 0.5),
                                        layout: layout
                                    ) { launchInlineActivity(title: "AI Review", inlineActivity: .biasDataAudit(oldChapter2BiasAndBadDataLabMiniGame)) }
                                    
                                    labMenuRow(
                                        index: 4,
                                        title: "Meme Rescue",
                                        subtitle: "Chapter 3 KNN",
                                        icon: "bolt.heart.fill",
                                        color: Color(red: 0.92, green: 0.2, blue: 0.25),
                                        layout: layout
                                    ) { launchInlineActivity(title: "Meme Rescue", inlineActivity: .chapter3KNNRescue(chapter3KNNRescueMiniGame)) }
                                    
                                    labMenuRow(
                                        index: 5,
                                        title: "Ethics Quiz",
                                        subtitle: "Professor New",
                                        icon: "checkmark.shield.fill",
                                        color: Color(red: 0.95, green: 0.55, blue: 0.1),
                                        layout: layout
                                    ) {
                                        let chapters = StoryChapterRepository.all
                                        if !chapters.isEmpty {
                                            activeStoryChapter = chapters[0]
                                        }
                                    }
                                }
                                .padding(.leading, layout.scaled(25))
                                .padding(.trailing, layout.scaled(15))
                                .padding(.bottom, layout.scaled(60))
                                .padding(.top, layout.scaled(8))
                            }
                        }
                        .padding(.trailing, layout.scaled(20))
                        .padding(.top, geo.safeAreaInsets.top + layout.scaled(60))
                    }
                }
            }
            .navigationDestination(isPresented: $showAIHallucination) {
                AIHallucinationView()
            }
            .navigationDestination(isPresented: $showImageTraining) {
                ImageTrainingView()
            }
            .navigationDestination(item: $activeStoryChapter) { chapter in
                StoryChapterPlayerView(initialChapter: chapter)
            }
        }
    }
    
    // MARK: - Premium Blue Archive Lab Menu Row
    private func labMenuRow(
        index: Int,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        layout: ResponsiveLayout,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredCardID == String(index)
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            ZStack {
                // Background drop shadow layer
                SlantedRect(offset: layout.scaled(15), direction: .backward)
                    .fill(isHovered ? color.opacity(0.25) : Color.black.opacity(0.06))
                    .offset(x: isHovered ? layout.scaled(6) : layout.scaled(4), y: isHovered ? layout.scaled(8) : layout.scaled(4))
                
                // Main card surface
                SlantedRect(offset: layout.scaled(15), direction: .backward)
                    .fill(isHovered ? themeWhite : themeWhite.opacity(0.92))
                    
                // Gradient accent bar inside (Left edge)
                HStack(spacing: 0) {
                    SlantedRect(offset: layout.scaled(15), direction: .backward)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: layout.scaled(10))
                        .offset(x: layout.scaled(-2)) // Push slightly left to mask edge safely
                    Spacer()
                }
                .clipShape(SlantedRect(offset: layout.scaled(15), direction: .backward))
                
                // Right side decorative numbers (Watermark)
                HStack {
                    Spacer()
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: layout.scaled(65), weight: .black, design: .rounded))
                        .italic()
                        .foregroundColor(Color(white: 0.94))
                        .offset(x: layout.scaled(15), y: layout.scaled(10))
                }
                .clipShape(SlantedRect(offset: layout.scaled(15), direction: .backward))
                
                // Content
                HStack(spacing: layout.scaled(16)) {
                    // Small index + Icon circle
                    ZStack {
                        Circle()
                            .fill(color.opacity(isHovered ? 1.0 : 0.12))
                            .frame(width: layout.scaled(42), height: layout.scaled(42))
                        Image(systemName: icon)
                            .font(.system(size: layout.scaled(18), weight: .bold))
                            .foregroundColor(isHovered ? .white : color)
                    }
                    .padding(.leading, layout.scaled(28))

                    VStack(alignment: .leading, spacing: layout.scaled(1)) {
                        Text(title.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: layout.scaled(22), weight: .black, design: .rounded))
                            .italic()
                            .foregroundColor(themeDark)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: layout.scaled(13), weight: .bold))
                            .foregroundColor(color)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                    
                    // Arrow button
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 2)
                            .background(Circle().fill(isHovered ? color : Color.clear))
                            .frame(width: layout.scaled(32), height: layout.scaled(32))
                            
                        Image(systemName: "arrow.right")
                            .font(.system(size: layout.scaled(12), weight: .bold))
                            .foregroundColor(isHovered ? .white : color.opacity(0.7))
                    }
                    .padding(.trailing, layout.scaled(28))
                }
                .padding(.vertical, layout.scaled(18))
            }
            .overlay(
                SlantedRect(offset: layout.scaled(15), direction: .backward)
                    .stroke(isHovered ? color.opacity(0.8) : themeWhite, lineWidth: layout.scaled(2))
            )
            .offset(x: isHovered ? layout.scaled(-12) : 0) // dramatic hover pop out
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredCardID = hovering ? String(index) : nil
        }
    }
    
    private func launchInlineActivity(title: String, inlineActivity: DialogInlineActivity) {
        let dummyLine = StoryDialogLine(
            speaker: "System",
            text: "Loading \(title)...",
            emotion: .neutral,
            inlineActivity: inlineActivity
        )
        let chapter = StoryChapter(
            id: UUID().uuidString,
            title: title,
            subtitle: "Lab Minigame",
            accentHex: "4A90E2",
            coverBackgroundImage: "507room",
            coverCharacterImage: "unknow",
            overview: "",
            lines: [dummyLine]
        )
        activeStoryChapter = chapter
    }
}

// MARK: - Lab Floating Particles
private struct LabFloatingParticles: View {
    let layout: ResponsiveLayout
    let color: Color
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "plus" : "circle")
                    .font(.system(size: layout.scaled(Double.random(in: 12...30)), weight: .heavy))
                    .foregroundColor(color.opacity(0.12))
                    .offset(
                        x: animate ? layout.scaled(Double.random(in: -400...400)) : layout.scaled(Double.random(in: -200...200)),
                        y: animate ? layout.scaled(Double.random(in: -500...500)) : layout.scaled(Double.random(in: -300...300))
                    )
                    .rotationEffect(.degrees(animate ? Double.random(in: 180...360) : 0))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: Double.random(in: 25...40)).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// Slanted shape for Blue Archive aesthetic
struct SlantedParallelogram: Shape {
    let slant: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: slant, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width - slant, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct LabMissionMenuButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let layout: ResponsiveLayout
    var width: CGFloat? = nil
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background shadow
                SlantedParallelogram(slant: layout.scaled(15))
                    .fill(Color.black.opacity(0.15))
                    .offset(x: 4, y: 6)
                
                // Main button background
                SlantedParallelogram(slant: layout.scaled(15))
                    .fill(isPressed ? Color(white: 0.95) : Color.white)
                    .overlay(
                        SlantedParallelogram(slant: layout.scaled(15))
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )
                
                // Color accent bar on the left
                SlantedParallelogram(slant: layout.scaled(15))
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: color, location: 0),
                                .init(color: color, location: 0.08),
                                .init(color: .clear, location: 0.081)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: layout.scaled(20), weight: .black, design: .rounded))
                        .italic()
                        .foregroundColor(color)
                    
                    Text(subtitle)
                        .font(.system(size: layout.scaled(11), weight: .bold))
                        .foregroundColor(.black.opacity(0.6))
                        .italic()
                }
                .padding(.leading, layout.scaled(30))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width ?? layout.scaled(420), height: layout.scaled(80))
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Lab Dashboard UI
// Kept for other experimental views in this file (AI hallucination screen, etc.)
struct MeshGradientBackground: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "0d0d1a"),
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .offset(
                        x: animate ? 100 : -50,
                        y: animate ? -80 : 50
                    )
                    .blur(radius: 80)
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.pink.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.35
                        )
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(
                        x: animate ? -80 : 60,
                        y: animate ? 100 : -60
                    )
                    .blur(radius: 60)
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true).delay(2), value: animate)

                Color.black.opacity(0.15)
            }
            .ignoresSafeArea()
            .onAppear { animate = true }
        }
    }
}

struct LabSurfaceBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.11)
            Color.white.opacity(0.015)
        }
        .ignoresSafeArea()
    }
}

struct LabDashboardHeader: View {
    let layout: ResponsiveLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            HStack(alignment: .top, spacing: layout.scaled(12)) {
                ZStack {
                    RoundedRectangle(cornerRadius: layout.scaled(16), style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: layout.scaled(54), height: layout.scaled(54))
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.scaled(16), style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    Image(systemName: "testtube.2")
                        .font(.system(size: layout.scaled(24), weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.88, blue: 0.92))
                }

                VStack(alignment: .leading, spacing: layout.scaled(4)) {
                    Text("Lab")
                        .font(.system(size: layout.scaled(30), weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Interactive experiments, prototypes, and classroom-ready AI demos")
                        .font(.system(size: layout.scaled(13), weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

            }

            HStack(spacing: layout.scaled(10)) {
                LabPill(title: "Labs", value: "2")
                LabPill(title: "Status", value: "Ready")
                LabPill(title: "Focus", value: "AI + UX")
            }
        }
    }
}

struct LabHeroPanel: View {
    let layout: ResponsiveLayout

    var body: some View {
        Group {
            if layout.isLandscape && !layout.isCompact {
                HStack(spacing: layout.scaled(14)) {
                    heroCopy
                    heroImages
                        .frame(maxWidth: layout.scaled(360))
                }
            } else {
                VStack(spacing: layout.scaled(14)) {
                    heroCopy
                    heroImages
                }
            }
        }
        .padding(layout.scaled(16))
        .background(
            RoundedRectangle(cornerRadius: layout.scaled(22), style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: layout.scaled(22), style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: layout.scaled(10)) {
            Text("Pick a lab and start fast")
                .font(.system(size: layout.scaled(20), weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("This page now matches the Select screen style: image-first cards, clear labels, and cleaner navigation. Use the comments in code as AI image prompts when you generate final artwork.")
                .font(.system(size: layout.scaled(12.5), weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.leading)

            Group {
                if layout.isCompact {
                    VStack(alignment: .leading, spacing: layout.scaled(6)) {
                        Label("No gradient", systemImage: "checkmark.circle.fill")
                        Label("No purple", systemImage: "checkmark.circle.fill")
                        Label("More images", systemImage: "photo.on.rectangle.angled")
                    }
                } else {
                    HStack(spacing: layout.scaled(8)) {
                        Label("No gradient", systemImage: "checkmark.circle.fill")
                        Label("No purple", systemImage: "checkmark.circle.fill")
                        Label("More images", systemImage: "photo.on.rectangle.angled")
                    }
                }
            }
            .font(.system(size: layout.scaled(11), weight: .semibold))
            .foregroundColor(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroImages: some View {
        VStack(spacing: layout.scaled(10)) {
            // AI image prompt: "Clean AI lab overview collage with educational demo scenes, dashboard cards, and modern dark UI composition."
            HStack(spacing: layout.scaled(10)) {
                LabHeroImageTile(imageName: "schooltopview", layout: layout)
                LabHeroImageTile(imageName: "cnxaqu", layout: layout)
            }
            LabHeroImageTile(imageName: "507room", layout: layout, height: layout.scaled(100))
        }
    }
}

struct LabHeroImageTile: View {
    let imageName: String
    let layout: ResponsiveLayout
    var height: CGFloat? = nil

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height ?? layout.scaled(88))
            .clipped()
            .overlay(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: layout.scaled(14), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.scaled(14), style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct LabSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))

            Spacer()
        }
    }
}

struct LabPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct LabFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let imageName: String?
    let chips: [String]
    let status: String
    let layout: ResponsiveLayout
    var disabled: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var cornerRadius: CGFloat { layout.scaled(20) }
    private var mediaHeight: CGFloat { layout.scaled(145) }
    
    var body: some View {
        Button(action: action) { cardShell }
        .buttonStyle(.plain)
        .disabled(disabled)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
    
    private var cardShell: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroSection
            detailsSection
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(disabled ? Color.white.opacity(0.08) : accent.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .scaleEffect(isPressed ? 0.985 : 1)
        .shadow(
            color: Color.black.opacity(disabled ? 0.10 : 0.18),
            radius: layout.scaled(8),
            x: 0,
            y: layout.scaled(4)
        )
        .opacity(disabled ? 0.95 : 1)
    }
    
    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            heroBackground
            Color.black.opacity(disabled ? 0.42 : 0.28)
            heroTopOverlay
            heroBottomOverlay
        }
    }
    
    @ViewBuilder
    private var heroBackground: some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: mediaHeight)
                .clipped()
        } else {
            ZStack {
                Color.white.opacity(0.02)
                Image(systemName: "photo")
                    .font(.system(size: layout.scaled(24), weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(height: mediaHeight)
        }
    }
    
    private var heroTopOverlay: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: layout.scaled(8)) {
                HStack(spacing: 8) {
                    statusBadge
                    if disabled {
                        lockedBadge
                    }
                }
            }
            
            Spacer()
            iconBadge
        }
        .padding(layout.scaled(12))
    }
    
    private var statusBadge: some View {
        Text(status)
            .font(.system(size: layout.scaled(10), weight: .bold))
            .foregroundColor(disabled ? .white.opacity(0.78) : accent)
            .padding(.horizontal, layout.scaled(8))
            .padding(.vertical, layout.scaled(5))
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                Capsule()
                    .stroke(disabled ? Color.white.opacity(0.15) : accent.opacity(0.35), lineWidth: 1)
            )
    }
    
    private var lockedBadge: some View {
        Text("LOCKED")
            .font(.system(size: layout.scaled(10), weight: .bold))
            .foregroundColor(.white.opacity(0.75))
            .padding(.horizontal, layout.scaled(8))
            .padding(.vertical, layout.scaled(5))
            .background(Color.black.opacity(0.3), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
    
    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layout.scaled(12), style: .continuous)
                .fill(Color.black.opacity(0.35))
                .frame(width: layout.scaled(38), height: layout.scaled(38))
            Image(systemName: icon)
                .font(.system(size: layout.scaled(16), weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private var heroBottomOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                cornerActionBadge
            }
            .padding(layout.scaled(12))
        }
    }
    
    private var cornerActionBadge: some View {
        Image(systemName: disabled ? "lock.fill" : "arrow.up.right")
            .font(.system(size: layout.scaled(16), weight: .bold))
            .foregroundColor(.white.opacity(0.88))
            .padding(layout.scaled(10))
            .background(Color.black.opacity(0.30), in: Circle())
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: layout.scaled(10)) {
            titleText
            subtitleText
            chipsRow
            footerRow
        }
        .padding(layout.scaled(14))
        .background(detailsBackground)
    }
    
    private var titleText: some View {
        Text(title)
            .font(.system(size: layout.bodyFontSize + 2, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(disabled ? 0.82 : 1))
            .multilineTextAlignment(.leading)
    }
    
    private var subtitleText: some View {
        Text(subtitle)
            .font(.system(size: layout.captionFontSize + 1, weight: .medium))
            .foregroundColor(.white.opacity(disabled ? 0.48 : 0.68))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
    
    private var chipsRow: some View {
        HStack(spacing: layout.scaled(8)) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                chipView(chip)
            }
        }
        .lineLimit(1)
    }
    
    private func chipView(_ chip: String) -> some View {
        Text(chip)
            .font(.system(size: layout.scaled(10), weight: .bold))
            .foregroundColor(.white.opacity(0.88))
            .padding(.horizontal, layout.scaled(8))
            .padding(.vertical, layout.scaled(5))
            .background(Color.white.opacity(0.05), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
    
    private var footerRow: some View {
        HStack {
            Text(disabled ? "Planned feature" : "Open lab")
                .font(.system(size: layout.scaled(11.5), weight: .semibold))
                .foregroundColor(disabled ? .white.opacity(0.55) : accent)
            Spacer()
            Image(systemName: disabled ? "clock" : "chevron.right")
                .font(.system(size: layout.scaled(12), weight: .bold))
                .foregroundColor(disabled ? .white.opacity(0.45) : accent)
        }
    }
    
    private var detailsBackground: some View {
        Color.white.opacity(0.015)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(disabled ? Color.white.opacity(0.05) : accent.opacity(0.20))
                    .frame(height: 1)
            }
    }
}

// MARK: - Back Button
struct BackButton: View {
    let action: () -> Void
    let layout: ResponsiveLayout

    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.scaled(10)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: layout.scaled(14), weight: .bold))

                Text("Back to Main Menu")
                    .font(.system(size: layout.bodyFontSize, weight: .semibold))

                Spacer()

                Image(systemName: "house")
                    .font(.system(size: layout.scaled(13), weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .foregroundColor(.white)
            .padding(.horizontal, layout.scaled(16))
            .padding(.vertical, layout.scaled(14))
            .background(
                RoundedRectangle(cornerRadius: layout.scaled(18), style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.scaled(18), style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/*
 Old gradient-based feature menu components were replaced with a cleaner,
 image-first dashboard to match the Select page visual language.
 */

// MARK: - Visual Novel Dialog View
struct VisualNovelDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechManager = SpeechManager()
    
    // Dialog state
    @State private var currentNode = 0
    @State private var displayedText = ""
    @State private var isTyping = false
    @State private var showChoices = false
    @State private var showTextInput = false
    @State private var userInput = ""
    @State private var currentEmotion: Emotion = .happy
    
    // Character animation
    @State private var charScale: CGFloat = 1.0
    @State private var charOffset: CGFloat = 0
    @State private var charRotation: Double = 0
    @State private var charOpacity: Double = 1.0
    @State private var isPressed = false
    @State private var currentAnimation: CharacterAnimation = .idle
    
    // Haptic feedback
    @State private var impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    let nodes: [(speaker: String, text: String, emotion: Emotion, hasChoices: Bool, hasInput: Bool)] = [
        ("Ploy", "Hello! Welcome to the dialog test! I'm Ploy. Try interacting with me! Tap to bounce, drag to move, long press to wiggle!", .happy, false, false),
        ("Ploy", "How are you feeling today? Choose an option that matches your mood!", .curious, true, false),
        ("Ploy", "I'd love to know your name! Please type it below.", .gentle, false, true),
        ("Ploy", "The dialog system supports different emotions! Watch my expressions and listen to my voice change!", .excited, false, false),
        ("Ploy", "Thanks for testing this feature! I hope you enjoyed our conversation!", .happy, false, false)
    ]
    
    var body: some View {
        GeometryReader { geo in
            visualNovelRoot(geo: geo)
        }
        .onAppear {
            impactFeedback.prepare()
            startTyping()
        }
    }
    
    private func visualNovelRoot(geo: GeometryProxy) -> some View {
        let layout = ResponsiveLayout(
            width: geo.size.width,
            height: geo.size.height,
            safeAreaInsets: geo.safeAreaInsets
        )
        
        return ZStack {
            visualNovelBackground(geo: geo)
            visualNovelForeground(layout: layout, geo: geo)
        }
    }
    
    private func visualNovelBackground(geo: GeometryProxy) -> some View {
        ZStack {
            Image("507room")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private func visualNovelForeground(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        if layout.isLandscape && (layout.isLarge || layout.isExtraLarge) {
            visualNovelLandscapeLayout(layout: layout, geo: geo)
        } else {
            visualNovelPortraitLayout(layout: layout, geo: geo)
        }
    }
    
    private func visualNovelLandscapeLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            characterSection(layout: layout, geo: geo)
                .frame(width: geo.size.width * 0.5)
            
            dialogSection(layout: layout)
                .frame(width: geo.size.width * 0.5)
                .padding(.bottom, layout.padding)
        }
    }
    
    private func visualNovelPortraitLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            characterSection(layout: layout, geo: geo)
            dialogSection(layout: layout)
        }
    }
    
    // MARK: - Character Section
    private func characterSection(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        // Calculate character height based on layout
        let characterHeight: CGFloat = {
            if layout.isLarge || layout.isExtraLarge {
                return layout.isLandscape ? geo.size.height * 0.55 : geo.size.height * 0.4
            }
            return layout.isLandscape ? geo.size.height * 0.5 : geo.size.height * 0.35
        }()
        
        return ZStack(alignment: .bottom) {
            // Character shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: layout.scaled(120), height: layout.scaled(32))
                .blur(radius: layout.scaled(8))
                .offset(y: -layout.scaled(8))
            
            // Character image with all interactions
            Image("unknow")
                .resizable()
                .scaledToFit()
                .frame(height: characterHeight)
                .scaleEffect(charScale * (isPressed ? 0.75 : 0.7))
                .offset(y: charOffset + (isPressed ? layout.scaled(8) : 0))
                .rotationEffect(.degrees(charRotation))
                .opacity(charOpacity)
                .shadow(color: getEmotionColor().opacity(0.3), radius: layout.scaled(16), x: 0, y: layout.scaled(8))
                .onTapGesture {
                    impactFeedback.impactOccurred()
                    triggerAnimation(.bounce)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            charOffset = value.translation.height * 0.4
                        }
                        .onEnded { _ in
                            withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
                                charOffset = 0
                            }
                            if abs(charOffset) > 30 {
                                triggerAnimation(.shake)
                            }
                        }
                )
                .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                    isPressed = pressing
                    if pressing {
                        impactFeedback.impactOccurred()
                        triggerAnimation(.wiggle)
                    }
                }, perform: {})
            
            // Character name & emotion badge
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: layout.elementSpacing / 2) {
                    Text("Ploy")
                        .font(.system(size: layout.bodyFontSize, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(getEmotionColor())
                            .frame(width: layout.scaled(6), height: layout.scaled(6))
                        Text(currentEmotion.rawValue.capitalized)
                            .font(.system(size: layout.captionFontSize, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, layout.scaled(12))
                .padding(.vertical, layout.scaled(8))
                .background(.ultraThinMaterial)
                .cornerRadius(layout.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.trailing, layout.padding)
            .padding(.bottom, layout.scaled(24))
            
            // Speech indicator
            if speechManager.isSpeaking {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<4) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.green)
                                .frame(width: layout.scaled(3), height: CGFloat.random(in: layout.scaled(6)...layout.scaled(16)))
                                .animation(
                                    .easeInOut(duration: 0.25)
                                    .repeatForever()
                                    .delay(Double(i) * 0.05),
                                    value: speechManager.isSpeaking
                                )
                        }
                    }
                    .frame(height: layout.scaled(20))
                    .padding(.horizontal, layout.scaled(10))
                    .padding(.vertical, layout.scaled(6))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .padding(.trailing, layout.padding)
                .padding(.bottom, layout.scaled(80))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Dialog Section
    private func dialogSection(layout: ResponsiveLayout) -> some View {
        VStack(spacing: 16) {
            // Top bar
            HStack {
                BackButtonCompact {
                    speechManager.stop()
                    dismiss()
                }
                
                Spacer()
                
                SpeechToggleButton(speechManager: speechManager)
            }
            .padding(.horizontal, layout.padding)
            
            Spacer()
            
            // Dialog box
            VStack(spacing: 12) {
                // Main text box
                DialogTextBox(
                    speaker: nodes[currentNode].speaker,
                    text: displayedText,
                    isTyping: isTyping,
                    layout: layout,
                    onTap: {
                        if isTyping {
                            skipTyping()
                        } else if !showChoices && !showTextInput {
                            advance()
                        }
                    }
                )
                
                // Choice buttons
                if showChoices {
                    VStack(spacing: layout.elementSpacing) {
                        ChoiceButtonEnhanced(
                            text: "I'm feeling great! 😊",
                            color: .green,
                            layout: layout,
                            action: { selectChoice("great", emotion: .happy) }
                        )
                        ChoiceButtonEnhanced(
                            text: "Just okay 🤔",
                            color: .yellow,
                            layout: layout,
                            action: { selectChoice("okay", emotion: .neutral) }
                        )
                        ChoiceButtonEnhanced(
                            text: "Not so good 😔",
                            color: .blue,
                            layout: layout,
                            action: { selectChoice("not good", emotion: .sad) }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Text input
                if showTextInput {
                    EnhancedTextInput(
                        text: $userInput,
                        layout: layout,
                        onSubmit: submitInput,
                        isEnabled: !userInput.isEmpty
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, layout.padding)
            .padding(.bottom, max(20, layout.padding - 10))
        }
    }
    
    // MARK: - Helper Methods
    private func getEmotionColor() -> Color {
        switch currentEmotion {
        case .happy: return .yellow
        case .excited: return .orange
        case .sad, .concerned: return .blue
        case .angry: return .red
        case .mysterious: return .purple
        case .surprised: return .pink
        case .gentle, .curious: return .mint
        case .neutral: return .cyan
        }
    }
    
    private func triggerAnimation(_ animation: CharacterAnimation) {
        currentAnimation = animation
        
        switch animation {
        case .bounce:
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                charScale = 1.2
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                    charScale = 1.0
                }
            }
            
        case .shake:
            withAnimation(.easeInOut(duration: 0.04).repeatCount(8, autoreverses: true)) {
                charRotation = 8
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                charRotation = 0
            }
            
        case .pulse:
            withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
                charScale = 1.08
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                charScale = 1.0
            }
            
        case .wiggle:
            withAnimation(.easeInOut(duration: 0.06).repeatCount(12, autoreverses: true)) {
                charRotation = -12
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 750_000_000)
                withAnimation { charRotation = 0 }
            }
            
        case .hop:
            withAnimation(.easeOut(duration: 0.25)) {
                charOffset = -50
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
                    charOffset = 0
                }
            }
            
        case .nod:
            withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
                charRotation = 5
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                charRotation = 0
            }
            
        case .idle:
            break
        }
    }
    
    private func startTyping() {
        let node = nodes[currentNode]
        displayedText = ""
        isTyping = true
        showChoices = false
        showTextInput = false
        currentEmotion = node.emotion
        
        speechManager.speak(node.text, emotion: node.emotion)
        
        let chars = Array(node.text)
        Task { @MainActor in
            for i in 0..<chars.count {
                displayedText.append(chars[i])
                let delay = ",.;!?".contains(chars[i]) ? 120_000_000 : 25_000_000
                try? await Task.sleep(nanoseconds: UInt64(delay))
            }
            isTyping = false
            showChoices = node.hasChoices
            showTextInput = node.hasInput
        }
    }
    
    private func skipTyping() {
        displayedText = nodes[currentNode].text
        isTyping = false
        showChoices = nodes[currentNode].hasChoices
        showTextInput = nodes[currentNode].hasInput
    }
    
    private func advance() {
        if currentNode < nodes.count - 1 {
            currentNode += 1
            startTyping()
        } else {
            dismiss()
        }
    }
    
    private func selectChoice(_ choice: String, emotion: Emotion) {
        showChoices = false
        currentEmotion = emotion
        let response = emotion == .happy ? "That's wonderful to hear!" :
                      emotion == .sad ? "I'm here for you." :
                      "I understand."
        speechManager.speak(response, emotion: emotion)
        triggerAnimation(emotion == .happy ? .bounce : emotion == .sad ? .nod : .pulse)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            advance()
        }
    }
    
    private func submitInput() {
        guard !userInput.isEmpty else { return }
        showTextInput = false
        speechManager.speak("Nice to meet you, \(userInput)!", emotion: .gentle)
        triggerAnimation(.bounce)
        userInput = ""
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            advance()
        }
    }
}

// MARK: - Dialog Text Box
struct DialogTextBox: View {
    let speaker: String
    let text: String
    let isTyping: Bool
    let layout: ResponsiveLayout
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack {
                Text(speaker)
                    .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, layout.scaled(12))
                    .padding(.vertical, layout.scaled(6))
                    .background(
                        Capsule()
                            .fill(Color.pink)
                    )
                
                Spacer()
                
                if isTyping {
                    EnhancedTypingIndicator(layout: layout)
                }
            }
            
            Text(text)
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white)
                .lineSpacing(layout.scaled(4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.1), value: text)
        }
        .padding(layout.padding)
        .background(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Enhanced Choice Button
struct ChoiceButtonEnhanced: View {
    let text: String
    let color: Color
    let layout: ResponsiveLayout
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: layout.bodyFontSize, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(color)
            }
            .padding(layout.padding)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - Enhanced Text Input
struct EnhancedTextInput: View {
    @Binding var text: String
    let layout: ResponsiveLayout
    let onSubmit: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: layout.elementSpacing) {
            TextField("Your name...", text: $text)
                .font(.system(size: layout.bodyFontSize))
                .padding(.horizontal, layout.padding)
                .padding(.vertical, layout.scaled(10))
                .background(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.cornerRadius)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .foregroundColor(.white)
                .accentColor(.pink)
                .submitLabel(.send)
                .onSubmit(onSubmit)
            
            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: layout.scaled(40)))
                    .foregroundColor(isEnabled ? .pink : .gray)
                    .scaleEffect(isEnabled ? 1.0 : 0.9)
            }
            .disabled(!isEnabled)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
        }
    }
}

// MARK: - Back Button Compact
struct BackButtonCompact: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Speech Toggle Button
struct SpeechToggleButton: View {
    @ObservedObject var speechManager: SpeechManager
    
    var body: some View {
        Button(action: { speechManager.toggle() }) {
            Image(systemName: speechManager.speechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 16))
                .foregroundColor(speechManager.speechEnabled ? .green : .gray)
                .padding(10)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Enhanced Typing Indicator
struct EnhancedTypingIndicator: View {
    let layout: ResponsiveLayout
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: layout.elementSpacing / 2) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: layout.scaled(6), height: layout.scaled(6))
                    .offset(y: offset)
                    .animation(
                        .easeInOut(duration: 0.35)
                        .repeatForever()
                        .delay(Double(i) * 0.12),
                        value: offset
                    )
            }
        }
        .onAppear { offset = -layout.scaled(4) }
    }
}

// MARK: - Press Events Modifier
struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Bounce Modifier (iOS 16 compatible)
struct BounceModifier: ViewModifier {
    @State private var isBouncing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isBouncing = true
                }
            }
    }
}

// MARK: - AI Hallucination View
struct AIHallucinationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechManager = SpeechManager()
    
    // Game State
    @State private var currentRoundIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var showTrainingData = false
    @State private var score = 0
    @State private var showScoreSummary = false
    @State private var displayedText = ""
    @State private var isTyping = false
    @State private var characterEmotion: Emotion = .curious
    
    // Character animation
    @State private var charScale: CGFloat = 1.0
    @State private var charOffset: CGFloat = 0
    @State private var charRotation: Double = 0
    @State private var showGlitch = false
    
    // Rounds data
    private let rounds = HallucinationRound.samples
    
    var currentRound: HallucinationRound {
        rounds[currentRoundIndex]
    }
    
    var body: some View {
        GeometryReader { geo in
            aiHallucinationRoot(geo: geo)
        }
        .onAppear {
            startRound()
        }
    }
    
    private func aiHallucinationRoot(geo: GeometryProxy) -> some View {
        let layout = ResponsiveLayout(
            width: geo.size.width,
            height: geo.size.height,
            safeAreaInsets: geo.safeAreaInsets
        )
        
        return ZStack {
            MeshGradientBackground()
            aiHallucinationMainContent(layout: layout, geo: geo)
            aiHallucinationOverlays(layout: layout)
        }
    }
    
    @ViewBuilder
    private func aiHallucinationMainContent(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        if layout.isLandscape && (layout.isLarge || layout.isExtraLarge) {
            aiHallucinationLandscapeLayout(layout: layout, geo: geo)
        } else {
            aiHallucinationPortraitLayout(layout: layout, geo: geo)
        }
    }
    
    private func aiHallucinationLandscapeLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            leftPanel(layout: layout, geo: geo)
                .frame(width: geo.size.width * 0.5)
            
            rightPanel(layout: layout)
                .frame(width: geo.size.width * 0.5)
        }
    }
    
    private func aiHallucinationPortraitLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar(layout: layout)
            
            ScrollView {
                VStack(spacing: layout.sectionSpacing) {
                    imageSection(layout: layout, geo: geo)
                    characterDialogSection(layout: layout)
                    Spacer(minLength: layout.sectionSpacing)
                }
                .padding(.horizontal, layout.padding)
            }
        }
    }
    
    @ViewBuilder
    private func aiHallucinationOverlays(layout: ResponsiveLayout) -> some View {
        if showResult {
            resultOverlay(layout: layout)
        }
        
        if showTrainingData {
            trainingDataOverlay(layout: layout)
        }
        
        if showScoreSummary {
            scoreSummaryOverlay(layout: layout)
        }
    }
    
    // MARK: - Left Panel (iPad)
    private func leftPanel(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar(layout: layout)
                .padding(.horizontal, layout.padding)
                .padding(.top, geo.safeAreaInsets.top + 10)
            
            ScrollView {
                VStack(spacing: layout.sectionSpacing) {
                    imageSection(layout: layout, geo: geo)
                    characterSection(layout: layout, geo: geo)
                    Spacer(minLength: layout.sectionSpacing)
                }
                .padding(.horizontal, layout.padding)
            }
        }
    }
    
    // MARK: - Right Panel (iPad)
    private func rightPanel(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.sectionSpacing) {
            Spacer()
            
            // Dialog box with AI message
            dialogBox(layout: layout)
            
            // Answer choices
            if !showResult && !showTrainingData {
                choicesSection(layout: layout)
            }
            
            Spacer()
        }
        .padding(.horizontal, layout.padding)
        .padding(.bottom, layout.padding)
    }
    
    // MARK: - Top Bar
    private func topBar(layout: ResponsiveLayout) -> some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: layout.bodyFontSize, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Score badge
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("\(score)/\(rounds.count)")
                    .font(.system(size: layout.bodyFontSize, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    )
            )
            
            // Round indicator
            Text("\(currentRoundIndex + 1)/\(rounds.count)")
                .font(.system(size: layout.captionFontSize))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
        }
    }
    
    // MARK: - Image Section
    private func imageSection(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack {
            // Image frame
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
            
            // The image
            Image(currentRound.imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius - 4))
                .padding(4)
                .overlay(
                    // Glitch effect when AI is "hallucinating"
                    Group {
                        if showGlitch {
                            GlitchOverlay()
                                .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
                        }
                    }
                )
            
            // AI Analysis label
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                        Text("AI Vision Analysis")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Capsule()
                                    .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .padding(8)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .frame(
            height: layout.isLandscape ? geo.size.height * 0.4 : geo.size.height * 0.3
        )
    }
    
    // MARK: - Character Section
    private func characterSection(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            // Character shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: layout.scaled(100), height: layout.scaled(25))
                .blur(radius: layout.scaled(8))
                .offset(y: -layout.scaled(8))
            
            // Character
            Image("char")
                .resizable()
                .scaledToFit()
                .frame(height: layout.isLandscape ? geo.size.height * 0.3 : geo.size.height * 0.2)
                .scaleEffect(charScale)
                .offset(y: charOffset)
                .rotationEffect(.degrees(charRotation))
                .shadow(
                    color: getEmotionColor(characterEmotion).opacity(0.3),
                    radius: layout.scaled(16),
                    x: 0,
                    y: layout.scaled(8)
                )
                .overlay(
                    // Glitch effect on character when confused
                    Group {
                        if characterEmotion == .surprised {
                            GlitchOverlay()
                        }
                    }
                )
            
            // Character badge
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ploy")
                        .font(.system(size: layout.captionFontSize + 2, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(getEmotionColor(characterEmotion))
                            .frame(width: 6, height: 6)
                        Text(characterEmotion.rawValue.capitalized)
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Character Dialog Section
    private func characterDialogSection(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.elementSpacing) {
            // Dialog box
            dialogBox(layout: layout)
            
            // Answer choices
            if !showResult && !showTrainingData {
                choicesSection(layout: layout)
            }
        }
    }
    
    // MARK: - Dialog Box
    private func dialogBox(layout: ResponsiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Ploy (AI)")
                        .font(.system(size: layout.captionFontSize, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.3))
                        .overlay(
                            Capsule()
                                .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                if isTyping {
                    EnhancedTypingIndicator(layout: layout)
                }
            }
            
            // AI message
            Text(displayedText)
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white)
                .lineSpacing(layout.scaled(4))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(layout.padding)
        .background(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Choices Section
    private func choicesSection(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.elementSpacing) {
            Text("What is the correct identification?")
                .font(.system(size: layout.bodyFontSize, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(currentRound.allOptions, id: \.self) { option in
                ChoiceButtonEnhanced(
                    text: option,
                    color: selectedAnswer == option ? .purple : .cyan,
                    layout: layout,
                    action: { selectAnswer(option) }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(
                            selectedAnswer == option ? Color.purple : Color.clear,
                            lineWidth: 2
                        )
                )
            }
        }
    }
    
    // MARK: - Result Overlay
    private func resultOverlay(layout: ResponsiveLayout) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: layout.sectionSpacing) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: layout.scaled(64)))
                    .foregroundColor(isCorrect ? .green : .red)
                
                Text(isCorrect ? "Correct!" : "Oops! AI was Confused")
                    .font(.system(size: layout.headlineFontSize, weight: .bold))
                    .foregroundColor(.white)
                
                Text(isCorrect 
                    ? "You identified the object correctly!"
                    : "The AI incorrectly identified this as '\(currentRound.hallucinatedAnswer)'")
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Correct Answer:")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    Text(currentRound.correctAnswer)
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(layout.padding)
                .background(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.cornerRadius)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                
                if !isCorrect {
                    Button(action: { 
                        withAnimation(.spring()) {
                            showTrainingData = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("View Training Data")
                        }
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(layout.cornerRadius)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { nextRound() }) {
                    Text(currentRoundIndex < rounds.count - 1 ? "Next Round →" : "See Results")
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            .padding(layout.padding * 1.5)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, layout.padding)
            .frame(maxWidth: 500)
        }
    }
    
    // MARK: - Training Data Overlay
    private func trainingDataOverlay(layout: ResponsiveLayout) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        showTrainingData = false
                    }
                }
            
            VStack(spacing: layout.sectionSpacing) {
                // Header
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: layout.scaled(32)))
                        .foregroundColor(.cyan)
                    
                    Text("AI Training Data Analysis")
                        .font(.system(size: layout.headlineFontSize, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Training data visualization
                VStack(alignment: .leading, spacing: layout.elementSpacing) {
                    Text("Why did the AI make this mistake?")
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(currentRound.trainingDataHint)
                        .font(.system(size: layout.bodyFontSize - 1))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                
                // Data visualization bars
                VStack(spacing: layout.elementSpacing) {
                    Text("Training Data Distribution")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Visual bars
                    dataBar(label: "Related Category A", percentage: 0.45, color: .pink, layout: layout)
                    dataBar(label: "Related Category B", percentage: 0.30, color: .purple, layout: layout)
                    dataBar(label: "Correct Category", percentage: 0.25, color: .green, layout: layout)
                }
                
                // Explanation
                VStack(alignment: .leading, spacing: 8) {
                    Label("The AI confused '\(currentRound.correctAnswer)' with '\(currentRound.hallucinatedAnswer)'", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: layout.captionFontSize + 1))
                        .foregroundColor(.yellow)
                    
                    Text("This is a classic example of AI hallucination where insufficient training data for the correct category leads to misclassification into a more common but incorrect category.")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                }
                .padding(layout.padding)
                .background(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.cornerRadius)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button(action: { 
                    withAnimation(.spring()) {
                        showTrainingData = false
                    }
                }) {
                    Text("Close Analysis")
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .cornerRadius(layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            .padding(layout.padding * 1.5)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(hex: "1a1a2e"))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, layout.padding)
            .frame(maxWidth: 500)
        }
    }
    
    // MARK: - Data Bar
    private func dataBar(label: String, percentage: Double, color: Color, layout: ResponsiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * percentage, height: 8)
                        .animation(.easeInOut(duration: 0.8), value: percentage)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Score Summary Overlay
    private func scoreSummaryOverlay(layout: ResponsiveLayout) -> some View {
        ZStack {
            MeshGradientBackground()
            
            VStack(spacing: layout.sectionSpacing) {
                Spacer()
                
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: layout.scaled(80)))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Training Complete!")
                    .font(.system(size: layout.headlineFontSize + 4, weight: .bold))
                    .foregroundColor(.white)
                
                Text("You've helped identify AI hallucination patterns")
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundColor(.white.opacity(0.7))
                
                // Score display
                ZStack {
                    Circle()
                        .stroke(
                            Color.purple.opacity(0.3),
                            lineWidth: 8
                        )
                        .frame(width: layout.scaled(150), height: layout.scaled(150))
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / CGFloat(rounds.count))
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: layout.scaled(150), height: layout.scaled(150))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: score)
                    
                    VStack {
                        Text("\(score)/\(rounds.count)")
                            .font(.system(size: layout.scaled(36), weight: .bold))
                            .foregroundColor(.white)
                        Text("Correct")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Feedback based on score
                Text(scoreFeedback)
                    .font(.system(size: layout.bodyFontSize, weight: .medium))
                    .foregroundColor(feedbackColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: layout.elementSpacing) {
                    Button(action: { 
                        resetGame()
                    }) {
                        Text("Train Again")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(layout.cornerRadius)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { dismiss() }) {
                        Text("Back to Menu")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(layout.cornerRadius)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, layout.padding)
            }
            .padding(.vertical, layout.padding)
        }
    }
    
    // MARK: - Helper Properties
    private var scoreFeedback: String {
        let percentage = Double(score) / Double(rounds.count)
        switch percentage {
        case 1.0: return "Perfect! You're an expert at spotting AI hallucinations! 🎉"
        case 0.8..<1.0: return "Great job! You have a keen eye for detail! ⭐"
        case 0.6..<0.8: return "Good work! Keep practicing to spot more errors! 👍"
        default: return "Keep training! AI hallucinations can be tricky! 💪"
        }
    }
    
    private var feedbackColor: Color {
        let percentage = Double(score) / Double(rounds.count)
        switch percentage {
        case 1.0: return .green
        case 0.8..<1.0: return .mint
        case 0.6..<0.8: return .yellow
        default: return .orange
        }
    }
    
    // MARK: - Helper Methods
    private func startRound() {
        selectedAnswer = nil
        showResult = false
        showTrainingData = false
        characterEmotion = .curious
        showGlitch = true
        
        // Type out AI's hallucinated statement
        let text = "Hmm, I'm analyzing this image... I believe this is a \(currentRound.hallucinatedAnswer)! What do you think?"
        typeText(text, emotion: .curious)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3).repeatCount(3)) {
                showGlitch = false
            }
        }
    }
    
    private func typeText(_ text: String, emotion: Emotion) {
        displayedText = ""
        isTyping = true
        characterEmotion = emotion
        
        speechManager.speak(text, emotion: emotion)
        
        let chars = Array(text)
        Task { @MainActor in
            for i in 0..<chars.count {
                displayedText.append(chars[i])
                let delay: UInt64 = ",.;!?".contains(chars[i]) ? 120_000_000 : 25_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
            isTyping = false
        }
    }
    
    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        isCorrect = (answer == currentRound.correctAnswer)
        
        if isCorrect {
            score += 1
            characterEmotion = .happy
            triggerBounce()
        } else {
            characterEmotion = .surprised
            triggerGlitch()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) {
                showResult = true
            }
        }
    }
    
    private func nextRound() {
        withAnimation(.spring()) {
            showResult = false
            showTrainingData = false
        }
        
        if currentRoundIndex < rounds.count - 1 {
            currentRoundIndex += 1
            startRound()
        } else {
            showScoreSummary = true
        }
    }
    
    private func resetGame() {
        currentRoundIndex = 0
        score = 0
        showScoreSummary = false
        startRound()
    }
    
    private func triggerBounce() {
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
            charScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                charScale = 1.0
            }
        }
    }
    
    private func triggerGlitch() {
        withAnimation(.easeInOut(duration: 0.05).repeatCount(10, autoreverses: true)) {
            charRotation = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            charRotation = 0
        }
    }
    
    private func getEmotionColor(_ emotion: Emotion) -> Color {
        switch emotion {
        case .happy: return .green
        case .excited: return .orange
        case .sad, .concerned: return .blue
        case .angry: return .red
        case .mysterious: return .purple
        case .surprised: return .pink
        case .gentle, .curious: return .mint
        case .neutral: return .cyan
        }
    }
}

// MARK: - Glitch Overlay Effect
struct GlitchOverlay: View {
    @State private var phase = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: false)) { _ in
            Canvas { context, size in
                // Random glitch lines
                for _ in 0..<5 {
                    let y = CGFloat.random(in: 0...size.height)
                    let height = CGFloat.random(in: 2...8)
                    let offset = CGFloat.random(in: -20...20)
                    
                    let rect = Path(
                        CGRect(x: 0, y: y, width: size.width, height: height)
                    )
                    
                    // RGB shift effect
                    context.addFilter(.colorMultiply(.red.opacity(0.3)))
                    context.fill(rect, with: .color(.red.opacity(0.3)))
                    
                    context.translateBy(x: offset, y: 0)
                    context.addFilter(.colorMultiply(.cyan.opacity(0.3)))
                    context.fill(rect, with: .color(.cyan.opacity(0.3)))
                }
            }
        }
        .opacity(0.5)
        .allowsHitTesting(false)
    }
}
