import SwiftUI

struct StoryChapterHubView: View {
    @Environment(\.dismiss) private var dismiss
    private let chapters = StoryChapterRepository.all

    var body: some View {
        GeometryReader { geo in
            let layout = ResponsiveLayout(
                width: geo.size.width,
                height: geo.size.height,
                safeAreaInsets: geo.safeAreaInsets
            )

            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.11)
                    .ignoresSafeArea()

                VStack(spacing: layout.sectionSpacing) {
                    header(layout: layout, geo: geo)

                    ScrollView(layout.isLandscape ? .horizontal : .vertical, showsIndicators: false) {
                        if layout.isLandscape {
                            HStack(spacing: layout.elementSpacing) {
                                ForEach(chapters) { chapter in
                                    chapterCard(chapter: chapter, layout: layout)
                                        .frame(width: min(max(geo.size.width * 0.42, 320), 520))
                                }
                            }
                            .padding(.horizontal, layout.padding)
                            .padding(.bottom, layout.padding)
                        } else {
                            VStack(spacing: layout.elementSpacing) {
                                ForEach(chapters) { chapter in
                                    chapterCard(chapter: chapter, layout: layout)
                                }
                            }
                            .padding(.horizontal, layout.padding)
                            .padding(.bottom, layout.padding)
                        }
                    }

                    Button(action: { dismiss() }) {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: layout.scaled(16), weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, layout.scaled(18))
                            .padding(.vertical, layout.scaled(12))
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, layout.padding)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func header(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: layout.scaled(10)) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: layout.scaled(4)) {
                    Text("Story Chapters")
                        .font(.system(size: layout.scaled(30), weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Data-driven dialog / cutscene / character / event scripts")
                        .font(.system(size: layout.scaled(13), weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
                Spacer()
                if layout.isLandscape {
                    Text("Landscape")
                        .font(.system(size: layout.scaled(11), weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }

            HStack(spacing: layout.scaled(10)) {
                statPill(title: "Chapters", value: "\(chapters.count)")
                statPill(title: "Events", value: "\(chapters.reduce(0) { $0 + $1.eventCount })")
                statPill(title: "Mode", value: "Playable")
            }
        }
        .padding(.horizontal, layout.padding)
        .padding(.top, geo.safeAreaInsets.top + layout.scaled(12))
        .padding(.bottom, layout.scaled(8))
    }

    private func statPill(title: String, value: String) -> some View {
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
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func chapterCard(chapter: StoryChapter, layout: ResponsiveLayout) -> some View {
        NavigationLink {
            ResponsiveDialogView(nodes: chapter.nodes)
                .navigationBarBackButtonHidden(true)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image(chapter.coverBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.isLandscape ? layout.scaled(250) : layout.scaled(220))
                    .clipped()
                    .overlay(Color.black.opacity(0.18))

                HStack(alignment: .bottom, spacing: layout.scaled(12)) {
                    Image(chapter.coverCharacterImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: layout.scaled(110), height: layout.scaled(150))
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)

                    VStack(alignment: .leading, spacing: layout.scaled(6)) {
                        Text(chapter.title)
                            .font(.system(size: layout.scaled(20), weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)

                        Text(chapter.subtitle)
                            .font(.system(size: layout.scaled(12), weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)

                        Text(chapter.overview)
                            .font(.system(size: layout.scaled(12)))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            chip("\(chapter.lines.count) scenes")
                            chip("\(chapter.eventCount) event")
                        }
                    }
                }
                .padding(layout.scaled(16))
                .background(
                    RoundedRectangle(cornerRadius: layout.scaled(18), style: .continuous)
                        .fill(Color.black.opacity(0.62))
                )
                .padding(layout.scaled(10))

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: layout.scaled(28)))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    Spacer()
                }
                .padding(layout.scaled(14))
            }
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: layout.scaled(24), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.scaled(24), style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}
