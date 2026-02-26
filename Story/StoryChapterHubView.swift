import SwiftUI

// MARK: - Slanted Shape Direction
enum SlantDirection {
    case forward
    case backward
}

// MARK: - Slanted Rectangle Shape
struct SlantedRect: Shape {
    var offset: CGFloat = 20
    var direction: SlantDirection = .forward

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if direction == .forward {
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width - offset, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width - offset, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: offset, y: rect.height))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Hub Activity Destination
private enum HubActivityDestination: Identifiable {
    case story(StoryChapter)
    case chapterPlayer(StoryChapter)

    var id: String {
        switch self {
        case .story(let ch): return "story-\(ch.id)"
        case .chapterPlayer(let ch): return "player-\(ch.id)"
        }
    }
}

// MARK: - Activity Card Model
private struct ActivityCard: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let backgroundImage: String?
    let accentColor: Color
    let chapterIndex: Int
    let isLarge: Bool
}

// MARK: - Story Chapter Hub View
@MainActor
struct StoryChapterHubView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progressStore = StoryProgressStore.shared
    private let chapters = StoryChapterRepository.all
    @State private var selectedChapterIndex: Int = 0
    @State private var activeDestination: HubActivityDestination? = nil
    @State private var hoveredCardID: String? = nil

    private var selectedChapter: StoryChapter {
        chapters[selectedChapterIndex]
    }

    // MARK: - Theme Colors
    private let themeBlue = Color(red: 0.12, green: 0.51, blue: 0.88)
    private let themeLight = Color(red: 0.88, green: 0.95, blue: 0.98)
    private let themeDark = Color(red: 0.05, green: 0.15, blue: 0.25)
    private let themeWhite = Color.white
    private let themePurple = Color(red: 0.55, green: 0.36, blue: 0.96)
    private let themeOrange = Color(red: 0.98, green: 0.45, blue: 0.09)
    private let themeTeal = Color(red: 0.18, green: 0.72, blue: 0.68)
    private let themePink = Color(red: 1.0, green: 0.36, blue: 0.57)
    private let themeGold = Color(red: 0.85, green: 0.65, blue: 0.13)

    // MARK: - Activity Cards Data
    private var activityCards: [ActivityCard] {
        [
            ActivityCard(
                id: "story",
                title: "Story",
                subtitle: "Play Chapter \(selectedChapterIndex + 1)",
                icon: "book.pages.fill",
                backgroundImage: selectedChapter.coverBackgroundImage,
                accentColor: themeBlue,
                chapterIndex: selectedChapterIndex,
                isLarge: true
            ),
            ActivityCard(
                id: "mission",
                title: "Mission",
                subtitle: selectedChapter.title,
                icon: "flag.fill",
                backgroundImage: nil,
                accentColor: themePurple,
                chapterIndex: selectedChapterIndex,
                isLarge: true
            ),
            ActivityCard(
                id: "ethics_quiz",
                title: "Ethics\nQuiz",
                subtitle: "Chapter 1",
                icon: "checkmark.shield.fill",
                backgroundImage: "schooltopview",
                accentColor: themePink,
                chapterIndex: 0,
                isLarge: false
            ),
            ActivityCard(
                id: "prompt_lab",
                title: "Prompt\nLab",
                subtitle: "Chapter 1",
                icon: "text.bubble.fill",
                backgroundImage: "redbus",
                accentColor: themeOrange,
                chapterIndex: 0,
                isLarge: false
            ),
            ActivityCard(
                id: "zoo_memory",
                title: "Zoo\nMemory",
                subtitle: "Chapter 2",
                icon: "pawprint.fill",
                backgroundImage: "cnxgate",
                accentColor: themeTeal,
                chapterIndex: 1,
                isLarge: false
            ),
            ActivityCard(
                id: "data_lab",
                title: "Data\nLab",
                subtitle: "Chapter 2",
                icon: "chart.bar.doc.horizontal.fill",
                backgroundImage: "cnxaqu",
                accentColor: themePurple,
                chapterIndex: 1,
                isLarge: false
            ),
            ActivityCard(
                id: "knn_rescue",
                title: "KNN\nRescue",
                subtitle: "Chapter 3",
                icon: "bolt.heart.fill",
                backgroundImage: "507room",
                accentColor: themeOrange,
                chapterIndex: 2,
                isLarge: false
            ),
            ActivityCard(
                id: "about",
                title: "About",
                subtitle: "Info",
                icon: "star.fill",
                backgroundImage: nil,
                accentColor: themeGold,
                chapterIndex: 0,
                isLarge: false
            )
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let layout = ResponsiveLayout(
                width: geo.size.width,
                height: geo.size.height,
                safeAreaInsets: geo.safeAreaInsets
            )

            ZStack {
                backgroundLayer(layout: layout, geo: geo)

                if layout.isLandscape {
                    landscapeLayout(layout: layout, geo: geo)
                } else {
                    portraitLayout(layout: layout, geo: geo)
                }

                // Back Button
                VStack {
                    HStack {
                        backButton(layout: layout)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, geo.safeAreaInsets.top + layout.scaled(15))
                .padding(.leading, layout.scaled(25))
                .zIndex(2)
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: $activeDestination) { dest in
            NavigationStack {
                switch dest {
                case .story(let ch):
                    StoryChapterPlayerView(initialChapter: ch)
                case .chapterPlayer(let ch):
                    StoryChapterPlayerView(initialChapter: ch)
                }
            }
        }
    }

    // MARK: - Background
    private func backgroundLayer(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack {
            // Blue Archive ocean gradient
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.72, blue: 0.92),
                    Color(red: 0.30, green: 0.58, blue: 0.85),
                    Color(red: 0.20, green: 0.45, blue: 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Image(selectedChapter.coverBackgroundImage)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .opacity(0.25)
                .ignoresSafeArea()

            // Top and bottom vignette
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.15), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.25)
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.2)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.25)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Layouts
    private func landscapeLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left: Character
            characterDisplay(layout: layout, geo: geo)
                .frame(width: geo.size.width * 0.38)
                .zIndex(1)

            // Right: Activity Grid
            activityGrid(layout: layout, geo: geo)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)
        }
        .padding(.top, geo.safeAreaInsets.top + layout.scaled(50))
        .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(10))
    }

    private func portraitLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            characterDisplay(layout: layout, geo: geo)
                .frame(height: geo.size.height * 0.35)
                .padding(.top, geo.safeAreaInsets.top + layout.scaled(50))

            activityGrid(layout: layout, geo: geo)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(10))
        }
    }

    // MARK: - Character Display (Left Side)
    private func characterDisplay(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        GeometryReader { charGeo in
            ZStack(alignment: .bottom) {
                Image(selectedChapter.coverCharacterImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: charGeo.size.height * 0.88)
                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 5, y: 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, layout.scaled(10))

                // Chapter selector pills at top
                VStack {
                    chapterPills(layout: layout)
                    Spacer()
                }
                .padding(.top, layout.scaled(5))
            }
        }
    }

    // MARK: - Chapter Pills
    private func chapterPills(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.scaled(8)) {
            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, _ in
                let isSelected = index == selectedChapterIndex
                let isUnlocked = progressStore.isChapterUnlocked(at: index)

                Button {
                    if isUnlocked {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedChapterIndex = index
                        }
                    }
                } label: {
                    HStack(spacing: layout.scaled(4)) {
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: layout.scaled(9)))
                        }
                        Text("CH.\(index + 1)")
                            .font(.system(size: layout.scaled(11), weight: .black, design: .rounded))
                            .tracking(0.5)
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .padding(.horizontal, layout.scaled(12))
                    .padding(.vertical, layout.scaled(6))
                    .background(
                        isSelected
                        ? themeBlue
                        : Color.white.opacity(0.15)
                    )
                    .clipShape(Capsule())
                    .shadow(color: isSelected ? themeBlue.opacity(0.5) : .clear, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .opacity(isUnlocked ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - Activity Grid (Right Side)
    private func activityGrid(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        let cards = activityCards
        let largeCards = cards.filter { $0.isLarge }
        let smallCards = cards.filter { !$0.isLarge }

        return ScrollView(showsIndicators: false) {
            VStack(spacing: layout.scaled(10)) {
                // Top Row: Two large cards
                HStack(spacing: layout.scaled(10)) {
                    ForEach(largeCards) { card in
                        activityCardView(card: card, layout: layout, isLargeCard: true)
                    }
                }
                .frame(height: layout.scaled(120))

                // Bottom Rows: 3-column grid
                let columns = 3
                let rows = (smallCards.count + columns - 1) / columns
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: layout.scaled(10)) {
                        ForEach(0..<columns, id: \.self) { col in
                            let idx = row * columns + col
                            if idx < smallCards.count {
                                activityCardView(card: smallCards[idx], layout: layout, isLargeCard: false)
                            } else {
                                Color.clear
                            }
                        }
                    }
                    .frame(height: layout.scaled(110))
                }
            }
            .padding(.horizontal, layout.scaled(16))
            .padding(.vertical, layout.scaled(12))
        }
    }

    // MARK: - Individual Activity Card
    private func activityCardView(card: ActivityCard, layout: ResponsiveLayout, isLargeCard: Bool) -> some View {
        let isUnlocked = progressStore.isChapterUnlocked(at: card.chapterIndex)
        let isHovered = hoveredCardID == card.id

        return Button {
            if isUnlocked {
                handleCardTap(card)
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Card Background
                ZStack {
                    if let bgImage = card.backgroundImage {
                        Image(bgImage)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.4)
                    }

                    // Glassmorphism gradient
                    LinearGradient(
                        colors: [
                            card.accentColor.opacity(0.4),
                            card.accentColor.opacity(0.15),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Color.white.opacity(isHovered ? 0.3 : 0.15)
                }
                .clipShape(RoundedRectangle(cornerRadius: layout.scaled(14)))

                // Content
                VStack(alignment: .leading, spacing: layout.scaled(4)) {
                    Spacer()

                    Image(systemName: card.icon)
                        .font(.system(size: layout.scaled(isLargeCard ? 22 : 18)))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                    Text(card.title)
                        .font(.system(size: layout.scaled(isLargeCard ? 22 : 16), weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                    if isLargeCard {
                        Text(card.subtitle)
                            .font(.system(size: layout.scaled(12), weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(layout.scaled(14))

                // Lock overlay
                if !isUnlocked {
                    ZStack {
                        RoundedRectangle(cornerRadius: layout.scaled(14))
                            .fill(Color.black.opacity(0.5))

                        VStack(spacing: layout.scaled(6)) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: layout.scaled(20)))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Locked")
                                .font(.system(size: layout.scaled(12), weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                // Completed badge
                if isUnlocked && card.id == "story" && progressStore.isChapterCompleted(selectedChapter.id) {
                    VStack {
                        HStack {
                            Spacer()
                            Text("✓ Clear")
                                .font(.system(size: layout.scaled(10), weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, layout.scaled(8))
                                .padding(.vertical, layout.scaled(4))
                                .background(Color.green.opacity(0.8))
                                .clipShape(Capsule())
                                .padding(layout.scaled(8))
                        }
                        Spacer()
                    }
                }

                // "In Progress" badge for mission card
                if card.id == "mission" {
                    VStack {
                        HStack {
                            Spacer()
                            Text("In Progress")
                                .font(.system(size: layout.scaled(9), weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, layout.scaled(8))
                                .padding(.vertical, layout.scaled(3))
                                .background(Color.red.opacity(0.85))
                                .clipShape(Capsule())
                                .padding(layout.scaled(8))
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: layout.scaled(14)))
            .overlay(
                RoundedRectangle(cornerRadius: layout.scaled(14))
                    .stroke(Color.white.opacity(0.3), lineWidth: layout.scaled(1))
            )
            .shadow(color: card.accentColor.opacity(0.3), radius: layout.scaled(8), x: 0, y: layout.scaled(4))
            .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(isUnlocked ? 1.0 : 0.7)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredCardID = hovering ? card.id : nil
            }
        }
    }

    // MARK: - Card Tap Handler
    private func handleCardTap(_ card: ActivityCard) {
        switch card.id {
        case "story":
            activeDestination = .story(selectedChapter)
        case "mission":
            // Cycle to next chapter
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedChapterIndex = (selectedChapterIndex + 1) % chapters.count
            }
        case "ethics_quiz", "prompt_lab":
            activeDestination = .chapterPlayer(chapters[0])
        case "zoo_memory", "data_lab":
            activeDestination = .chapterPlayer(chapters[1])
        case "knn_rescue":
            activeDestination = .chapterPlayer(chapters[2])
        case "about":
            // Dismiss back to main menu (About is accessible from there)
            dismiss()
        default:
            break
        }
    }

    // MARK: - Back Button
    private func backButton(layout: ResponsiveLayout) -> some View {
        Button(action: { dismiss() }) {
            HStack(spacing: layout.scaled(6)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: layout.scaled(12), weight: .bold))
                Text("Back")
                    .font(.system(size: layout.scaled(14), weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, layout.scaled(16))
            .padding(.vertical, layout.scaled(10))
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: layout.scaled(3))
        }
        .buttonStyle(.plain)
    }
}
