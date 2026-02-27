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
            // Forward slant: /
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width - offset, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        } else {
            // Backward slant: \
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width - offset, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: offset, y: rect.height))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Story Chapter Hub View
@MainActor
struct StoryChapterHubView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progressStore = StoryProgressStore.shared
    private let chapters = StoryChapterRepository.all
    @State private var selectedChapterIndex: Int = 0

    private var selectedChapter: StoryChapter {
        chapters[selectedChapterIndex]
    }

    // MARK: - Visual Novel / Blue Archive Theme Colors
    private let themeBlue = Color(red: 0.12, green: 0.51, blue: 0.88)
    private let themeLight = Color(red: 0.88, green: 0.95, blue: 0.98)
    private let themeDark = Color(red: 0.05, green: 0.15, blue: 0.25)
    private let themeWhite = Color.white

    var body: some View {
        GeometryReader { geo in
            let layout = ResponsiveLayout(
                width: geo.size.width,
                height: geo.size.height,
                safeAreaInsets: geo.safeAreaInsets
            )

            ZStack {
                // 1. Slanted Background Layer
                backgroundLayer(layout: layout, geo: geo)

                // 2. Main Stacks
                if layout.isLandscape {
                    landscapeLayout(layout: layout, geo: geo)
                } else {
                    portraitLayout(layout: layout, geo: geo)
                }

                // 3. Floating Back Button - Positioned absolutely safely
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
        .onAppear {
            SoundManager.shared.playBGM()
        }
    }

    // MARK: - Background
    private func backgroundLayer(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack {
            LinearGradient(
                colors: [themeWhite, themeLight, themeWhite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            SlantedRect(offset: layout.scaled(100), direction: .forward)
                .fill(themeWhite.opacity(0.6))
                .frame(width: geo.size.width * 0.8, height: geo.size.height)
                .offset(x: -geo.size.width * 0.2)
                .ignoresSafeArea()

            SlantedRect(offset: layout.scaled(60), direction: .backward)
                .fill(themeBlue.opacity(0.04))
                .frame(width: geo.size.width * 0.5, height: geo.size.height)
                .offset(x: geo.size.width * 0.4)
                .ignoresSafeArea()
        }
    }

    // MARK: - Layouts
    private func landscapeLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        HStack(spacing: layout.scaled(30)) {
            // Hero Showcare takes remaining area
            heroShowcase(layout: layout, geo: geo)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1)

            // Sidebar takes fixed constrained area
            chapterSidebar(layout: layout, geo: geo)
                .frame(width: min(geo.size.width * 0.35, 400))
                .zIndex(0)
        }
        .padding(.top, geo.safeAreaInsets.top + layout.scaled(65)) // Shifted down for Back button
        .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(30))
        .padding(.leading, layout.scaled(30))
        .padding(.trailing, layout.scaled(20))
    }

    private func portraitLayout(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(spacing: layout.scaled(20)) {
            heroShowcase(layout: layout, geo: geo)
                .frame(height: geo.size.height * 0.45)
                .padding(.top, geo.safeAreaInsets.top + layout.scaled(65))
                .zIndex(1)

            chapterSidebar(layout: layout, geo: geo)
                .frame(maxWidth: .infinity)
                .zIndex(0)
        }
        .padding(.horizontal, layout.scaled(20))
        .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(20))
    }

    // MARK: - Hero Showcase Container
    private func heroShowcase(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        // We use Color.clear layout boundaries to perfectly adopt the proposed size, 
        // preventing overflowing children like scaledToFill images from breaking the layout.
        Color.clear
            .padding(layout.scaled(8)) // Allows stroke and shadows to bleed naturally
            .overlay(
                GeometryReader { heroGeo in
                    ZStack(alignment: .topLeading) {
                        // A. The Cropped Background Image Map
                        Color.clear
                            .overlay(
                                ZStack {
                                    Image(selectedChapter.coverBackgroundImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: heroGeo.size.width, height: heroGeo.size.height)
                                        .clipped()

                                    LinearGradient(
                                        colors: [themeDark.opacity(0.1), themeDark.opacity(0.45)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }
                            )
                            .clipShape(SlantedRect(offset: layout.scaled(35), direction: .forward))
                            .overlay(
                                SlantedRect(offset: layout.scaled(35), direction: .forward)
                                    .stroke(themeWhite, lineWidth: layout.scaled(4))
                            )
                            .shadow(color: themeBlue.opacity(0.2), radius: 10, x: 0, y: layout.scaled(8))

                        // B. Full Character Image
                        // Placed at the bottom right corner of the actual hero bounds
                        Image(selectedChapter.coverCharacterImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: layout.isLandscape ? heroGeo.size.height * 0.85 : heroGeo.size.height * 0.55)
                            .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: layout.scaled(10))
                            .position(
                                x: heroGeo.size.width - (layout.isLandscape ? layout.scaled(100) : layout.scaled(120)),
                                y: heroGeo.size.height - ((layout.isLandscape ? heroGeo.size.height * 0.85 : heroGeo.size.height * 0.55) / 2) + layout.scaled(15)
                            )
                            .allowsHitTesting(false)

                        // C. Bottom-Left Information Panel
                        // We put it inside a bottomLeading-aligned embedded ZStack pointing to the parent size
                        ZStack(alignment: .bottomLeading) {
                            Color.clear
                            chapterInfoPanel(layout: layout)
                        }
                    }
                }
            )
    }

    // MARK: - Info Panel Details
    private func chapterInfoPanel(layout: ResponsiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.scaled(6)) {
            Text("CHAPTER \(selectedChapterIndex + 1)")
                .font(.system(size: layout.scaled(13), weight: .black, design: .rounded))
                .foregroundColor(themeBlue)
                .tracking(2)

            Text(selectedChapter.title)
                .font(.system(size: layout.scaled(26), weight: .heavy, design: .rounded))
                .foregroundColor(themeDark)
                .lineLimit(2)

            Text(selectedChapter.subtitle)
                .font(.system(size: layout.scaled(14), weight: .bold))
                .foregroundColor(.gray)

            Text(selectedChapter.overview)
                .font(.system(size: layout.scaled(12), weight: .medium))
                .foregroundColor(themeDark.opacity(0.75))
                .lineLimit(layout.isLandscape ? 3 : 2)
                .padding(.top, layout.scaled(4))
                .frame(maxWidth: layout.scaled(280), alignment: .leading)

            // Play Button
            NavigationLink {
                StoryChapterPlayerView(initialChapter: selectedChapter)
            } label: {
                HStack(spacing: layout.scaled(8)) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: layout.scaled(18)))
                    Text("START MISSION")
                        .font(.system(size: layout.scaled(15), weight: .black, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(themeWhite)
                .padding(.horizontal, layout.scaled(20))
                .padding(.vertical, layout.scaled(12))
                .background(themeBlue)
                .clipShape(SlantedRect(offset: layout.scaled(8), direction: .forward))
                .shadow(color: themeBlue.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, layout.scaled(8))
        }
        .padding(layout.scaled(24))
        .background(themeWhite.opacity(0.95))
        .clipShape(SlantedRect(offset: layout.scaled(18), direction: .forward))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        .padding(.leading, layout.scaled(15))
        .padding(.bottom, layout.scaled(25))
    }

    // MARK: - Sidebar Menu
    private func chapterSidebar(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            Text("MISSION SELECT")
                .font(.system(size: layout.scaled(20), weight: .heavy, design: .rounded))
                .foregroundColor(themeDark)
                .tracking(1.5)
                .padding(.leading, layout.scaled(25))

            ScrollView(showsIndicators: false) {
                VStack(spacing: layout.scaled(12)) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        chapterMenuRow(
                            chapter: chapter,
                            index: index,
                            isSelected: index == selectedChapterIndex,
                            layout: layout
                        )
                    }
                }
                .padding(.leading, layout.scaled(25))
                .padding(.trailing, layout.scaled(10))
                .padding(.bottom, layout.scaled(40))
                .padding(.top, layout.scaled(10))
            }
        }
    }

    private func chapterMenuRow(chapter: StoryChapter, index: Int, isSelected: Bool, layout: ResponsiveLayout) -> some View {
        let isUnlocked = progressStore.isChapterUnlocked(at: index)
        let isCompleted = progressStore.isChapterCompleted(chapter.id)

        return Button {
            if isUnlocked {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedChapterIndex = index
                }
            }
        } label: {
            HStack(spacing: 0) {
                // Accent Bar (Left side)
                Rectangle()
                    .fill(isSelected ? themeBlue : Color.gray.opacity(0.2))
                    .frame(width: layout.scaled(8))

                // Row Details
                HStack(spacing: layout.scaled(12)) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: layout.scaled(22), weight: .black, design: .rounded))
                        .foregroundColor(isSelected ? themeBlue : AccessibleColors.menuIdleText)

                    VStack(alignment: .leading, spacing: layout.scaled(2)) {
                        Text(chapter.title)
                            .font(.system(size: layout.scaled(15), weight: .bold))
                            .foregroundColor(isSelected ? themeDark : AccessibleColors.menuIdleText)
                            .lineLimit(1)

                        Text(chapter.subtitle)
                            .font(.system(size: layout.scaled(12), weight: .bold))
                            .foregroundColor(isSelected ? themeBlue.opacity(0.85) : AccessibleColors.menuIdleSubtext)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(themeBlue)
                            .font(.system(size: layout.scaled(16)))
                    } else if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray.opacity(0.4))
                            .font(.system(size: layout.scaled(14)))
                    }
                }
                .padding(.vertical, layout.scaled(14))
                .padding(.horizontal, layout.scaled(14))
                .background(isSelected ? themeWhite : themeWhite.opacity(0.7))
            }
            .clipShape(SlantedRect(offset: layout.scaled(12), direction: .backward))
            .overlay(
                SlantedRect(offset: layout.scaled(12), direction: .backward)
                    .stroke(isSelected ? themeBlue : Color.clear, lineWidth: layout.scaled(2))
            )
            .shadow(color: isSelected ? themeBlue.opacity(0.25) : .black.opacity(0.05), radius: layout.scaled(8), x: 0, y: layout.scaled(4))
            .offset(x: isSelected ? layout.scaled(-15) : 0) // Selected row pops out to the left
        }
        .buttonStyle(.plain)
        .opacity(isUnlocked ? 1.0 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(index + 1): \(chapter.title). \(isCompleted ? "Completed." : isUnlocked ? "Available." : "Locked.")")
        .accessibilityHint(isUnlocked ? "Double tap to select this chapter" : "Complete previous chapters to unlock")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            .foregroundColor(themeDark)
            .padding(.horizontal, layout.scaled(16))
            .padding(.vertical, layout.scaled(10))
            .background(themeWhite.opacity(0.95))
            .clipShape(SlantedRect(offset: layout.scaled(8), direction: .forward))
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: layout.scaled(3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go back to main menu")
        .accessibilityHint("Double tap to return to the main menu")
        .accessibilityAddTraits(.isButton)
    }
}
