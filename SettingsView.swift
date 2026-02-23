import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: GlobalSettingsStore
    @State private var showResetAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header(layout: layout)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                            infoCard(layout: layout)
                            appearanceCard(layout: layout)
                            interfaceCard(layout: layout)
                            resetCard(layout: layout)
                        }
                        .padding(.horizontal, layout.padding)
                        .padding(.top, layout.sectionSpacing)
                        .padding(.bottom, max(layout.padding, geometry.safeAreaInsets.bottom + 8))
                    }
                }
            }
            .alert("Reset settings?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    settings.reset()
                }
            } message: {
                Text("This restores all menu settings to default values.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func header(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.elementSpacing) {
            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: layout.bodyFontSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, layout.scaled(12))
                .padding(.vertical, layout.scaled(8))
                .background(
                    RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: layout.headlineFontSize, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Balance title centering against the back button width.
            Color.clear.frame(width: layout.scaled(88), height: layout.scaled(40))
        }
        .padding(.horizontal, layout.padding)
        .padding(.top, layout.safeAreaInsets.top + 8)
        .padding(.bottom, layout.elementSpacing)
        .background(Color.black.opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
    
    private func infoCard(layout: ResponsiveLayout) -> some View {
        settingsCard(layout: layout) {
            VStack(alignment: .leading, spacing: layout.elementSpacing) {
                HStack(spacing: layout.elementSpacing) {
                    Image(systemName: "gearshape")
                        .font(.system(size: layout.iconSize * 0.9, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: layout.scaled(30), height: layout.scaled(30))
                        .background(
                            RoundedRectangle(cornerRadius: layout.cornerRadius * 0.5)
                                .fill(Color.white.opacity(0.06))
                        )
                    
                    Text("Global Menu Settings")
                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("Changes here affect the main menu across the app and stay saved after relaunch.")
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.white.opacity(0.7))
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
                    subtitle: "Disable menu background motion.",
                    icon: "sparkles",
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
                    HStack {
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
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: layout.cornerRadius * 0.75)
                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func sectionTitle(_ text: String, layout: ResponsiveLayout) -> some View {
        Text(text)
            .font(.system(size: layout.bodyFontSize, weight: .semibold))
            .foregroundColor(.white.opacity(0.95))
    }
    
    private func settingsCard<Content: View>(
        layout: ResponsiveLayout,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(layout.padding)
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
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
                    .foregroundColor(.white.opacity(0.85))
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
        .tint(.white)
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
                    .foregroundColor(.white.opacity(0.85))
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
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }
            
            Slider(value: $value, in: range)
                .tint(.white)
                .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.45 : 1)
    }
}

#Preview {
    SettingsView(settings: GlobalSettingsStore())
        .preferredColorScheme(.dark)
}
