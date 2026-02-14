import SwiftUI
import Foundation

// MARK: - 16:9 Stage Wrapper (Letterbox)
struct Stage16x9<Content: View>: View {
    private let content: (CGSize) -> Content
    
    init(@ViewBuilder content: @escaping (CGSize) -> Content) {
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            let targetRatio: CGFloat = 16.0 / 9.0
            
            let stageWidth = min(screen.width, screen.height * targetRatio)
            let stageHeight = stageWidth / targetRatio
            let stageSize = CGSize(width: stageWidth, height: stageHeight)
            
            ZStack {
                Color.black.ignoresSafeArea()
                content(stageSize)
                    .frame(width: stageWidth, height: stageHeight)
                    .clipped()
                    .background(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - ViewModel
@MainActor
final class LoadingViewModel: ObservableObject {
    enum Phase { case intro, loading, main }
    
    @Published var phase: Phase = .intro
    
    // Intro
    @Published var displayText: String = ""
    @Published var introTextOpacity: Double = 0.0
    @Published var presentOpacity: Double = 0.0
    
    // Slideshow
    @Published var currentImageIndex: Int = 0
    @Published var imageOpacity: Double = 0.0
    @Published var panOffset: CGFloat = 0.0
    
    // Loading bar
    @Published var loadingProgress: CGFloat = 0.0
    @Published var loadingBarOffset: CGFloat = 0.0
    @Published var loadingBarOpacity: Double = 1.0
    
    // Main
    @Published var touchToStartOpacity: Double = 0.0
    
    let targetText = "Jnx03 Swift Student Challenge 2026"
    let randomChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    let backgroundImages = ["lantassc", "507room", "cnxaqu", "cnxgate", "redbus", "schooltopview"]
    
    private var sequenceTask: Task<Void, Never>?
    private var slideshowTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    
    private var panLeftToRight = true
    
    func start() {
        cleanup()
        resetUI()
        
        sequenceTask = Task { @MainActor in
            phase = .intro
            withAnimation(.easeIn(duration: 0.35)) { introTextOpacity = 1.0 }
            
            await randomTextPhase(duration: 0.5, tick: 0.05)
            await formTextPhase(tick: 0.06)
            
            await sleepSeconds(0.6)
            withAnimation(.easeIn(duration: 0.6)) { presentOpacity = 1.0 }
            
            await sleepSeconds(1.0)
            startLoading()
        }
    }
    
    func cleanup() {
        sequenceTask?.cancel(); sequenceTask = nil
        slideshowTask?.cancel(); slideshowTask = nil
        loadingTask?.cancel(); loadingTask = nil
    }
    
    private func resetUI() {
        phase = .intro
        displayText = ""
        introTextOpacity = 0.0
        presentOpacity = 0.0
        
        currentImageIndex = 0
        imageOpacity = 0.0
        panOffset = 0.0
        panLeftToRight = true
        
        loadingProgress = 0.0
        loadingBarOffset = 0.0
        loadingBarOpacity = 1.0
        
        touchToStartOpacity = 0.0
    }
    
    private func randomTextPhase(duration: TimeInterval, tick: TimeInterval) async {
        let targetLength = targetText.count
        let steps = max(1, Int(duration / tick))
        
        for _ in 0..<steps {
            if Task.isCancelled { return }
            displayText = String((0..<targetLength).map { _ in randomChars.randomElement() ?? "X" })
            await sleepSeconds(tick)
        }
    }
    
    private func formTextPhase(tick: TimeInterval) async {
        let chars = Array(targetText)
        let total = chars.count
        
        for idx in 0..<total {
            if Task.isCancelled { return }
            var out = ""
            out.reserveCapacity(total)
            
            for i in 0..<total {
                if i <= idx { out.append(chars[i]) }
                else { out.append(randomChars.randomElement() ?? "X") }
            }
            
            displayText = out
            await sleepSeconds(tick)
        }
        
        displayText = targetText
    }
    
    private func startLoading() {
        phase = .loading
        panOffset = panLeftToRight ? -90 : 90
        withAnimation(.easeIn(duration: 0.6)) { imageOpacity = 1.0 }
        
        startSlideshowLoop()
        startLoadingBar(duration: 5.0)
    }
    
    private func startSlideshowLoop() {
        slideshowTask?.cancel()
        
        slideshowTask = Task { @MainActor in
            while !Task.isCancelled {
                guard !Task.isCancelled else { return }
                
                let stayDuration = Double.random(in: 5.0...7.0)
                
                let start: CGFloat = panLeftToRight ? -90 : 90
                let end: CGFloat = panLeftToRight ? 90 : -90
                
                panOffset = start
                
                // Check cancellation before animation
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: stayDuration)) { panOffset = end }
                
                await sleepSeconds(stayDuration)
                if Task.isCancelled { return }
                
                withAnimation(.easeInOut(duration: 0.5)) { imageOpacity = 0.0 }
                await sleepSeconds(0.5)
                if Task.isCancelled { return }
                
                // Safely update index
                let nextIndex = (currentImageIndex + 1) % backgroundImages.count
                currentImageIndex = nextIndex
                panLeftToRight.toggle()
                
                panOffset = panLeftToRight ? -90 : 90
                withAnimation(.easeInOut(duration: 0.5)) { imageOpacity = 1.0 }
            }
        }
    }
    
    private func startLoadingBar(duration: TimeInterval) {
        loadingTask?.cancel()
        
        loadingTask = Task { @MainActor in
            let tick: TimeInterval = 0.02
            let steps = max(1, Int(duration / tick))
            
            for step in 0...steps {
                if Task.isCancelled { return }
                let value = CGFloat(Double(step) / Double(steps))
                withAnimation(.linear(duration: tick)) { loadingProgress = value }
                await sleepSeconds(tick)
            }
            
            withAnimation(.easeIn(duration: 0.40)) {
                loadingBarOffset = 190
                loadingBarOpacity = 0.0
            }
            
            await sleepSeconds(0.40)
            if Task.isCancelled { return }
            
            phase = .main
            withAnimation(.easeIn(duration: 0.6)) { touchToStartOpacity = 1.0 }
        }
    }
    
    private func sleepSeconds(_ seconds: TimeInterval) async {
        let ns = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
    }
}

// MARK: - Pro Boot Background (Crash-safe)
struct ProBootBackground: View {
    var body: some View {
        ZStack {
            BinaryField()
            Scanlines()
            Vignette()
            TerminalLogOverlay()
        }
    }
    
    private struct BinaryField: View {
        var body: some View {
            TimelineView(.animation(minimumInterval: 0.16)) { timeline in
                GeometryReader { geo in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let cols = max(26, Int(geo.size.width / 14))
                    let rows = max(16, Int(geo.size.height / 20))
                    let seed = Int((t.truncatingRemainder(dividingBy: 10_000)) * 100)
                    
                    Text(binaryBlock(rows: rows, cols: cols, seed: seed))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.green.opacity(0.16))
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(y: CGFloat((t * 16).truncatingRemainder(dividingBy: 34)) - 17)
                }
            }
        }
        
        private func binaryBlock(rows: Int, cols: Int, seed: Int) -> String {
            var out = ""
            out.reserveCapacity(rows * (cols + 1))
            for r in 0..<rows {
                for c in 0..<cols {
                    let v = ((seed &* 31) ^ (r &* 97) ^ (c &* 131)) & 1
                    out.append(v == 0 ? "0" : "1")
                }
                if r != rows - 1 { out.append("\n") }
            }
            return out
        }
    }
    
    private struct Scanlines: View {
        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.00), location: 0.00),
                        .init(color: .white.opacity(0.05), location: 0.48),
                        .init(color: .white.opacity(0.00), location: 0.52),
                        .init(color: .white.opacity(0.00), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
                .opacity(0.33)
                .offset(y: CGFloat((t * 70).truncatingRemainder(dividingBy: 220)) - 110)
            }
        }
    }
    
    private struct Vignette: View {
        var body: some View {
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.80)],
                center: .center,
                startRadius: 120,
                endRadius: 900
            )
        }
    }
    
    private struct TerminalLogOverlay: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("BOOT SEQUENCE // 010101")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                
                TimelineView(.animation(minimumInterval: 0.18)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line(t, 0))
                        Text(line(t, 1))
                        Text(line(t, 2))
                        Text(line(t, 3))
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.40))
                }
                
                Spacer()
            }
            .padding(.leading, 18)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        
        private func line(_ t: TimeInterval, _ i: Int) -> String {
            let k64 = Int64(t * 6) &+ Int64(i * 7)
            let k = UInt32(truncatingIfNeeded: k64)
            let hash: UInt32 = k &* 2654435761
            let hex = String(hash, radix: 16, uppercase: true).leftPad(to: 8, with: "0")
            
            switch Int(k % 6) {
            case 0: return "[OK]  init.kernel(0x\(hex))"
            case 1: return "[OK]  load.modules(0x\(hex))"
            case 2: return "[..]  compile.graph(0x\(hex))"
            case 3: return "[OK]  mount.cache(0x\(hex))"
            case 4: return "[..]  verify.sign(0x\(hex))"
            default: return "[OK]  bootstrap.ui(0x\(hex))"
            }
        }
    }
}

