import SwiftUI

@MainActor
final class GlobalSettingsStore: ObservableObject {
    static let shared = GlobalSettingsStore()

    private enum Keys {
        static let reduceMotion = "globalSettings.reduceMotion"
        static let parallaxStrength = "globalSettings.parallaxStrength"
        static let menuOverlayOpacity = "globalSettings.menuOverlayOpacity"
        static let showStatusIndicator = "globalSettings.showStatusIndicator"
        static let showVersionLabel = "globalSettings.showVersionLabel"
        static let masterVolume = "globalSettings.masterVolume"
        static let speechEnabled = "globalSettings.speechEnabled"
    }
    
    private enum Defaults {
        static let reduceMotion = false
        static let parallaxStrength = 0.85
        static let menuOverlayOpacity = 0.55
        static let showStatusIndicator = true
        static let showVersionLabel = true
        static let masterVolume = 0.85
        static let speechEnabled = true
    }
    
    private let userDefaults: UserDefaults
    private var isLoading = false
    
    @Published var reduceMotion: Bool = Defaults.reduceMotion {
        didSet { persist(reduceMotion, forKey: Keys.reduceMotion) }
    }
    
    @Published var parallaxStrength: Double = Defaults.parallaxStrength {
        didSet { persist(parallaxStrength, forKey: Keys.parallaxStrength) }
    }
    
    @Published var menuOverlayOpacity: Double = Defaults.menuOverlayOpacity {
        didSet { persist(menuOverlayOpacity, forKey: Keys.menuOverlayOpacity) }
    }
    
    @Published var showStatusIndicator: Bool = Defaults.showStatusIndicator {
        didSet { persist(showStatusIndicator, forKey: Keys.showStatusIndicator) }
    }
    
    @Published var showVersionLabel: Bool = Defaults.showVersionLabel {
        didSet { persist(showVersionLabel, forKey: Keys.showVersionLabel) }
    }

    @Published var masterVolume: Double = Defaults.masterVolume {
        didSet { persist(masterVolume, forKey: Keys.masterVolume) }
    }

    @Published var speechEnabled: Bool = Defaults.speechEnabled {
        didSet { persist(speechEnabled, forKey: Keys.speechEnabled) }
    }
    
    var effectiveParallaxStrength: CGFloat {
        reduceMotion ? 0 : CGFloat(parallaxStrength)
    }

    var effectiveSpeechVolume: Float {
        guard speechEnabled else { return 0 }
        let clamped = min(max(masterVolume, 0), 1)
        return Float(clamped)
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }
    
    func reset() {
        reduceMotion = Defaults.reduceMotion
        parallaxStrength = Defaults.parallaxStrength
        menuOverlayOpacity = Defaults.menuOverlayOpacity
        showStatusIndicator = Defaults.showStatusIndicator
        showVersionLabel = Defaults.showVersionLabel
        masterVolume = Defaults.masterVolume
        speechEnabled = Defaults.speechEnabled
    }
    
    private func load() {
        isLoading = true
        
        if userDefaults.object(forKey: Keys.reduceMotion) != nil {
            reduceMotion = userDefaults.bool(forKey: Keys.reduceMotion)
        }
        if userDefaults.object(forKey: Keys.parallaxStrength) != nil {
            parallaxStrength = userDefaults.double(forKey: Keys.parallaxStrength)
        }
        if userDefaults.object(forKey: Keys.menuOverlayOpacity) != nil {
            menuOverlayOpacity = userDefaults.double(forKey: Keys.menuOverlayOpacity)
        }
        if userDefaults.object(forKey: Keys.showStatusIndicator) != nil {
            showStatusIndicator = userDefaults.bool(forKey: Keys.showStatusIndicator)
        }
        if userDefaults.object(forKey: Keys.showVersionLabel) != nil {
            showVersionLabel = userDefaults.bool(forKey: Keys.showVersionLabel)
        }
        if userDefaults.object(forKey: Keys.masterVolume) != nil {
            masterVolume = userDefaults.double(forKey: Keys.masterVolume)
        }
        if userDefaults.object(forKey: Keys.speechEnabled) != nil {
            speechEnabled = userDefaults.bool(forKey: Keys.speechEnabled)
        }
        
        if !parallaxStrength.isFinite {
            parallaxStrength = Defaults.parallaxStrength
        }
        if !menuOverlayOpacity.isFinite {
            menuOverlayOpacity = Defaults.menuOverlayOpacity
        }
        if !masterVolume.isFinite {
            masterVolume = Defaults.masterVolume
        }

        parallaxStrength = min(max(parallaxStrength, 0), 1)
        menuOverlayOpacity = min(max(menuOverlayOpacity, 0.35), 0.8)
        masterVolume = min(max(masterVolume, 0), 1)
        
        isLoading = false
    }
    
    private func persist(_ value: Bool, forKey key: String) {
        guard !isLoading else { return }
        userDefaults.set(value, forKey: key)
    }
    
    private func persist(_ value: Double, forKey key: String) {
        guard !isLoading else { return }
        userDefaults.set(value, forKey: key)
    }
}
