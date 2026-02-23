import SwiftUI

@MainActor
struct StoryGalleryMuseumView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = StoryProgressStore.shared

    @State private var currentChapterIndex = 0
    @State private var selectedImageIndex = 0

    private let chapters = StoryChapterRepository.all
    private let placeholderImageName = "placeholder"

    var body: some View {
        GeometryReader { geo in
            if chapters.isEmpty {
                emptyState(in: geo)
            } else {
                museumLayout(in: geo)
            }
        }
        .onChange(of: currentChapterIndex) { _, _ in
            selectedImageIndex = 0
        }
    }

    private func museumLayout(in geo: GeometryProxy) -> some View {
        let isCompact = geo.size.width < 880
        let horizontalPadding = isCompact ? 16.0 : 28.0
        let verticalPadding = isCompact ? 12.0 : 18.0
        let contentHeight = min(max(geo.size.height * 0.52, 250), isCompact ? 330 : 430)
        let thumbWidth = min(max(geo.size.width * (isCompact ? 0.24 : 0.18), 120), isCompact ? 180 : 240)
        let navButtonSize = isCompact ? 52.0 : 62.0

        let chapter = chapters[clampedChapterIndex]
        let chapterImages = displayImages(for: chapter)
        let displayedImageName = chapterImages[clampedImageIndex(in: chapterImages)]
        let isUnlocked = progress.isChapterUnlocked(at: clampedChapterIndex, in: chapters)
        let isCompleted = progress.isChapterCompleted(chapter.id)

        return ZStack {
            museumBackground

            VStack(spacing: 0) {
                topBar(
                    topInset: geo.safeAreaInsets.top,
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding
                )

                chapterHeader(chapter: chapter, isCompact: isCompact)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, isCompact ? 4 : 8)

                Spacer(minLength: 8)

                HStack(alignment: .center, spacing: isCompact ? 10 : 16) {
                    chapterNavButton(direction: .previous, size: navButtonSize)

                    mainPreviewPanel(
                        chapter: chapter,
                        imageName: displayedImageName,
                        isUnlocked: isUnlocked,
                        isCompleted: isCompleted,
                        height: contentHeight
                    )

                    thumbnailColumn(
                        chapterImages: chapterImages,
                        width: thumbWidth,
                        height: contentHeight,
                        isUnlocked: isUnlocked
                    )

                    chapterNavButton(direction: .next, size: navButtonSize)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 10)

                bottomBar(
                    isUnlocked: isUnlocked,
                    isCompleted: isCompleted,
                    isCompact: isCompact,
                    horizontalPadding: horizontalPadding,
                    bottomInset: geo.safeAreaInsets.bottom
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private func emptyState(in geo: GeometryProxy) -> some View {
        ZStack {
            museumBackground

            VStack(spacing: 14) {
                Text("Memory Museum")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("No chapters are available yet.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Button("Back") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.88), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(.white)
            }
            .padding(.top, geo.safeAreaInsets.top)
        }
        .ignoresSafeArea()
    }

    private var museumBackground: some View {
        ZStack {
            Image(placeholderImageName)
                .resizable()
                .scaledToFill()
                .blur(radius: 12)
                .saturation(0.35)
                .overlay(Color.black.opacity(0.72))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Rectangle()
                .fill(Color.black.opacity(0.32))
                .ignoresSafeArea()
        }
    }

    private func topBar(topInset: CGFloat, horizontalPadding: CGFloat, verticalPadding: CGFloat) -> some View {
        HStack(spacing: 14) {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.9))
                    Circle()
                        .stroke(Color.red.opacity(0.9), lineWidth: 2.5)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Text("Memory museum")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 12)

            progressPill
        }
        .padding(.top, topInset + verticalPadding)
        .padding(.horizontal, horizontalPadding)
    }

    private var progressPill: some View {
        HStack(spacing: 8) {
            Text("CHAPTER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            Text("\(clampedChapterIndex + 1)/\(chapters.count)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.82), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func chapterHeader(chapter: StoryChapter, isCompact: Bool) -> some View {
        VStack(spacing: 4) {
            Text("Chapter \(clampedChapterIndex + 1)")
                .font(.system(size: isCompact ? 22 : 28, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(chapter.subtitle)
                .font(.system(size: isCompact ? 16 : 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(chapter.title)
                .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func mainPreviewPanel(
        chapter: StoryChapter,
        imageName: String,
        isUnlocked: Bool,
        isCompleted: Bool,
        height: CGFloat
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.82))

            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .overlay(Color.black.opacity(isUnlocked ? 0.16 : 0.36))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.46)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("MEMORY \(clampedImageIndex(in: displayImages(for: chapter)) + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45), in: Capsule())

                    if isCompleted {
                        Label("Completed", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.55), in: Capsule())
                    } else if !isUnlocked {
                        Label("Locked", systemImage: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.55), in: Capsule())
                    }
                }

                Text(chapter.title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(chapter.overview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
            }
            .padding(14)

            if !isUnlocked {
                lockOverlay(for: chapter)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private func lockOverlay(for chapter: StoryChapter) -> some View {
        let previousNumber = max(clampedChapterIndex, 0)

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.32))

            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("Locked Gallery")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Finish Chapter \(previousNumber) to unlock this archive.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func thumbnailColumn(
        chapterImages: [String],
        width: CGFloat,
        height: CGFloat,
        isUnlocked: Bool
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let hasImage = index < chapterImages.count
                let imageName = hasImage ? chapterImages[index] : placeholderImageName
                let isSelected = isUnlocked && index == clampedImageIndex(in: chapterImages) && hasImage

                Button {
                    guard isUnlocked, hasImage else { return }
                    selectedImageIndex = index
                } label: {
                    ZStack(alignment: .topLeading) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: (height - 20) / 3)
                            .clipped()
                            .overlay(Color.black.opacity(hasImage ? (isUnlocked ? 0.18 : 0.34) : 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Text(hasImage ? "\(index + 1)" : "X")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.46), in: Capsule())
                            .padding(8)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.red.opacity(0.9) : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!isUnlocked || !hasImage)
            }
        }
        .frame(width: width, height: height)
    }

    private func chapterNavButton(direction: MuseumNavDirection, size: CGFloat) -> some View {
        let isEnabled = canNavigate(direction)

        return Button {
            navigate(direction)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(isEnabled ? 0.86 : 0.55))
                Circle()
                    .stroke(direction == .next ? Color.red.opacity(0.9) : .white.opacity(0.08), lineWidth: direction == .next ? 2.5 : 1)

                Image(systemName: direction == .next ? "chevron.right" : "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(direction == .next ? Color.red.opacity(isEnabled ? 0.95 : 0.4) : .white.opacity(isEnabled ? 0.86 : 0.35))
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
            .opacity(isEnabled ? 1 : 0.75)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func bottomBar(
        isUnlocked: Bool,
        isCompleted: Bool,
        isCompact: Bool,
        horizontalPadding: CGFloat,
        bottomInset: CGFloat
    ) -> some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    bottomStatusRow(isUnlocked: isUnlocked, isCompleted: isCompleted)
                    archiveMetaBlock(isUnlocked: isUnlocked)
                }
            } else {
                HStack(alignment: .bottom, spacing: 18) {
                    bottomStatusRow(isUnlocked: isUnlocked, isCompleted: isCompleted)
                    Spacer(minLength: 12)
                    archiveMetaBlock(isUnlocked: isUnlocked)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, max(bottomInset, 12))
    }

    private func bottomStatusRow(isUnlocked: Bool, isCompleted: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.84))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.orange.opacity(0.9))
            }
            .frame(width: 54, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(isCompleted ? "Museum entry archived" : (isUnlocked ? "Museum entry unlocked" : "Museum entry locked"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(isCompleted ? "Completed chapter memories are ready for export." : "Complete the chapter to mark this archive as finished.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }
        }
    }

    private func archiveMetaBlock(isUnlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Archive date [xx/xx/xxxx]")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                museumActionPill(title: "Save", icon: "square.and.arrow.down", isEnabled: isUnlocked)
                museumActionPill(title: "Share", icon: "square.and.arrow.up", isEnabled: isUnlocked)
                museumActionPill(title: "More", icon: "ellipsis", isEnabled: isUnlocked)
            }

            Text("Save to Photos, share, etc.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private func museumActionPill(title: String, icon: String, isEnabled: Bool) -> some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.35))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(isEnabled ? 0.88 : 0.55), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var clampedChapterIndex: Int {
        guard !chapters.isEmpty else { return 0 }
        return min(max(currentChapterIndex, 0), chapters.count - 1)
    }

    private func clampedImageIndex(in images: [String]) -> Int {
        guard !images.isEmpty else { return 0 }
        return min(max(selectedImageIndex, 0), images.count - 1)
    }

    private func canNavigate(_ direction: MuseumNavDirection) -> Bool {
        switch direction {
        case .previous:
            return clampedChapterIndex > 0
        case .next:
            return clampedChapterIndex < chapters.count - 1
        }
    }

    private func navigate(_ direction: MuseumNavDirection) {
        guard canNavigate(direction) else { return }

        switch direction {
        case .previous:
            currentChapterIndex -= 1
        case .next:
            currentChapterIndex += 1
        }
    }

    private func displayImages(for chapter: StoryChapter) -> [String] {
        let collected = museumGalleryImageNames(for: chapter)
        if collected.isEmpty {
            return [placeholderImageName]
        }
        return collected
    }

    private func museumGalleryImageNames(for chapter: StoryChapter) -> [String] {
        var collected: [String] = []

        func append(_ name: String?) {
            guard let name else { return }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard !trimmed.hasPrefix("__") else { return }
            guard !collected.contains(trimmed) else { return }
            collected.append(trimmed)
        }

        append(chapter.coverBackgroundImage)

        for line in chapter.lines {
            append(line.showcaseMedia?.imageName)
        }

        for line in chapter.lines {
            append(line.backgroundImage)
        }

        append(chapter.coverCharacterImage)

        return Array(collected.prefix(3))
    }
}

private enum MuseumNavDirection {
    case previous
    case next
}
