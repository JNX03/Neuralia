import SwiftUI

struct MenuSettingsPopupOverlay: View {
    @ObservedObject var settings: GlobalSettingsStore
    let layout: ResponsiveLayout
    let onClose: () -> Void

    @State private var selectedTab: PopupTab = .games
    private let panelBorder = AccessibleColors.panelBorder
    private let panelBackground = AccessibleColors.panelBackground
    private let sectionBorder = AccessibleColors.sectionBorder
    private let sidebarSelected = AccessibleColors.sidebarSelected
    private let accent = Color(red: 0.20, green: 0.60, blue: 0.90)
    private let textPrimary = AccessibleColors.textPrimary
    private let textMuted = AccessibleColors.textSecondary

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            popupCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityAddTraits(.isModal)
    }

    private var popupCard: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(panelBorder)
            content
        }
        .frame(
            maxWidth: min(layout.width - (layout.padding * 2), layout.isCompact ? 560 : 780),
            maxHeight: min(layout.height * 0.86, layout.isCompact ? 620 : 540)
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
                Text("Options")
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
            .accessibilityLabel("Close Settings")
            .accessibilityHint("Double tap to close the settings panel")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, layout.scaled(16))
        .padding(.vertical, layout.scaled(12))
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.75),
                    Color.white.opacity(0.45)
                ],
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
            ForEach(PopupTab.allCases) { tab in
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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.title) tab")
                .accessibilityHint("Double tap to show \(tab.title.lowercased()) settings")
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])

                Divider()
                    .overlay(panelBorder.opacity(0.8))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button("Reset") {
                    settings.reset()
                }
                .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                .foregroundStyle(textMuted)
                .buttonStyle(.plain)
                .accessibilityLabel("Reset all settings to defaults")
                .accessibilityHint("Double tap to reset all options")
                .accessibilityAddTraits(.isButton)

                Spacer()
            }
            .padding(.horizontal, layout.scaled(12))
            .padding(.vertical, layout.scaled(10))
        }
        .frame(
            width: layout.width < 700 || layout.isPortrait ? nil : max(128, layout.scaled(150)),
            height: layout.width < 700 || layout.isPortrait ? nil : .infinity
        )
        .background(AccessibleColors.sidebarBackground.opacity(0.90))
    }

    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.scaled(12)) {
                switch selectedTab {
                case .games:
                    gamesTab
                case .volume:
                    volumeTab
                case .notice:
                    noticeTab
                case .language:
                    languageTab
                case .accessibility:
                    accessibilityTab
                }
            }
            .padding(layout.scaled(12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.65))
    }

    private var gamesTab: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            optionSection(
                title: "Motion Effects",
                subtitle: "Enable menu animations and parallax movement.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: motionEffectsBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )

            optionSection(
                title: "Parallax Strength",
                subtitle: nil,
                body: {
                    ChoiceRadioGroup(
                        options: IntensityPreset.allCases,
                        selection: parallaxPresetBinding,
                        isDisabled: settings.reduceMotion,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        label: { $0.title }
                    )
                }
            )

            optionSection(
                title: "Menu Overlay",
                subtitle: "Darkness level behind the menu buttons.",
                body: {
                    ChoiceRadioGroup(
                        options: IntensityPreset.allCases,
                        selection: overlayPresetBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        label: { $0.title }
                    )
                }
            )
        }
    }

    private var volumeTab: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            optionSection(
                title: "Master Volume",
                subtitle: "Applies to app voice / speech playback level.",
                body: {
                    ChoiceRadioGroup(
                        options: VolumeOption.allCases,
                        selection: masterVolumePresetBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        label: { $0.title }
                    )
                }
            )

            optionSection(
                title: "Voice Box",
                subtitle: "Turns narration voice on/off across the app.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: speechEnabledBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )

            optionSection(
                title: "Background Music",
                subtitle: "Turns the background music on or off.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: musicEnabledBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )
        }
    }

    private var noticeTab: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            optionSection(
                title: "Status Indicator",
                subtitle: "Show the \"Ready to Play\" indicator on the main menu.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: statusIndicatorBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )

            optionSection(
                title: "Version Label",
                subtitle: "Show version text in the bottom-right corner.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: versionLabelBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )
        }
    }

    private var languageTab: some View {
        optionSection(
            title: "Language",
            subtitle: "English is locked for this version.",
            body: {
                HStack(spacing: 10) {
                    RadioIcon(isSelected: true, accent: accent)
                    Text("English")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundStyle(textPrimary)
                    Spacer(minLength: 0)
                    Label("Locked", systemImage: "lock.fill")
                        .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                        .foregroundStyle(textMuted)
                }
                .padding(.vertical, 4)
            }
        )
    }

    private var accessibilityTab: some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            optionSection(
                title: "Color Blind Mode",
                subtitle: "Replaces red/green indicators with blue/orange and adds shape icons for status cues.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: colorBlindModeBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )

            optionSection(
                title: "Reduce Motion",
                subtitle: "Disables parallax, bouncing, and other animations throughout the app.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: reduceMotionBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )

            optionSection(
                title: "Voice Narration",
                subtitle: "Spoken narration for dialog text. Helpful for users who prefer audio content.",
                body: {
                    BinaryRadioGroup(
                        leftTitle: "On",
                        rightTitle: "Off",
                        selection: speechEnabledBinding,
                        layout: layout,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func optionSection<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder body: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: layout.scaled(8)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 3, height: layout.scaled(18))
                        .clipShape(Capsule())

                    Text(title)
                        .font(.system(size: layout.bodyFontSize + 1, weight: .medium))
                        .foregroundStyle(textPrimary)
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: layout.captionFontSize + 1))
                        .foregroundStyle(textMuted)
                        .padding(.leading, layout.scaled(11))
                }
            }

            body()
        }
        .padding(layout.scaled(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: layout.scaled(6), style: .continuous)
                .stroke(sectionBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: layout.scaled(6), style: .continuous))
    }

    private var motionEffectsBinding: Binding<Bool> {
        Binding(
            get: { !settings.reduceMotion },
            set: { settings.reduceMotion = !$0 }
        )
    }

    private var statusIndicatorBinding: Binding<Bool> {
        Binding(
            get: { settings.showStatusIndicator },
            set: { settings.showStatusIndicator = $0 }
        )
    }

    private var versionLabelBinding: Binding<Bool> {
        Binding(
            get: { settings.showVersionLabel },
            set: { settings.showVersionLabel = $0 }
        )
    }

    private var speechEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.speechEnabled },
            set: { settings.speechEnabled = $0 }
        )
    }

    private var musicEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.musicEnabled },
            set: { settings.musicEnabled = $0 }
        )
    }

    private var colorBlindModeBinding: Binding<Bool> {
        Binding(
            get: { settings.colorBlindMode },
            set: { settings.colorBlindMode = $0 }
        )
    }

    private var reduceMotionBinding: Binding<Bool> {
        Binding(
            get: { settings.reduceMotion },
            set: { settings.reduceMotion = $0 }
        )
    }

    private var parallaxPresetBinding: Binding<IntensityPreset> {
        Binding(
            get: { IntensityPreset.closest(to: settings.parallaxStrength) },
            set: { settings.parallaxStrength = $0.parallaxValue }
        )
    }

    private var overlayPresetBinding: Binding<IntensityPreset> {
        Binding(
            get: { IntensityPreset.closestOverlay(to: settings.menuOverlayOpacity) },
            set: { settings.menuOverlayOpacity = $0.overlayValue }
        )
    }

    private var masterVolumePresetBinding: Binding<VolumeOption> {
        Binding(
            get: { VolumeOption.closest(to: settings.masterVolume) },
            set: { settings.masterVolume = $0.volumeValue }
        )
    }
}

