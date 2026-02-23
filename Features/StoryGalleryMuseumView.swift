import SwiftUI

@MainActor
struct StoryGalleryMuseumView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = StoryProgressStore.shared

    @State private var currentChapterIndex = 0
    @State private var selectedImageIndex = 0
    @State private var chapterSlideDirection = 1
    @State private var previewSlideDirection = 1

    @State private var celebration: MuseumCelebration?
    @State private var celebrationTask: Task<Void, Never>?
    @State private var lastObservedChapterID: String?
    @State private var lastObservedUnlockState = true
    @State private var lastObservedCompletedState = false
    @State private var showcasedChapters: Set<String> = []

    @State private var lockPulse = false

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
        .onAppear {
            startAmbientAnimationsIfNeeded()
            refreshCurrentChapterObservation(triggerAnimation: false)
        }
        .onDisappear {
            celebrationTask?.cancel()
        }
        .onChange(of: currentChapterIndex) { _, _ in
            selectedImageIndex = 0
            refreshCurrentChapterObservation(triggerAnimation: true)
        }
        .onChange(of: progress.completedChapterIDs) { _, _ in
            refreshCurrentChapterObservation(triggerAnimation: true)
        }
    }

    private func museumLayout(in geo: GeometryProxy) -> some View {
        let isCompact = geo.size.width < 880
        let horizontalPadding = isCompact ? 16.0 : 28.0
        let verticalPadding = isCompact ? 12.0 : 18.0
        let contentHeight = min(max(geo.size.height * 0.62, 300), isCompact ? 420 : 520)
        let thumbWidth = min(max(geo.size.width * (isCompact ? 0.18 : 0.12), 92), isCompact ? 126 : 160)
        let navButtonSize = isCompact ? 52.0 : 62.0

        let chapter = chapters[clampedChapterIndex]
        let chapterImages = displayImages(for: chapter)
        let displayedImageName = chapterImages[clampedImageIndex(in: chapterImages)]
        let isUnlocked = progress.isChapterUnlocked(at: clampedChapterIndex, in: chapters)
        let isCompleted = progress.isChapterCompleted(chapter.id)
        let archiveDate = progress.completionDate(for: chapter.id)

        let previewIdentity = "\(chapter.id)-\(clampedImageIndex(in: chapterImages))-\(isUnlocked ? 1 : 0)-\(isCompleted ? 1 : 0)"
        let headerIdentity = "\(chapter.id)-\(isUnlocked ? 1 : 0)-\(isCompleted ? 1 : 0)"

        return ZStack {
            museumBackground

            VStack(spacing: 0) {
                topBar(
                    topInset: geo.safeAreaInsets.top,
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding
                )

                ZStack {
                    chapterHeader(
                        chapter: chapter,
                        isCompact: isCompact,
                        isUnlocked: isUnlocked,
                        isCompleted: isCompleted
                    )
                    .id(headerIdentity)
                    .transition(slideTransition(direction: chapterSlideDirection))
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, isCompact ? 4 : 8)
                .animation(.spring(response: 0.42, dampingFraction: 0.9), value: headerIdentity)

                Spacer(minLength: 8)

                HStack(alignment: .center, spacing: isCompact ? 10 : 16) {
                    chapterNavButton(direction: .previous, size: navButtonSize)

                    ZStack {
                        mainPreviewPanel(
                            chapter: chapter,
                            imageName: displayedImageName,
                            isUnlocked: isUnlocked,
                            isCompleted: isCompleted,
                            archiveDate: archiveDate,
                            height: contentHeight
                        )
                        .id(previewIdentity)
                        .transition(slideTransition(direction: previewSlideDirection))
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.9), value: previewIdentity)

                    ZStack {
                        thumbnailColumn(
                            chapterImages: chapterImages,
                            width: thumbWidth,
                            height: contentHeight,
                            isUnlocked: isUnlocked
                        )
                        .id("thumbs-\(chapter.id)-\(isUnlocked ? 1 : 0)")
                        .transition(slideTransition(direction: chapterSlideDirection))
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: chapter.id)

                    chapterNavButton(direction: .next, size: navButtonSize)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 10)

                bottomBar(
                    chapter: chapter,
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
                        .stroke(.white.opacity(0.14), lineWidth: 1.5)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Text("Memory museum")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 12)

            progressPill
        }
        .padding(.top, topInset + verticalPadding)
        .padding(.horizontal, horizontalPadding)
    }

    private var progressPill: some View {
        let completed = progress.completedCount(in: chapters)
        let total = max(chapters.count, 1)

        return HStack(spacing: 8) {
            Text("Chapter")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
            Text("\(clampedChapterIndex + 1)/\(chapters.count)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 14)

            Text("\(completed)/\(total) archived")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.82), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func chapterHeader(
        chapter: StoryChapter,
        isCompact: Bool,
        isUnlocked: Bool,
        isCompleted: Bool
    ) -> some View {
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
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)

            Text(isCompleted ? "Archived" : (isUnlocked ? "Unlocked" : "Locked"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isCompleted ? Color.green.opacity(0.85) : .white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
    }

    private func mainPreviewPanel(
        chapter: StoryChapter,
        imageName: String,
        isUnlocked: Bool,
        isCompleted: Bool,
        archiveDate: Date?,
        height: CGFloat
    ) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let imageHeight = max(180, height * 0.78)

        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.45))
                    .overlay(Color.black.opacity(isUnlocked ? 0.05 : 0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 8) {
                    Text("Memory \(clampedImageIndex(in: displayImages(for: chapter)) + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.55), in: Capsule())

                    Text(isCompleted ? "Archived" : (isUnlocked ? "Unlocked" : "Locked"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.45), in: Capsule())
                }
                .padding(12)

                if !isUnlocked {
                    lockOverlay(for: chapter, memoryCount: galleryMemoryCount(for: chapter))
                }

                if let celebration, celebration.chapterID == chapter.id {
                    celebrationOverlay(celebration)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .zIndex(5)
                }
            }
            .frame(height: imageHeight)

            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(chapter.overview)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)

                Text(previewFooterLine(isUnlocked: isUnlocked, isCompleted: isCompleted, archiveDate: archiveDate))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.black.opacity(0.82), in: cardShape)
        .overlay(
            cardShape
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
    }

    private func lockOverlay(for chapter: StoryChapter, memoryCount: Int) -> some View {
        let previousNumber = max(clampedChapterIndex, 0)

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.36))

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 54, height: 54)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(lockPulse ? 1.04 : 0.97)

                Text("Locked Gallery")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text("Finish Chapter \(previousNumber) to unlock this archive.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)

                Text("\(memoryCount) memories inside")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
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
        let currentSelected = clampedImageIndex(in: chapterImages)

        return VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let hasImage = index < chapterImages.count
                let imageName = hasImage ? chapterImages[index] : placeholderImageName
                let isSelected = isUnlocked && index == currentSelected && hasImage

                Button {
                    guard isUnlocked, hasImage else { return }
                    previewSlideDirection = index >= currentSelected ? 1 : -1
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                        selectedImageIndex = index
                    }
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
                    .scaleEffect(isSelected ? 1.03 : 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? .white.opacity(0.45) : .white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
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
                    .stroke(.white.opacity(0.12), lineWidth: 1.5)

                Image(systemName: direction == .next ? "chevron.right" : "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.86 : 0.35))
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
            .opacity(isEnabled ? 1 : 0.75)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func bottomBar(
        chapter: StoryChapter,
        isUnlocked: Bool,
        isCompleted: Bool,
        isCompact: Bool,
        horizontalPadding: CGFloat,
        bottomInset: CGFloat
    ) -> some View {
        archiveMetaBlock(chapter: chapter, isUnlocked: isUnlocked, isCompleted: isCompleted, isCompact: isCompact)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, max(bottomInset, 12))
    }

    private func bottomStatusRow(chapter: StoryChapter, isUnlocked: Bool, isCompleted: Bool) -> some View {
        let memoryCount = galleryMemoryCount(for: chapter)
        let rarity = chapterRarityLabel(for: clampedChapterIndex)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.84))
                    Image(systemName: isCompleted ? "trophy.fill" : (isUnlocked ? "target" : "lock.fill"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isCompleted ? Color.orange.opacity(0.92) : (isUnlocked ? Color.red.opacity(0.88) : .white.opacity(0.78)))
                }
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(isCompleted ? "Archive achieved" : (isUnlocked ? "Archive ready to claim" : "Next archive locked"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(bottomStatusDescription(chapter: chapter, isUnlocked: isUnlocked, isCompleted: isCompleted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                museumInfoPill(title: rarity, icon: "sparkles", tint: rarityTint(for: clampedChapterIndex))
                museumInfoPill(title: "\(memoryCount) memories", icon: "photo.stack.fill")
                museumInfoPill(title: "+120 XP", icon: "bolt.fill", tint: Color.orange.opacity(0.95))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func collectionDrivePanel(isCompact: Bool) -> some View {
        let completed = progress.completedCount(in: chapters)
        let total = max(chapters.count, 1)
        let ratio = min(max(CGFloat(completed) / CGFloat(total), 0), 1)
        let perks = museumPerks(completedArchives: completed)
        let totalXP = completed * 120

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Unlock Track")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text(nextUnlockDriveLine(from: perks))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completed)/\(chapters.count) archives")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("\(totalXP) XP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.orange.opacity(0.9))
                }
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.9), Color.orange.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, ratio * (isCompact ? 230 : 420)), height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(perks) { perk in
                        perkCard(perk)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func archiveMetaBlock(
        chapter: StoryChapter,
        isUnlocked: Bool,
        isCompleted: Bool,
        isCompact: Bool
    ) -> some View {
        let memoryCount = galleryMemoryCount(for: chapter)
        let archiveDateText = archiveDateLine(for: chapter, chapterIndex: clampedChapterIndex, isUnlocked: isUnlocked, isCompleted: isCompleted)
        let statusLine = archiveActionHint(isUnlocked: isUnlocked, isCompleted: isCompleted)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            Text(archiveDateText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isCompleted ? Color.green.opacity(0.94) : .white.opacity(0.88))
                .lineLimit(2)

            if isCompact {
                VStack(alignment: .leading, spacing: 8) {
                    archiveShareButton(chapter: chapter, isUnlocked: isUnlocked, isCompleted: isCompleted)
                    HStack(spacing: 8) {
                        museumInfoPill(title: "\(memoryCount) memories", icon: "photo.stack")
                        museumInfoPill(title: isCompleted ? "Done" : (isUnlocked ? "Ready" : "Locked"), icon: isCompleted ? "checkmark" : "lock")
                    }
                }
            } else {
                HStack(spacing: 8) {
                    archiveShareButton(chapter: chapter, isUnlocked: isUnlocked, isCompleted: isCompleted)
                    museumInfoPill(title: "\(memoryCount) memories", icon: "photo.stack")
                    museumInfoPill(title: isCompleted ? "Done" : (isUnlocked ? "Ready" : "Locked"), icon: isCompleted ? "checkmark" : "lock")
                }
            }

            Text(statusLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func archiveShareButton(chapter: StoryChapter, isUnlocked: Bool, isCompleted: Bool) -> some View {
        ShareLink(item: museumShareText(for: chapter, chapterIndex: clampedChapterIndex, isUnlocked: isUnlocked, isCompleted: isCompleted)) {
            museumActionPillLabel(
                title: isCompleted ? "Share Archive" : "Share Goal",
                icon: "square.and.arrow.up",
                isEnabled: isUnlocked,
                tint: .white
            )
        }
        .disabled(!isUnlocked)
    }

    private func museumActionPillLabel(title: String, icon: String, isEnabled: Bool, tint: Color = .white) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(isEnabled ? tint : .white.opacity(0.35))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(isEnabled ? 0.88 : 0.55), in: Capsule())
        .overlay(
            Capsule()
                .stroke(isEnabled ? tint.opacity(0.25) : .white.opacity(0.08), lineWidth: 1)
        )
    }

    private func museumInfoPill(title: String, icon: String, tint: Color = .white) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(tint.opacity(0.92))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.78), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func perkCard(_ perk: MuseumPerkState) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: perk.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(perk.isUnlocked ? perk.tint : .white.opacity(0.45))
                Text(perk.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Text(perk.subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(2)

            Text(perk.isUnlocked ? "Unlocked" : "Unlock at \(perk.requiredArchives) archives")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(perk.isUnlocked ? perk.tint.opacity(0.95) : .white.opacity(0.5))
        }
        .padding(10)
        .frame(width: 190, alignment: .leading)
        .background(Color.black.opacity(perk.isUnlocked ? 0.88 : 0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(perk.isUnlocked ? perk.tint.opacity(0.22) : .white.opacity(0.08), lineWidth: 1)
        )
    }

    private func celebrationOverlay(_ celebration: MuseumCelebration) -> some View {
        VStack(spacing: 6) {
            Image(systemName: celebration.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))

            Text(celebration.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text(celebration.subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(18)
        .allowsHitTesting(false)
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

        chapterSlideDirection = (direction == .next) ? 1 : -1
        previewSlideDirection = chapterSlideDirection

        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            switch direction {
            case .previous:
                currentChapterIndex -= 1
            case .next:
                currentChapterIndex += 1
            }
        }
    }

    private func displayImages(for chapter: StoryChapter) -> [String] {
        let collected = museumGalleryImageNames(for: chapter)
        if collected.isEmpty {
            return [placeholderImageName]
        }
        return collected
    }

    private func galleryMemoryCount(for chapter: StoryChapter) -> Int {
        max(museumGalleryImageNames(for: chapter).count, 1)
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

    private func slideTransition(direction: Int) -> AnyTransition {
        let insertion: Edge = direction >= 0 ? .trailing : .leading
        let removal: Edge = direction >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }

    private func startAmbientAnimationsIfNeeded() {
        guard !lockPulse else { return }

        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            lockPulse = true
        }
    }

    private func refreshCurrentChapterObservation(triggerAnimation: Bool) {
        guard chapters.indices.contains(clampedChapterIndex) else { return }

        let chapter = chapters[clampedChapterIndex]
        let isUnlocked = progress.isChapterUnlocked(at: clampedChapterIndex, in: chapters)
        let isCompleted = progress.isChapterCompleted(chapter.id)

        defer {
            lastObservedChapterID = chapter.id
            lastObservedUnlockState = isUnlocked
            lastObservedCompletedState = isCompleted
        }

        guard triggerAnimation else { return }

        if lastObservedChapterID == chapter.id {
            if !lastObservedUnlockState && isUnlocked {
                triggerCelebration(
                    chapterID: chapter.id,
                    title: "Gallery Unlocked",
                    subtitle: "New memories are ready.",
                    symbol: "lock.open.fill",
                    tint: .white
                )
                showcasedChapters.insert(chapter.id)
            }

            if !lastObservedCompletedState && isCompleted {
                triggerCelebration(
                    chapterID: chapter.id,
                    title: "Archive Stamped",
                    subtitle: "Archive date recorded.",
                    symbol: "checkmark.seal.fill",
                    tint: Color.green.opacity(0.95)
                )
                showcasedChapters.insert(chapter.id)
            }
            return
        }

        guard isUnlocked, !showcasedChapters.contains(chapter.id) else { return }

        triggerCelebration(
            chapterID: chapter.id,
            title: isCompleted ? "Archive Recovered" : "New Target Unlocked",
            subtitle: isCompleted ? "This memory is already archived." : "Finish the chapter to stamp the archive date.",
            symbol: isCompleted ? "trophy.fill" : "sparkles",
            tint: isCompleted ? Color.green.opacity(0.95) : .white
        )
        showcasedChapters.insert(chapter.id)
    }

    private func triggerCelebration(chapterID: String, title: String, subtitle: String, symbol: String, tint: Color) {
        celebrationTask?.cancel()

        let payload = MuseumCelebration(chapterID: chapterID, title: title, subtitle: subtitle, symbol: symbol, tint: tint)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            celebration = payload
        }

        celebrationTask = Task {
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.24)) {
                    celebration = nil
                }
            }
        }
    }

    private var museumMotivationLine: String {
        let completed = progress.completedCount(in: chapters)
        if chapters.isEmpty {
            return "No archives available"
        }
        if completed == chapters.count {
            return "All archives completed. Master seal active."
        }
        if let nextTarget = nextArchiveTarget() {
            let unlocked = progress.isChapterUnlocked(at: nextTarget.index, in: chapters)
            return unlocked
                ? "Next target: Chapter \(nextTarget.index + 1) is ready to archive"
                : "Finish Chapter \(max(nextTarget.index, 1)) to unlock the next archive"
        }
        return "Keep collecting memories"
    }

    private func nextArchiveTarget() -> (index: Int, chapter: StoryChapter)? {
        for (index, chapter) in chapters.enumerated() where !progress.isChapterCompleted(chapter.id) {
            return (index, chapter)
        }
        return nil
    }

    private func chapterRewardTeaser(isUnlocked: Bool, isCompleted: Bool, memoryCount: Int) -> String {
        if isCompleted {
            return "Achievement unlocked: archived with \(memoryCount) memory captures"
        }
        if isUnlocked {
            return "Reward: archive this chapter to stamp a real date and unlock sharing"
        }
        return "Locked reward: \(memoryCount) memories waiting behind this chapter"
    }

    private func bottomStatusDescription(chapter: StoryChapter, isUnlocked: Bool, isCompleted: Bool) -> String {
        if isCompleted {
            return "\(chapter.subtitle) is archived. Share it or keep building the museum track."
        }
        if isUnlocked {
            return "Finish \(chapter.title) to stamp the archive date and push the next unlock."
        }
        return "Clear the previous chapter to unlock this memory room and its reward tier."
    }

    private func chapterRarityLabel(for chapterIndex: Int) -> String {
        switch chapterIndex {
        case 0: return "Rare"
        case 1: return "Epic"
        case 2: return "Legendary"
        default: return (chapterIndex % 2 == 0) ? "Epic" : "Rare"
        }
    }

    private func rarityTint(for chapterIndex: Int) -> Color {
        switch chapterRarityLabel(for: chapterIndex) {
        case "Legendary": return Color.yellow.opacity(0.95)
        case "Epic": return Color.pink.opacity(0.9)
        default: return Color.cyan.opacity(0.9)
        }
    }

    private func museumPerks(completedArchives: Int) -> [MuseumPerkState] {
        let totalRequired = max(chapters.count, 1)

        return [
            MuseumPerkState(
                id: "curator-frame",
                title: "Curator Frame",
                subtitle: "Premium glowing frame activates on unlocked memories.",
                icon: "rectangle.inset.filled",
                requiredArchives: 1,
                isUnlocked: completedArchives >= 1,
                tint: Color.red.opacity(0.95)
            ),
            MuseumPerkState(
                id: "spotlight-sweep",
                title: "Spotlight Sweep",
                subtitle: "Animated highlight sweep makes new memories feel alive.",
                icon: "wand.and.rays",
                requiredArchives: 2,
                isUnlocked: completedArchives >= 2,
                tint: Color.orange.opacity(0.95)
            ),
            MuseumPerkState(
                id: "master-seal",
                title: "Master Seal",
                subtitle: "Complete the museum to unlock the final crown badge.",
                icon: "crown.fill",
                requiredArchives: totalRequired,
                isUnlocked: completedArchives >= totalRequired,
                tint: Color.yellow.opacity(0.95)
            )
        ]
    }

    private func nextUnlockDriveLine(from perks: [MuseumPerkState]) -> String {
        if let nextPerk = perks.first(where: { !$0.isUnlocked }) {
            return "Next unlock: \(nextPerk.title) at \(nextPerk.requiredArchives) archives"
        }
        return "Everything unlocked. Keep sharing your completed archive collection."
    }

    private func archiveDateLine(for chapter: StoryChapter, chapterIndex: Int, isUnlocked: Bool, isCompleted: Bool) -> String {
        if let archiveDate = progress.completionDate(for: chapter.id), isCompleted {
            return "Archived on \(Self.archiveDateFormatter.string(from: archiveDate))"
        }

        if isCompleted {
            return "Archived (legacy save, date unavailable)"
        }

        if isUnlocked {
            if let unlockDate = unlockDateForChapter(at: chapterIndex) {
                return "Unlocked on \(Self.archiveDateLabelFormatter.string(from: unlockDate))"
            }
            return "Archive date pending"
        }

        return "Locked until previous chapter is completed"
    }

    private func unlockDateForChapter(at chapterIndex: Int) -> Date? {
        guard chapterIndex > 0 else { return nil }
        let previousIndex = chapterIndex - 1
        guard chapters.indices.contains(previousIndex) else { return nil }
        return progress.completionDate(for: chapters[previousIndex].id)
    }

    private func archiveActionHint(isUnlocked: Bool, isCompleted: Bool) -> String {
        if isCompleted {
            return "Share this archive."
        }
        if isUnlocked {
            return "Finish the chapter to save the real archive date."
        }
        return "Finish the previous chapter to unlock sharing."
    }

    private func previewFooterLine(isUnlocked: Bool, isCompleted: Bool, archiveDate: Date?) -> String {
        if let archiveDate, isCompleted {
            return "Archived: \(Self.archiveDateFormatter.string(from: archiveDate))"
        }
        if isCompleted {
            return "Archived (date unavailable)"
        }
        if isUnlocked {
            return "Complete chapter to stamp archive date"
        }
        return "Locked until previous chapter is completed"
    }

    private func museumShareText(for chapter: StoryChapter, chapterIndex: Int, isUnlocked: Bool, isCompleted: Bool) -> String {
        let status = isCompleted ? "Archived" : (isUnlocked ? "Unlocked" : "Locked")
        let archiveDateText: String

        if let date = progress.completionDate(for: chapter.id), isCompleted {
            archiveDateText = Self.archiveDateFormatter.string(from: date)
        } else if isCompleted {
            archiveDateText = "Legacy archive (date unavailable)"
        } else {
            archiveDateText = "Not archived yet"
        }

        return """
        Memory Museum - Chapter \(chapterIndex + 1)
        \(chapter.title)
        Status: \(status)
        Archive date: \(archiveDateText)
        \(chapter.subtitle)
        """
    }

    private static let archiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let archiveDateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private enum MuseumNavDirection {
    case previous
    case next
}

private struct MuseumPerkState: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let requiredArchives: Int
    let isUnlocked: Bool
    let tint: Color
}

private struct MuseumCelebration: Identifiable {
    let id = UUID()
    let chapterID: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
}
