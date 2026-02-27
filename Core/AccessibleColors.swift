import SwiftUI

// MARK: - Centralized Accessible Color Palette
// Provides WCAG-compliant colors with color-blind-friendly alternatives.
// When colorBlindMode is enabled, problematic color combinations (red/green)
// are replaced with distinguishable alternatives (blue/orange with shape cues).

struct AccessibleColors {
    let colorBlindMode: Bool

    init(colorBlindMode: Bool = false) {
        self.colorBlindMode = colorBlindMode
    }

    // MARK: - Semantic Status Colors
    // These replace raw .green/.red/.orange throughout the app.
    // In color-blind mode, green→blue, red→vermillion, orange→yellow
    // following the Wong color-blind-safe palette.

    var success: Color {
        colorBlindMode ? Color(red: 0.0, green: 0.45, blue: 0.70) : Color(red: 0.13, green: 0.72, blue: 0.45)
    }

    var warning: Color {
        colorBlindMode ? Color(red: 0.90, green: 0.67, blue: 0.0) : Color(red: 0.95, green: 0.55, blue: 0.15)
    }

    var error: Color {
        colorBlindMode ? Color(red: 0.80, green: 0.24, blue: 0.0) : Color(red: 0.90, green: 0.25, blue: 0.20)
    }

    var successLabel: String { colorBlindMode ? "Good" : "Good" }
    var warningLabel: String { colorBlindMode ? "Uncertain" : "Uncertain" }
    var errorLabel: String { colorBlindMode ? "Poor" : "Poor" }

    var successIcon: String { "checkmark.circle.fill" }
    var warningIcon: String { "exclamationmark.triangle.fill" }
    var errorIcon: String { "xmark.circle.fill" }

    // MARK: - Confidence Level Helper
    func confidenceColor(for value: Double) -> Color {
        if value > 0.7 { return success }
        if value > 0.5 { return warning }
        return error
    }

    func confidenceLabel(for value: Double) -> String {
        if value > 0.7 { return "High confidence" }
        if value > 0.5 { return "Medium confidence" }
        return "Low confidence"
    }

    func confidenceIcon(for value: Double) -> String {
        if value > 0.7 { return successIcon }
        if value > 0.5 { return warningIcon }
        return errorIcon
    }

    // MARK: - Theme Accent Colors
    // Dialog system accent — pink in standard, magenta-shifted in CB mode
    var dialogAccent: Color {
        colorBlindMode ? Color(red: 0.80, green: 0.47, blue: 0.65) : .pink
    }

    // Cyan accent used in dialog/UI
    var infoAccent: Color {
        colorBlindMode ? Color(red: 0.34, green: 0.71, blue: 0.91) : .cyan
    }

    // MARK: - Menu / Panel Colors (improved contrast)

    // Panel backgrounds — slightly darker for better contrast with text
    static let panelBackground = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let panelBorder = Color(red: 0.75, green: 0.78, blue: 0.82)
    static let sectionBorder = Color(red: 0.78, green: 0.80, blue: 0.83)

    // Text colors — darker for WCAG AA compliance (4.5:1 ratio)
    static let textPrimary = Color(red: 0.11, green: 0.14, blue: 0.20)
    static let textSecondary = Color(red: 0.33, green: 0.37, blue: 0.43)

    // Sidebar
    static let sidebarSelected = Color(red: 0.68, green: 0.84, blue: 0.96)
    static let sidebarBackground = Color(red: 0.82, green: 0.91, blue: 0.97)

    // Menu button idle text — darker than .gray.opacity(0.5) for contrast
    static let menuIdleText = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let menuIdleSubtext = Color(red: 0.50, green: 0.53, blue: 0.58)
    static let menuIdleIcon = Color(red: 0.50, green: 0.53, blue: 0.58)

    // Version label — improved from .gray.opacity(0.5)
    static let versionLabel = Color(red: 0.50, green: 0.53, blue: 0.58)

    // MARK: - Correct/Incorrect for mini-games
    var correct: Color { success }
    var incorrect: Color { error }

    // MARK: - Ready/Not Ready status
    var ready: Color { success }
    var notReady: Color { warning }
}

// MARK: - Environment Key
private struct AccessibleColorsKey: EnvironmentKey {
    static let defaultValue = AccessibleColors()
}

extension EnvironmentValues {
    var accessibleColors: AccessibleColors {
        get { self[AccessibleColorsKey.self] }
        set { self[AccessibleColorsKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    func accessibleColors(colorBlindMode: Bool) -> some View {
        environment(\.accessibleColors, AccessibleColors(colorBlindMode: colorBlindMode))
    }
}

// MARK: - Confidence Indicator View
// Replaces color-only confidence display with color + icon + text label
struct AccessibleConfidenceIndicator: View {
    let confidence: Double
    let label: String
    let layout: ResponsiveLayout
    @Environment(\.accessibleColors) private var colors

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: colors.confidenceIcon(for: confidence))
                .foregroundColor(colors.confidenceColor(for: confidence))
                .font(.system(size: layout.captionFontSize))

            Text(label)
                .font(.system(size: layout.bodyFontSize, weight: .semibold))
                .foregroundColor(colors.confidenceColor(for: confidence))

            Text("(\(Int(confidence * 100))%)")
                .font(.system(size: layout.captionFontSize, weight: .medium))
                .foregroundColor(colors.confidenceColor(for: confidence))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(colors.confidenceLabel(for: confidence)), \(Int(confidence * 100)) percent")
    }
}

// MARK: - Accessible Status Badge
// Shows status with both color and icon for color-blind users
struct AccessibleStatusBadge: View {
    let isPositive: Bool
    let positiveText: String
    let negativeText: String
    @Environment(\.accessibleColors) private var colors

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption2)
            Text(isPositive ? positiveText : negativeText)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(isPositive ? colors.success : colors.warning)
        .accessibilityLabel(isPositive ? positiveText : negativeText)
    }
}