private enum PopupTab: String, CaseIterable, Identifiable {
    case games = "Games"
    case volume = "Volume"
    case notice = "Notice"
    case language = "Language"
    case accessibility = "Accessibility"

    var id: String { rawValue }
    var title: String { rawValue }
}

private enum IntensityPreset: String, CaseIterable, Identifiable {
    case veryHigh = "Very High"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }
    var title: String { rawValue }

    var parallaxValue: Double {
        switch self {
        case .veryHigh: return 1.0
        case .high: return 0.85
        case .medium: return 0.6
        case .low: return 0.35
        }
    }

    var overlayValue: Double {
        switch self {
        case .veryHigh: return 0.8
        case .high: return 0.65
        case .medium: return 0.5
        case .low: return 0.35
        }
    }

    static func closest(to value: Double) -> IntensityPreset {
        allCases.min(by: { abs($0.parallaxValue - value) < abs($1.parallaxValue - value) }) ?? .high
    }

    static func closestOverlay(to value: Double) -> IntensityPreset {
        allCases.min(by: { abs($0.overlayValue - value) < abs($1.overlayValue - value) }) ?? .medium
    }
}

private enum VolumeOption: String, CaseIterable, Identifiable {
    case veryHigh = "Very High"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case mute = "Mute"

    var id: String { rawValue }
    var title: String { rawValue }

