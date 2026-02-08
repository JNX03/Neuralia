import SwiftUI

// MARK: - Model (must be visible to LoadingView.swift)
struct PointerRipple: Identifiable, Equatable {
    let id: UUID
    let location: CGPoint
}

// MARK: - Overlay
struct PointerFXOverlay: View {
    let location: CGPoint
    let isDown: Bool
    let isVisible: Bool
    let ripples: [PointerRipple]
    let trailPoints: [CGPoint]
    
    // ✅ Default makes it backwards-compatible (no error if you forget to pass trailPoints)
    init(
        location: CGPoint,
        isDown: Bool,
        isVisible: Bool,
        ripples: [PointerRipple],
        trailPoints: [CGPoint] = []
    ) {
        self.location = location
        self.isDown = isDown
        self.isVisible = isVisible
        self.ripples = ripples
        self.trailPoints = trailPoints
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            
            // ✅ Trail (line follow drag)
            if trailPoints.count > 1 {
                BlueArchiveTrailFX(points: trailPoints, isDown: isDown)
            }
            
            // ✅ Multiple ripples
            ForEach(ripples) { r in
                BlueArchiveRippleFX()
                    .position(r.location)
            }
            
            // Cursor
            if isVisible {
                BlueArchiveCursorFX(isDown: isDown)
                    .position(location)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

// MARK: - Trail
private struct BlueArchiveTrailFX: View {
    let points: [CGPoint]
    let isDown: Bool
    
    private var neonGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.85),
                .cyan.opacity(0.85),
                .blue.opacity(0.75)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for p in points.dropFirst() {
                path.addLine(to: p)
            }
        }
        .stroke(
            neonGradient,
            style: StrokeStyle(
                lineWidth: isDown ? 4.2 : 3.2,
                lineCap: .round,
                lineJoin: .round
            )
        )
        .shadow(color: .cyan.opacity(0.55), radius: 12)
        .shadow(color: .blue.opacity(0.35), radius: 18)
        .blendMode(.plusLighter)
        .opacity(isDown ? 0.95 : 0.75)
    }
}

// MARK: - Cursor (neon)
private struct BlueArchiveCursorFX: View {
    let isDown: Bool
    
    private var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                .white.opacity(0.95),
                .cyan.opacity(0.90),
                .blue.opacity(0.90),
                .cyan.opacity(0.90),
                .white.opacity(0.95)
            ]),
            center: .center
        )
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(ringGradient, lineWidth: isDown ? 2.0 : 2.2)
                .frame(width: isDown ? 18 : 22, height: isDown ? 18 : 22)
                .shadow(color: .cyan.opacity(0.65), radius: 10)
                .shadow(color: .blue.opacity(0.45), radius: 14)
                .blendMode(.plusLighter)
            
            Circle()
                .fill(.white.opacity(isDown ? 0.22 : 0.14))
                .frame(width: isDown ? 10 : 8, height: isDown ? 10 : 8)
                .overlay(
                    Circle()
                        .fill(.cyan.opacity(0.25))
                        .blur(radius: 3)
                )
                .blendMode(.plusLighter)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isDown)
    }
}

// MARK: - Ripple
private struct BlueArchiveRippleFX: View {
    @State private var animate = false
    
    private var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                .white.opacity(0.95),
                .cyan.opacity(0.85),
                .blue.opacity(0.80),
                .cyan.opacity(0.85),
                .white.opacity(0.95)
            ]),
            center: .center
        )
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(ringGradient, lineWidth: animate ? 0.8 : 2.2)
                .frame(width: 18, height: 18)
                .scaleEffect(animate ? 5.4 : 0.35)
                .opacity(animate ? 0.0 : 0.95)
                .shadow(color: .cyan.opacity(0.55), radius: 14)
                .shadow(color: .blue.opacity(0.35), radius: 18)
                .blendMode(.plusLighter)
            
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 18, height: 18)
                .scaleEffect(animate ? 3.2 : 0.6)
                .opacity(animate ? 0.0 : 0.6)
                .blur(radius: 8)
                .blendMode(.plusLighter)
        }
        .onAppear {
            animate = false
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.8)) {
                    animate = true
                }
            }
        }
    }
}
