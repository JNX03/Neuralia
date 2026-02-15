import SwiftUI

// MARK: - Responsive Layout Engine (Shared)
struct ResponsiveLayout {
    let width: CGFloat
    let height: CGFloat
    let safeAreaInsets: EdgeInsets
    
    // MARK: - Device Categories
    var isCompact: Bool { width < 400 }
    var isRegular: Bool { width >= 400 && width < 768 }
    var isLarge: Bool { width >= 768 && width < 1200 }
    var isExtraLarge: Bool { width >= 1200 }
    
    var isLandscape: Bool { width > height }
    var isPortrait: Bool { width <= height }
    
    // MARK: - Aspect Ratio Categories
    var isUltrawide: Bool { width / height > 2.0 }
    var isCinema: Bool { width / height > 1.8 }
    
    // MARK: - Scale Factor (for sizing elements proportionally)
    var scaleFactor: CGFloat {
        switch true {
        case isCompact: return 0.85
        case isRegular: return 1.0
        case isLarge: return 1.15
        case isExtraLarge: return 1.3
        default: return 1.0
        }
    }
    
    // MARK: - Typography Scale
    func scaled(_ size: CGFloat) -> CGFloat {
        return size * scaleFactor
    }
    
    var titleFontSize: CGFloat {
        switch true {
        case isCompact: return 24
        case isRegular: return 28
        case isLarge: return 32
        case isExtraLarge: return 36
        default: return 28
        }
    }
    
    var headlineFontSize: CGFloat {
        switch true {
        case isCompact: return 18
        case isRegular: return 20
        case isLarge: return 24
        case isExtraLarge: return 28
        default: return 20
        }
    }
    
    var bodyFontSize: CGFloat {
        switch true {
        case isCompact: return 14
        case isRegular: return 16
        case isLarge: return 18
        case isExtraLarge: return 20
        default: return 16
        }
    }
    
    var captionFontSize: CGFloat {
        switch true {
        case isCompact: return 11
        case isRegular: return 12
        case isLarge: return 14
        case isExtraLarge: return 16
        default: return 12
        }
    }
    
    // MARK: - Spacing
    var padding: CGFloat {
        switch true {
        case isCompact: return 16
        case isRegular: return 20
        case isLarge: return 28
        case isExtraLarge: return 36
        default: return 20
        }
    }
    
    var sectionSpacing: CGFloat {
        switch true {
        case isCompact: return 12
        case isRegular: return 16
        case isLarge: return 24
        case isExtraLarge: return 32
        default: return 16
        }
    }
    
    var elementSpacing: CGFloat {
        switch true {
        case isCompact: return 8
        case isRegular: return 10
        case isLarge: return 14
        case isExtraLarge: return 18
        default: return 10
        }
    }
    
    // MARK: - Component Sizes
    var buttonHeight: CGFloat {
        switch true {
        case isCompact: return 44
        case isRegular: return 50
        case isLarge: return 56
        case isExtraLarge: return 64
        default: return 50
        }
    }
    
    var iconSize: CGFloat {
        switch true {
        case isCompact: return 20
        case isRegular: return 24
        case isLarge: return 28
        case isExtraLarge: return 32
        default: return 24
        }
    }
    
    var cornerRadius: CGFloat {
        switch true {
        case isCompact: return 12
        case isRegular: return 16
        case isLarge: return 20
        case isExtraLarge: return 24
        default: return 16
        }
    }
    
    // MARK: - Menu Specific
    var menuWidth: CGFloat {
        switch true {
        case isCompact: return min(width - 32, 320)
        case isRegular: return min(width - 48, 360)
        case isLarge: return isLandscape ? 380 : min(width - 64, 420)
        case isExtraLarge: return isLandscape ? 420 : 400
        default: return 320
        }
    }
    
    var menuIconSize: CGFloat {
        switch true {
        case isCompact: return 100
        case isRegular: return 140
        case isLarge: return 180
        case isExtraLarge: return 220
        default: return 140
        }
    }
    
    // MARK: - Loading View Specific
    var introTextSize: CGFloat {
        switch true {
        case isCompact: return 20
        case isRegular: return 28
        case isLarge: return 32
        case isExtraLarge: return 38
        default: return 28
        }
    }
    
    var touchToStartSize: CGFloat {
        switch true {
        case isCompact: return 16
        case isRegular: return 20
        case isLarge: return 24
        case isExtraLarge: return 28
        default: return 20
        }
    }
    
    var hudIconSize: CGFloat {
        switch true {
        case isCompact: return 120
        case isRegular: return 180
        case isLarge: return 220
        case isExtraLarge: return 280
        default: return 180
        }
    }
    
    // MARK: - Content Container
    var contentMaxWidth: CGFloat {
        switch true {
        case isCompact: return width - 32
        case isRegular: return min(width - 48, 600)
        case isLarge: return min(width - 64, 800)
        case isExtraLarge: return min(width - 80, 1000)
        default: return 600
        }
    }
    
    // MARK: - Layout Mode
    enum LayoutMode {
        case compact      // Phone portrait
        case regular      // Phone landscape / small tablet
        case expanded     // iPad / large screen
        case desktop      // Mac / ultrawide
    }
    
    var layoutMode: LayoutMode {
        switch true {
        case isCompact: return .compact
        case isRegular: return .regular
        case isLarge: return .expanded
        case isExtraLarge: return .desktop
        default: return .regular
        }
    }
}

// MARK: - View Extension for Responsive Layout
extension View {
    func responsiveLayout(_ geometry: GeometryProxy) -> ResponsiveLayout {
        ResponsiveLayout(
            width: geometry.size.width,
            height: geometry.size.height,
            safeAreaInsets: geometry.safeAreaInsets
        )
    }
}

// MARK: - Responsive Font Modifier
struct ResponsiveFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let layout: ResponsiveLayout
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: layout.scaled(size), weight: weight))
    }
}

extension View {
    func responsiveFont(size: CGFloat, weight: Font.Weight = .regular, layout: ResponsiveLayout) -> some View {
        modifier(ResponsiveFont(size: size, weight: weight, layout: layout))
    }
}

// MARK: - Responsive Padding Modifier
struct ResponsivePadding: ViewModifier {
    let edges: Edge.Set
    let length: CGFloat?
    let layout: ResponsiveLayout
    
    func body(content: Content) -> some View {
        if let length = length {
            content.padding(edges, layout.scaled(length))
        } else {
            content.padding(edges, layout.padding)
        }
    }
}

extension View {
    func responsivePadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil, layout: ResponsiveLayout) -> some View {
        modifier(ResponsivePadding(edges: edges, length: length, layout: layout))
    }
}
