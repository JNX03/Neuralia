import SwiftUI

@MainActor
struct StoryChapterPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentChapter: StoryChapter
    @State private var showChapterCompleteOverlay = false
    @State private var completionNextChapter: StoryChapter?

    init(initialChapter: StoryChapter) {
        _currentChapter = State(initialValue: initialChapter)
    }

    var body: some View {
        ZStack {
            ResponsiveDialogView(
                nodes: currentChapter.nodes,
                chapterTopBarDropFactor: 0.5,
                onComplete: { handleChapterCompleted() },
                showCompletionOverlay: false
            )
            .id(currentChapter.id)
            .onAppear {
                SoundManager.shared.playBGM()
            }

            if showChapterCompleteOverlay {
                chapterCompleteOverlay
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showChapterCompleteOverlay)
        .navigationBarBackButtonHidden(true)
    }

    private func handleChapterCompleted() {
        guard !showChapterCompleteOverlay else { return }
        StoryProgressStore.shared.markChapterCompleted(currentChapter.id)
        completionNextChapter = nextChapter(after: currentChapter)
        showChapterCompleteOverlay = true
    }

    private func nextChapter(after chapter: StoryChapter) -> StoryChapter? {
        let chapters = StoryChapterRepository.all
        guard let currentIndex = chapters.firstIndex(where: { $0.id == chapter.id }) else { return nil }
        let nextIndex = currentIndex + 1
        guard chapters.indices.contains(nextIndex) else { return nil }
        return chapters[nextIndex]
    }

    private func continueToNextChapter(_ chapter: StoryChapter) {
        showChapterCompleteOverlay = false
        completionNextChapter = nil
        currentChapter = chapter
        SoundManager.shared.playBGM()
    }

    private func chapterNumber(for chapter: StoryChapter) -> Int? {
        if let index = StoryChapterRepository.all.firstIndex(where: { $0.id == chapter.id }) {
            return index + 1
        }

        let digits = chapter.id.filter(\.isNumber)
        return Int(digits)
    }

    private func chapterLabel(for chapter: StoryChapter) -> String {
        if let number = chapterNumber(for: chapter) {
            return "Chapter \(number)"
        }
        return chapter.title
    }

    private var chapterCompleteBadgeText: String {
        "\(chapterLabel(for: currentChapter)) complete"
    }

    private var chapterAccentColor: Color {
        Color(hex: currentChapter.accentHex)
    }

    private var chapterCompletionBackgroundImageName: String {
        if currentChapter.id == "chapter1" {
            return "chapter1ending"
        }
        if currentChapter.id == "chapter2" {
            return "room"
        }
        return currentChapter.coverBackgroundImage
    }

    private var chapterCompleteOverlay: some View {
        GeometryReader { geo in
            let useCompactBottomLayout = geo.size.width < 860

            ZStack {
                Image(chapterCompletionBackgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 12)
                    .saturation(0.65)
                    .overlay(Color.black.opacity(0.45))
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.78),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.84)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        chapterAccentColor.opacity(0.42),
                        chapterAccentColor.opacity(0.12),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: min(max(geo.size.width, geo.size.height) * 0.9, 900)
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Label(chapterCompleteBadgeText, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.42))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(chapterAccentColor.opacity(0.65), lineWidth: 1)
                            )
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top + 16)
                    .padding(.horizontal, 20)

                    Spacer()

                    if useCompactBottomLayout {
                        VStack(alignment: .trailing, spacing: 14) {
                            completionSummaryCard
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Spacer(minLength: 0)
                                completionActionButtons
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                    } else {
                        HStack(alignment: .bottom, spacing: 20) {
                            completionSummaryCard
                                .frame(maxWidth: min(geo.size.width * 0.56, 520), alignment: .leading)

                            Spacer(minLength: 0)

                            completionActionButtons
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var completionSummaryCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(currentChapter.coverCharacterImage)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 118)
                .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(chapterCompleteBadgeText)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .textCase(.none)
                    .fixedSize(horizontal: false, vertical: true)

                Text(currentChapter.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.82))

                Text("You finished this chapter. Exit to the chapter list or continue to the next chapter.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var completionActionButtons: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button(action: {
                showChapterCompleteOverlay = false
                dismiss()
            }) {
                Label("Exit", systemImage: "door.left.hand.open")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if let nextChapter = completionNextChapter {
                Button(action: { continueToNextChapter(nextChapter) }) {
                    HStack(spacing: 8) {
                        Text("Continue \(chapterLabel(for: nextChapter))")
                            .lineLimit(1)
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        chapterAccentColor.opacity(0.95),
                                        chapterAccentColor.opacity(0.78),
                                        Color.white.opacity(0.22)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: chapterAccentColor.opacity(0.35), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
