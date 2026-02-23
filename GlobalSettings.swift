import SwiftUI

@MainActor
final class GlobalSettingsStore: ObservableObject {
    private enum Keys {
        static let reduceMotion = "globalSettings.reduceMotion"
        static let parallaxStrength = "globalSettings.parallaxStrength"
        static let menuOverlayOpacity = "globalSettings.menuOverlayOpacity"
        static let showStatusIndicator = "globalSettings.showStatusIndicator"
        static let showVersionLabel = "globalSettings.showVersionLabel"
    }
    
    private enum Defaults {
        static let reduceMotion = false
        static let parallaxStrength = 0.85
        static let menuOverlayOpacity = 0.55
        static let showStatusIndicator = true
        static let showVersionLabel = true
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
    
    var effectiveParallaxStrength: CGFloat {
        reduceMotion ? 0 : CGFloat(parallaxStrength)
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
        
        if !parallaxStrength.isFinite {
            parallaxStrength = Defaults.parallaxStrength
        }
        if !menuOverlayOpacity.isFinite {
            menuOverlayOpacity = Defaults.menuOverlayOpacity
        }
        
        parallaxStrength = min(max(parallaxStrength, 0), 1)
        menuOverlayOpacity = min(max(menuOverlayOpacity, 0.35), 0.8)
        
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