    var volumeValue: Double {
        switch self {
        case .veryHigh: return 1.0
        case .high: return 0.8
        case .medium: return 0.55
        case .low: return 0.3
        case .mute: return 0.0
        }
    }

    static func closest(to value: Double) -> VolumeOption {
        allCases.min(by: { abs($0.volumeValue - value) < abs($1.volumeValue - value) }) ?? .high
    }
}

private struct BinaryRadioGroup: View {
    let leftTitle: String
    let rightTitle: String
    @Binding var selection: Bool
    let layout: ResponsiveLayout
    let accent: Color
    let textPrimary: Color
    let textMuted: Color

    var body: some View {
        HStack(spacing: layout.scaled(20)) {
            radioButton(title: leftTitle, isSelected: selection) {
                selection = true
            }
            radioButton(title: rightTitle, isSelected: !selection) {
                selection = false
            }
            Spacer(minLength: 0)
        }
    }

    private func radioButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RadioIcon(isSelected: isSelected, accent: accent)
                Text(title)
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundStyle(isSelected ? textPrimary : textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ChoiceRadioGroup<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    var isDisabled: Bool = false
    let layout: ResponsiveLayout
    let accent: Color
    let textPrimary: Color
    let textMuted: Color
    let label: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: layout.scaled(10)) {
            ForEach(optionRows, id: \.self) { row in
                HStack(spacing: layout.scaled(18)) {
                    ForEach(row) { option in
                        Button {
                            selection = option
                        } label: {
                            HStack(spacing: 8) {
                                RadioIcon(isSelected: selection == option, accent: accent)
                                Text(label(option))
                                    .font(.system(size: layout.bodyFontSize))
                                    .foregroundStyle(selection == option ? textPrimary : textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(label(option))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                    }

                    if row.count == 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var columnCount: Int {
        layout.width < 520 ? 2 : 4
    }

    private var optionRows: [[Option]] {
        stride(from: 0, to: options.count, by: columnCount).map { start in
            Array(options[start..<min(start + columnCount, options.count)])
        }
    }
}

private struct RadioIcon: View {
    let isSelected: Bool
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accent : Color.gray.opacity(0.45), lineWidth: 1.5)
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

struct MenuSettingsPopupOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { geometry in
                MenuSettingsPopupOverlay(
                    settings: GlobalSettingsStore(),
                    layout: ResponsiveLayout(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        safeAreaInsets: geometry.safeAreaInsets
                    ),
                    onClose: {}
                )
            }
        }
    }
}