private extension String {
    func leftPad(to length: Int, with char: Character) -> String {
        if count >= length { return self }
        return String(repeating: String(char), count: length - count) + self
    }
}

// MARK: - LoadingView (16:9 + Pointer FX + Touch Anywhere in Main)
struct LoadingView: View {
    @StateObject private var vm = LoadingViewModel()
    
    var onStart: () -> Void = {}
    private let versionString = "Ver: 1.19.182"
    
    // sizes
    private let hudIconSize: CGFloat = 220
    private let hudSide: CGFloat = 18
    
    // Pointer / touch FX
    @State private var pointerLocation: CGPoint = .zero
    @State private var pointerIsVisible: Bool = false
    @State private var pointerIsDown: Bool = false
    
    @State private var ripples: [PointerRipple] = []
    @State private var trailPoints: [CGPoint] = []
    
    @State private var pointerHideTask: Task<Void, Never>?
    @State private var trailClearTask: Task<Void, Never>?
    @State private var hasStarted = false

    
    var body: some View {
        ZStack {
            Stage16x9 { stage in
                // move UI away from top/bottom edges inside the 16:9 stage
                let topHUDDown = max(40, stage.height * 0.10)
                let loadingBarUp = max(28, stage.height * 0.06)
                let mainRaise = max(120, stage.height * 0.26)
                
                ZStack {
                    Color.black
                    
                    if vm.phase == .intro {
                        ProBootBackground()
                        Color.black.opacity(0.40)
                    }
                    
                    if vm.phase != .intro {
                        slideshowBackground
                    }
                    
                    switch vm.phase {
                    case .intro:
                        introContent
                    case .loading:
                        Color.clear
                    case .main:
                        mainContent(mainRaise: mainRaise)
                    }
                    
                    // HUD only for loading+main (moved DOWN)
                    if vm.phase != .intro {
                        hudLayer(topPadding: topHUDDown)
                    }
                    
                    // Loading bar only during loading (moved UP)
                    if vm.phase == .loading {
                        VStack {
                            Spacer()
                            loadingBar
                                .padding(.horizontal, 18)
                                .padding(.bottom, loadingBarUp)
                                .offset(y: vm.loadingBarOffset)
                                .opacity(vm.loadingBarOpacity)
                        }
                    }
                }
                .onAppear { vm.start() }
                .onDisappear { vm.cleanup() }
            }
            
            // FX overlay above everything (full-screen coordinates)
            PointerFXOverlay(
                location: pointerLocation,
                isDown: pointerIsDown,
                isVisible: pointerIsVisible,
                ripples: ripples,
                trailPoints: trailPoints
            )
        }
        .coordinateSpace(name: "screen")
        .simultaneousGesture(pointerGesture)
        .onDisappear {
            pointerHideTask?.cancel()
            trailClearTask?.cancel()
            pointerHideTask = nil
            trailClearTask = nil
            hasStarted = false
        }
    }
    
