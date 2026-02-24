import SwiftUI

struct MenuCreditsPopupOverlay: View {
    let layout: ResponsiveLayout
    let onClose: () -> Void

    @State private var selectedTab: CreditsPopupTab = .credits
    @State private var currentImageIndex = 0
    @State private var imageOpacity: Double = 1.0
    @State private var timer: Timer? = nil

    private let memoryImages = ["507room", "cnxaqu", "cnxgate", "lantassc", "redbus"]

    private let panelBorder = Color(red: 0.80, green: 0.83, blue: 0.86)
    private let panelBackground = Color(red: 0.95, green: 0.96, blue: 0.97)
    private let sidebarSelected = Color(red: 0.72, green: 0.86, blue: 0.97)
    private let sectionBorder = Color(red: 0.84, green: 0.86, blue: 0.88)
    private let textPrimary = Color(red: 0.17, green: 0.24, blue: 0.33)
    private let textMuted = Color(red: 0.45, green: 0.50, blue: 0.58)
    private let accent = Color(red: 0.32, green: 0.76, blue: 0.98)

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            popupCard
                .padding(.horizontal, layout.padding)
                .padding(.vertical, max(layout.padding, layout.safeAreaInsets.top + layout.scaled(10)))
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            startImageCycle()
        }
        .onDisappear {
            stopImageCycle()
        }
    }

    private var popupCard: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(panelBorder)
            content
        }
        .frame(
            maxWidth: min(layout.width - (layout.padding * 2), layout.isCompact ? 560 : 820),
            maxHeight: min(layout.height * 0.86, layout.isCompact ? 640 : 560)
        )
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: layout.scaled(8), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.scaled(8), style: .continuous)
                .stroke(panelBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 26, x: 0, y: 14)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text("Credits")
                    .font(.system(size: layout.bodyFontSize + 6, weight: .bold))
                    .foregroundStyle(textPrimary)

                Rectangle()
                    .fill(Color(red: 0.95, green: 0.85, blue: 0.25))
                    .frame(width: 86, height: 4)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: layout.bodyFontSize + 2, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .frame(width: layout.scaled(34), height: layout.scaled(34))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, layout.scaled(4))
        }
        .padding(.horizontal, layout.scaled(16))
        .padding(.vertical, layout.scaled(12))
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.75), Color.white.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var content: some View {
        Group {
            if layout.width < 700 || layout.isPortrait {
                VStack(spacing: 0) {
                    sidebar
                    Divider().overlay(panelBorder)
                    contentPane
                }
            } else {
                HStack(spacing: 0) {
                    sidebar
                    Divider().overlay(panelBorder)
                    contentPane
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            ForEach(CreditsPopupTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, layout.scaled(16))
                        .padding(.vertical, layout.scaled(12))
                        .background(selectedTab == tab ? sidebarSelected : Color.clear)
                }
                .buttonStyle(.plain)

                Divider().overlay(panelBorder.opacity(0.8))
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("WWDC SSC 2026")
                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("Neura project credits")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundStyle(textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.scaled(12))
            .padding(.vertical, layout.scaled(10))
        }
        .frame(
            width: layout.width < 700 || layout.isPortrait ? nil : max(138, layout.scaled(160)),
            height: layout.width < 700 || layout.isPortrait ? nil : .infinity
        )
        .background(Color(red: 0.85, green: 0.93, blue: 0.98).opacity(0.85))
    }

    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.scaled(12)) {
                switch selectedTab {
                case .credits:
                    creditsTab
                case .memory:
                    memoryTab
                }
            }
            .padding(layout.scaled(12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.65))
    }

    private var creditsTab: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            infoSection(
                title: "Creator",
                subtitle: "Primary author and designer"
            ) {
                VStack(alignment: .leading, spacing: layout.scaled(8)) {
                    HStack(spacing: 10) {
                        Image("icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: layout.scaled(36), height: layout.scaled(36))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chawabhon Netisingha")
                                .font(.system(size: layout.bodyFontSize, weight: .semibold))
                                .foregroundStyle(textPrimary)
                            Text("Made with love by Jnx03")
                                .font(.system(size: layout.captionFontSize + 1))
                                .foregroundStyle(textMuted)
                        }
                        Spacer(minLength: 0)
                    }

                    creditBadge("WWDC SSC 2026", tint: accent)
                }
            }

            infoSection(
                title: "Contributions",
                subtitle: "Core areas credited in this build"
            ) {
                VStack(spacing: layout.scaled(8)) {
                    CreditRow(icon: "paintbrush.fill", label: "Art", value: "Chawabhon Netisingha", layout: layout, textPrimary: textPrimary, textMuted: textMuted)
                    CreditRow(icon: "music.note", label: "Music", value: "Chawabhon Netisingha", layout: layout, textPrimary: textPrimary, textMuted: textMuted)
                    CreditRow(icon: "book.closed.fill", label: "Story", value: "Chawabhon Netisingha", layout: layout, textPrimary: textPrimary, textMuted: textMuted)
                    CreditRow(icon: "chevron.left.forwardslash.chevron.right", label: "Code", value: "Chawabhon Netisingha", layout: layout, textPrimary: textPrimary, textMuted: textMuted)
                }
            }

            infoSection(
                title: "Project Notes",
                subtitle: "Built for an interactive Swift student challenge experience"
            ) {
                VStack(alignment: .leading, spacing: layout.scaled(6)) {
                    Label("Responsive UI for iPhone, iPad, and Mac layouts", systemImage: "rectangle.3.group")
                    Label("Story chapters, gallery, and learning features", systemImage: "sparkles")
                    Label("Settings and motion controls from main menu", systemImage: "gearshape.2.fill")
                }
                .font(.system(size: layout.captionFontSize + 2))
                .foregroundStyle(textMuted)
            }
        }
    }

    private var memoryTab: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            infoSection(
                title: "Memory Board",
                subtitle: "Moments and assets used in the project moodboard"
            ) {
                VStack(spacing: layout.scaled(10)) {
                    memoryCard

                    HStack(spacing: 8) {
                        ForEach(0..<memoryImages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentImageIndex ? accent : textMuted.opacity(0.35))
                                .frame(width: index == currentImageIndex ? 20 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.25), value: currentImageIndex)
                        }
                    }

                    Text(memoryImages[currentImageIndex])
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .textCase(nil)
                }
            }

            infoSection(
                title: "Thanks",
                subtitle: "Built with SwiftUI and lots of iteration"
            ) {
                HStack(spacing: 10) {
                    Label("SwiftUI", systemImage: "swift")
                    Label("iPad + Mac", systemImage: "macbook.and.ipad")
                    Label("Neura", systemImage: "brain.head.profile")
                }
                .font(.system(size: layout.captionFontSize + 1))
                .foregroundStyle(textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var memoryCard: some View {
        RoundedRectangle(cornerRadius: layout.scaled(10), style: .continuous)
            .fill(Color.white)
            .frame(height: layout.width < 700 || layout.isPortrait ? layout.scaled(180) : layout.scaled(220))
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: layout.scaled(8), style: .continuous)
                        .fill(Color(red: 0.93, green: 0.95, blue: 0.97))
                        .padding(layout.scaled(10))

                    Image(memoryImages[currentImageIndex])
                        .resizable()
                        .scaledToFill()
                        .opacity(imageOpacity)
                        .clipShape(RoundedRectangle(cornerRadius: layout.scaled(8), style: .continuous))
                        .padding(layout.scaled(10))

                    VStack {
                        HStack {
                            Spacer()
                            Text("\(currentImageIndex + 1)/\(memoryImages.count)")
                                .font(.system(size: layout.captionFontSize, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(layout.scaled(16))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.scaled(10), style: .continuous)
                    .stroke(sectionBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func infoSection<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder body: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: layout.scaled(10)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: layout.bodyFontSize + 1, weight: .bold))
                    .foregroundStyle(textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: layout.captionFontSize + 1))
                        .foregroundStyle(textMuted)
                }
            }

            body()
        }
        .padding(layout.scaled(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: layout.scaled(10), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.scaled(10), style: .continuous)
                .stroke(sectionBorder, lineWidth: 1)
        )
    }

    private func creditBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func startImageCycle() {
        stopImageCycle()
        timer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            Task { @MainActor in
                cycleImage()
            }
        }
    }

    private func stopImageCycle() {
        timer?.invalidate()
        timer = nil
    }

    private func cycleImage() {
        withAnimation(.easeInOut(duration: 0.35)) {
            imageOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            currentImageIndex = (currentImageIndex + 1) % memoryImages.count
            withAnimation(.easeInOut(duration: 0.35)) {
                imageOpacity = 1
            }
        }
    }
}

private enum CreditsPopupTab: String, CaseIterable, Identifiable {
    case credits
    case memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .credits:
            return "Credits"
        case .memory:
            return "Memory"
        }
    }
}

private struct CreditRow: View {
    let icon: String
    let label: String
    let value: String
    let layout: ResponsiveLayout
    let textPrimary: Color
    let textMuted: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: layout.captionFontSize + 3, weight: .semibold))
                .foregroundStyle(textMuted)
                .frame(width: layout.scaled(22))

            Text(label)
                .font(.system(size: layout.captionFontSize + 2, weight: .semibold))
                .foregroundStyle(textPrimary)
                .frame(width: layout.scaled(72), alignment: .leading)

            Text(value)
                .font(.system(size: layout.captionFontSize + 2))
                .foregroundStyle(textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, layout.scaled(10))
        .padding(.vertical, layout.scaled(8))
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: layout.scaled(8), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.scaled(8), style: .continuous)
                .stroke(Color(red: 0.90, green: 0.92, blue: 0.95), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Image("lantassc")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()

        MenuCreditsPopupOverlay(
            layout: ResponsiveLayout(width: 1024, height: 768, safeAreaInsets: EdgeInsets()),
            onClose: {}
        )
    }
}
