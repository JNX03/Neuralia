import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: GlobalSettingsStore

    @State private var showResetAlert = false
    @State private var selectedPage: SettingsPage = .appearance
    @State private var pageDirection: CGFloat = 1
    @State private var animateCharacter = false
    @Namespace private var tabIndicator

    private let accent = Color(red: 0.39, green: 0.92, blue: 1.0)

    private enum SettingsPage: String, CaseIterable, Identifiable {
        case appearance = "Lab View"
        case interface = "Other Settings"

        var id: Self { self }

        var icon: String {
            switch self {
            case .appearance: return "sparkles.tv"
            case .interface: return "slider.horizontal.3"
            }
        }

        var index: Int {
            switch self {
            case .appearance: return 0
            case .interface: return 1
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            let useSplitLayout = layout.isLandscape || layout.width > 720

            ZStack {
                backgroundView(layout: layout)

                Group {
                    if useSplitLayout {
                        HStack(spacing: layout.sectionSpacing) {
                            characterPanel(layout: layout)
                                .frame(maxWidth: geometry.size.width * 0.34)

                            settingsPanel(layout: layout)
                        }
                    } else {
                        VStack(spacing: layout.sectionSpacing) {
                            characterPanel(layout: layout)
                                .frame(height: min(geometry.size.height * 0.28, layout.scaled(220)))

                            settingsPanel(layout: layout)
                        }
                    }
                }
                .frame(
                    maxWidth: min(geometry.size.width - (layout.padding * 2), 1180),
                    maxHeight: .infinity,
                    alignment: .top
                )
                .padding(.horizontal, layout.padding)
                .padding(.top, geometry.safeAreaInsets.top + layout.scaled(10))
                .padding(.bottom, max(layout.padding, geometry.safeAreaInsets.bottom + layout.scaled(8)))
            }
            .alert("Reset settings?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    settings.reset()
                }
            } message: {
                Text("This restores all menu settings to default values.")
            }
            .onAppear {
                animateCharacter = !settings.reduceMotion
            }
            .onChange(of: settings.reduceMotion) { _, reduceMotion in
                animateCharacter = !reduceMotion
            }
        }
        .preferredColorScheme(.dark)
    }

    private func backgroundView(layout: ResponsiveLayout) -> some View {
        ZStack {
            Image("lantassc")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    accent.opacity(0.2),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    private func characterPanel(layout: ResponsiveLayout) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: layout.cornerRadius + 6)
                .fill(Color.black.opacity(0.34))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius + 6)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius + 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .padding(1)
                )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius + 6))

            Image("char_neutral")
                .resizable()
                .scaledToFit()
                .padding(layout.scaled(18))
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
                .scaleEffect(settings.reduceMotion ? 1 : (animateCharacter ? 1.02 : 0.98))
                .offset(y: settings.reduceMotion ? 0 : (animateCharacter ? -6 : 6))
                .animation(
                    settings.reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                    value: animateCharacter
                )
        }
    }

    private func settingsPanel(layout: ResponsiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.sectionSpacing) {
            settingsHeader(layout: layout)
            pageSwitcher(layout: layout)
            pageContent(layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(layout.padding)
        .background(panelBackground(layout: layout))
    }

    private func settingsHeader(layout: ResponsiveLayout) -> some View {
        HStack(alignment: .center, spacing: layout.elementSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: layout.headlineFontSize + 2, weight: .bold))
                    .foregroundColor(.white)

                Text("Clean control panel for menu behavior and interface options.")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer(minLength: layout.elementSpacing)

            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                    Text("Exit")
                }
                .font(.system(size: layout.bodyFontSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, layout.scaled(12))
                .padding(.vertical, layout.scaled(8))
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.22))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.55), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func pageSwitcher(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.scaled(8)) {
            ForEach(SettingsPage.allCases) { page in
                Button {
                    selectPage(page)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: page.icon)
                            .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        Text(page.rawValue)
                            .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(selectedPage == page ? 0.98 : 0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, layout.scaled(10))
                    .padding(.vertical, layout.scaled(10))
                    .background {
                        if selectedPage == page {
                            RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                                .fill(accent.opacity(0.17))
                                .overlay(
                                    RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                                        .stroke(accent.opacity(0.45), lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "settings-page-indicator", in: tabIndicator)
                        } else {
                            RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                                .fill(Color.white.opacity(0.02))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(layout.scaled(6))
        .background(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func pageContent(layout: ResponsiveLayout) -> some View {
        ZStack {
            if selectedPage == .appearance {
                appearancePage(layout: layout)
                    .transition(slideTransition)
                    .zIndex(1)
            }

            if selectedPage == .interface {
                interfacePage(layout: layout)
                    .transition(slideTransition)
                    .zIndex(1)
            }
        }
        .clipped()
        .animation(settings.reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9), value: selectedPage)
    }

    private func appearancePage(layout: ResponsiveLayout) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                infoCard(layout: layout)
                appearanceCard(layout: layout)
            }
            .padding(.top, 2)
            .padding(.bottom, 2)
        }
    }

    private func interfacePage(layout: ResponsiveLayout) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                interfaceCard(layout: layout)
                resetCard(layout: layout)
            }
            .padding(.top, 2)
            .padding(.bottom, 2)
        }
    }

    private var slideTransition: AnyTransition {
        let insertionEdge: Edge = pageDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = pageDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func selectPage(_ page: SettingsPage) {
        guard page != selectedPage else { return }

        pageDirection = page.index > selectedPage.index ? 1 : -1
        withAnimation(settings.reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)) {
            selectedPage = page
        }
    }

    private func panelBackground(layout: ResponsiveLayout) -> some View {
        RoundedRectangle(cornerRadius: layout.cornerRadius + 8)
            .fill(Color.black.opacity(0.42))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius + 8)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius + 8)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
                    .padding(1)
            )
    }

    private func infoCard(layout: ResponsiveLayout) -> some View {
        settingsCard(layout: layout) {
            VStack(alignment: .leading, spacing: layout.elementSpacing) {
                HStack(spacing: layout.elementSpacing) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: layout.iconSize * 0.85, weight: .semibold))
                        .foregroundColor(accent)
                        .frame(width: layout.scaled(34), height: layout.scaled(34))
                        .background(
                            RoundedRectangle(cornerRadius: layout.cornerRadius * 0.55)
                                .fill(accent.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: layout.cornerRadius * 0.55)
                                        .stroke(accent.opacity(0.22), lineWidth: 1)
                                )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Computer Lab Style")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Background uses the LANTASSC image with a cleaner split UI.")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.white.opacity(0.68))
                    }
                }

                Text("Switch pages above to move between visual settings and other menu options.")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
    }

    private func appearanceCard(layout: ResponsiveLayout) -> some View {
        settingsCard(layout: layout) {
            VStack(alignment: .leading, spacing: layout.elementSpacing) {
                sectionTitle("Appearance", layout: layout)

                SettingsToggleRow(
                    layout: layout,
                    title: "Reduce Motion",
                    subtitle: "Disable menu and settings animations.",
                    icon: "figure.walk.motion",
                    isOn: $settings.reduceMotion
                )

                Divider().overlay(Color.white.opacity(0.08))

                SettingsSliderRow(
                    layout: layout,
                    title: "Parallax Strength",
                    subtitle: "Menu background movement amount.",
                    icon: "arrow.left.and.right",
                    value: $settings.parallaxStrength,
                    range: 0...1,
                    valueText: "\(Int(settings.parallaxStrength * 100))%",
                    isDisabled: settings.reduceMotion
                )

                Divider().overlay(Color.white.opacity(0.08))

                SettingsSliderRow(
                    layout: layout,
                    title: "Background Dim",
                    subtitle: "Darkness over the menu background.",
                    icon: "circle.lefthalf.filled",
                    value: $settings.menuOverlayOpacity,
                    range: 0.35...0.8,
                    valueText: "\(Int(settings.menuOverlayOpacity * 100))%"
                )
            }
        }
    }

    private func interfaceCard(layout: ResponsiveLayout) -> some View {
        settingsCard(layout: layout) {
            VStack(alignment: .leading, spacing: layout.elementSpacing) {
                sectionTitle("Interface", layout: layout)

                SettingsToggleRow(
                    layout: layout,
                    title: "Show Status Indicator",
                    subtitle: "Show the \"Ready to Play\" row.",
                    icon: "dot.radiowaves.left.and.right",
                    isOn: $settings.showStatusIndicator
                )

                Divider().overlay(Color.white.opacity(0.08))

                SettingsToggleRow(
                    layout: layout,
                    title: "Show Version Label",
                    subtitle: "Show app version in the corner.",
                    icon: "number",
                    isOn: $settings.showVersionLabel
                )
            }
        }
    }

    private func resetCard(layout: ResponsiveLayout) -> some View {
        settingsCard(layout: layout) {
            VStack(alignment: .leading, spacing: layout.elementSpacing) {
                sectionTitle("Reset", layout: layout)

                Text("Restore the original menu style and behavior.")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.7))

                Button(action: { showResetAlert = true }) {
                    HStack(spacing: layout.elementSpacing) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, layout.scaled(14))
                    .padding(.vertical, layout.scaled(12))
                    .background(
                        RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                            .fill(Color.red.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionTitle(_ text: String, layout: ResponsiveLayout) -> some View {
        Text(text.uppercased())
            .font(.system(size: layout.captionFontSize + 1, weight: .bold))
            .tracking(0.8)
            .foregroundColor(accent.opacity(0.95))
    }

    private func settingsCard<Content: View>(
        layout: ResponsiveLayout,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(layout.padding)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

private struct SettingsToggleRow: View {
    let layout: ResponsiveLayout
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: layout.elementSpacing) {
                Image(systemName: icon)
                    .font(.system(size: layout.iconSize * 0.7, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: layout.scaled(24), height: layout.scaled(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: layout.bodyFontSize, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
        }
        .tint(Color(red: 0.39, green: 0.92, blue: 1.0))
    }
}

private struct SettingsSliderRow: View {
    let layout: ResponsiveLayout
    let title: String
    let subtitle: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack(alignment: .top, spacing: layout.elementSpacing) {
                Image(systemName: icon)
                    .font(.system(size: layout.iconSize * 0.7, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: layout.scaled(24), height: layout.scaled(24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: layout.bodyFontSize, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                Text(valueText)
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }

            Slider(value: $value, in: range)
                .tint(Color(red: 0.39, green: 0.92, blue: 1.0))
                .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.45 : 1)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: GlobalSettingsStore())
            .preferredColorScheme(.dark)
    }
}