    private var pointerGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("screen"))
            .onChanged { value in
                // Skip if already transitioning
                guard !hasStarted else { return }
                
                pointerHideTask?.cancel()
                trailClearTask?.cancel()
                
                pointerIsVisible = true
                pointerIsDown = true
                pointerLocation = value.location
                
                // Trail tracking
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
                let isTap = dist < 16
                
                if isTap { spawnRipple(at: value.location) }
                
                // Only trigger onStart if in main phase and not already started
                if vm.phase == .main, isTap, !hasStarted {
                    hasStarted = true
                    onStart()
                }
                
                // Trail fade
                trailClearTask?.cancel()
                trailClearTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.easeOut(duration: 0.35)) {
                        trailPoints.removeAll()
                    }
                }
                
                // Cursor fade
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
        if ripples.count > 18 { ripples.removeFirst(ripples.count - 18) }
        
        let id = UUID()
        ripples.append(PointerRipple(id: id, location: point))
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 950_000_000) // longer fade
            ripples.removeAll { $0.id == id }
        }
    }

    private var slideshowBackground: some View {
        Group {
            if vm.backgroundImages.indices.contains(vm.currentImageIndex) {
                Image(vm.backgroundImages[vm.currentImageIndex])
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.15)
                    .offset(x: vm.panOffset)
                    .opacity(vm.imageOpacity)
                
                Color.black.opacity(0.35)
            }
        }
    }
    
    private func hudLayer(topPadding: CGFloat) -> some View {
        VStack {
            HStack(alignment: .top) {
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: hudIconSize, height: hudIconSize)
                    .shadow(radius: 18)
                
                Spacer()
                
                Text(versionString)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.38))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                    .shadow(radius: 10)
            }
            .padding(.leading, hudSide)
            .padding(.trailing, hudSide)
            .padding(.top, topPadding)
            
            Spacer()
        }
        .allowsHitTesting(false)
    }
    
    private var introContent: some View {
        VStack(spacing: 14) {
            Spacer()
            
            Text(vm.displayText)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .opacity(vm.introTextOpacity)
            
            Text("PRESENT")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .tracking(8)
                .opacity(vm.presentOpacity)
            
            Spacer()
            
            TimelineView(.animation(minimumInterval: 0.35)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let dots = String(repeating: ".", count: Int(t * 2).quotientAndRemainder(dividingBy: 4).remainder)
                Text("010101  LOADING\(dots)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 14)
            }
        }
    }
    
    private var loadingBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LOADING")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                
                Spacer()
                
                Text("\(Int(vm.loadingProgress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: max(8, geo.size.width * vm.loadingProgress))
                        .shadow(radius: 6)
                }
            }
            .frame(height: 12)
            
            Text("booting… 010101")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(radius: 14)
    }
    
    private func mainContent(mainRaise: CGFloat) -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Text("TOUCH TO START")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(3)
                    .foregroundColor(.white)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                    )
                
                Text("made with love by chawabhon netisingha")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .opacity(vm.touchToStartOpacity)
            .padding(.bottom, mainRaise)
        }
        .allowsHitTesting(false) // ✅ gestures handled at root (touch anywhere)
    }
}
