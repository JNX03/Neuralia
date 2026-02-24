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
                NeonTrailFX(points: trailPoints, isDown: isDown)
            }
            
            // ✅ Multiple ripples
            ForEach(ripples) { r in
                NeonRippleFX()
                    .position(r.location)
            }
            
            // Cursor
            if isVisible {
                NeonCursorFX(isDown: isDown)
                    .position(location)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

// MARK: - Trail
private struct NeonTrailFX: View {
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
private struct NeonCursorFX: View {
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
private struct NeonRippleFX: View {
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

// MARK: - Shared Gesture + Overlay Host
private struct PointerFXModifier: ViewModifier {
    @State private var pointerLocation: CGPoint = .zero
    @State private var pointerIsVisible: Bool = false
    @State private var pointerIsDown: Bool = false
    @State private var ripples: [PointerRipple] = []
    @State private var trailPoints: [CGPoint] = []
    @State private var pointerHideTask: Task<Void, Never>?
    @State private var trailClearTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay {
                PointerFXOverlay(
                    location: pointerLocation,
                    isDown: pointerIsDown,
                    isVisible: pointerIsVisible,
                    ripples: ripples,
                    trailPoints: trailPoints
                )
            }
            .simultaneousGesture(pointerGesture)
            .onDisappear {
                pointerHideTask?.cancel()
                trailClearTask?.cancel()
                pointerHideTask = nil
                trailClearTask = nil
                pointerIsVisible = false
                pointerIsDown = false
                trailPoints.removeAll()
            }
    }

    private var pointerGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                pointerHideTask?.cancel()
                trailClearTask?.cancel()

                pointerIsVisible = true
                pointerIsDown = true
                pointerLocation = value.location

                let p = value.location
                if let last = trailPoints.last {
                    let d = hypot(p.x - last.x, p.y - last.y)
                    if d > 3.0 {
                        trailPoints.append(p)
                    }
                } else {
                    trailPoints = [p]
                }

                if trailPoints.count > 18 {
                    trailPoints.removeFirst(trailPoints.count - 18)
                }
            }
            .onEnded { value in
                pointerLocation = value.location
                pointerIsDown = false

                let dist = hypot(value.translation.width, value.translation.height)
                if dist < 16 {
                    spawnRipple(at: value.location)
                }

                trailClearTask?.cancel()
                trailClearTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.easeOut(duration: 0.35)) {
                        trailPoints.removeAll()
                    }
                }

                pointerHideTask?.cancel()
                pointerHideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    withAnimation(.easeOut(duration: 0.35)) {
                        pointerIsVisible = false
                    }
                }
            }
    }

    private func spawnRipple(at point: CGPoint) {
        if ripples.count > 18 {
            ripples.removeFirst(ripples.count - 18)
        }

        let id = UUID()
        ripples.append(PointerRipple(id: id, location: point))

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 950_000_000)
            ripples.removeAll { $0.id == id }
        }
    }
}

extension View {
    func neuraPointerFX() -> some View {
        modifier(PointerFXModifier())
    }
}
