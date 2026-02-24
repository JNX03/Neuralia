import SwiftUI
import Foundation

// MARK: - 16:9 Stage Wrapper (Letterbox) with Responsive Support
struct Stage16x9<Content: View>: View {
    private let content: (CGSize, ResponsiveLayout) -> Content
    
    init(@ViewBuilder content: @escaping (CGSize, ResponsiveLayout) -> Content) {
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let layout = ResponsiveLayout(
                width: geo.size.width,
                height: geo.size.height,
                safeAreaInsets: geo.safeAreaInsets
            )
            
            let screen = geo.size
            let targetRatio: CGFloat = 16.0 / 9.0
            
            // Responsive stage sizing - larger on big screens
            let stageWidth = min(screen.width, screen.height * targetRatio)
            let stageHeight = stageWidth / targetRatio
            let stageSize = CGSize(width: stageWidth, height: stageHeight)
            
            ZStack {
                Color.black.ignoresSafeArea()
                content(stageSize, layout)
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
    @Published var imageScale: CGFloat = 1.08
    
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
        imageScale = 1.08
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
        imageScale = 1.06
        withAnimation(.easeOut(duration: 0.75)) { imageOpacity = 1.0 }
        
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
                let startScale = CGFloat.random(in: 1.05...1.10)
                let endScale = CGFloat.random(in: 1.13...1.18)
                
                panOffset = start
                imageScale = startScale
                
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: stayDuration)) {
                    panOffset = end
                    imageScale = endScale
                }
                
                await sleepSeconds(stayDuration)
                if Task.isCancelled { return }
                
                withAnimation(.easeInOut(duration: 0.5)) { imageOpacity = 0.0 }
                await sleepSeconds(0.5)
                if Task.isCancelled { return }
                
                let nextIndex = (currentImageIndex + 1) % backgroundImages.count
                currentImageIndex = nextIndex
                panLeftToRight.toggle()
                
                panOffset = panLeftToRight ? -90 : 90
                imageScale = CGFloat.random(in: 1.05...1.09)
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

// MARK: - Loading View with Responsive Layout
struct LoadingView: View {
    @StateObject private var vm = LoadingViewModel()
    
    var onStart: () -> Void = {}
    private let versionString = "Ver: 1.19.182"
    @State private var hasStarted = false

    var body: some View {
        Stage16x9 { stage, layout in
            // Responsive positioning based on stage size
            let topHUDDown = max(layout.scaled(30), stage.height * 0.08)
            let loadingBarBase = max(layout.scaled(56), stage.height * 0.14)
            let loadingBarUp = max(loadingBarBase, layout.safeAreaInsets.bottom + layout.scaled(24))
            let loadingBarMaxWidth = layout.isCompact
                ? max(0, stage.width - (layout.padding * 2))
                : min(max(layout.scaled(420), stage.width * 0.48), stage.width - (layout.padding * 2))
            let mainRaise = max(layout.scaled(80), stage.height * 0.22)
            
            // Responsive HUD sizing
            let hudIconSize = layout.hudIconSize
            let hudSide = layout.scaled(14)
            
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
                    introContent(layout: layout)
                case .loading:
                    Color.clear
                case .main:
                    mainContent(mainRaise: mainRaise, layout: layout)
                }
                
                // HUD for loading + main
                if vm.phase != .intro {
                    hudLayer(
                        topPadding: topHUDDown,
                        hudIconSize: hudIconSize,
                        hudSide: hudSide,
                        layout: layout
                    )
                }
                
                // Loading bar
                if vm.phase == .loading {
                    VStack {
                        Spacer()
                        loadingBar(layout: layout)
                            .frame(maxWidth: loadingBarMaxWidth)
                            .padding(.horizontal, layout.padding)
                            .padding(.bottom, loadingBarUp)
                            .offset(y: vm.loadingBarOffset)
                            .opacity(vm.loadingBarOpacity)
                    }
                }
            }
            .onAppear { vm.start() }
            .onDisappear { vm.cleanup() }
        }
        .onTapGesture {
            guard vm.phase == .main, !hasStarted else { return }
            hasStarted = true
            onStart()
        }
        .onDisappear {
            hasStarted = false
        }
    }

    private var slideshowBackground: some View {
        Group {
            if vm.backgroundImages.indices.contains(vm.currentImageIndex) {
                Image(vm.backgroundImages[vm.currentImageIndex])
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(vm.imageScale)
                    .offset(x: vm.panOffset)
                    .opacity(vm.imageOpacity)
                
                LinearGradient(
                    colors: [
                        Color.black.opacity(vm.phase == .loading ? 0.18 : 0.26),
                        Color.black.opacity(0.10),
                        Color.black.opacity(vm.phase == .loading ? 0.52 : 0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                if vm.phase == .loading {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.black.opacity(0.70), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 76)
                        
                        Spacer()
                        
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private var loadingStatusText: String {
        switch vm.loadingProgress {
        case ..<0.20: return "Preparing engine"
        case ..<0.45: return "Loading assets"
        case ..<0.75: return "Streaming scene"
        case ..<0.98: return "Finalizing"
        default: return "Ready"
        }
    }
    
    private func hudLayer(
        topPadding: CGFloat,
        hudIconSize: CGFloat,
        hudSide: CGFloat,
        layout: ResponsiveLayout
    ) -> some View {
        VStack {
            HStack(alignment: .top) {
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: hudIconSize, height: hudIconSize)
                    .shadow(radius: layout.scaled(12))
                
                Spacer()
                
                Text(versionString)
                    .font(.system(size: layout.captionFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, layout.scaled(10))
                    .padding(.vertical, layout.scaled(8))
                    .background(
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .fill(Color.black.opacity(0.38))
                            .overlay(
                                RoundedRectangle(cornerRadius: layout.cornerRadius)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                    .shadow(radius: layout.scaled(8))
            }
            .padding(.leading, hudSide)
            .padding(.trailing, hudSide)
            .padding(.top, topPadding)
            
            Spacer()
        }
        .allowsHitTesting(false)
    }
    
    private func introContent(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.elementSpacing) {
            Spacer()
            
            Text(vm.displayText)
                .font(.system(size: layout.introTextSize, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, layout.padding)
                .opacity(vm.introTextOpacity)
            
            Text("PRESENT")
                .font(.system(size: layout.scaled(18), weight: .bold))
                .foregroundColor(.white)
                .tracking(layout.scaled(8))
                .opacity(vm.presentOpacity)
            
            Spacer()
            
            TimelineView(.animation(minimumInterval: 0.35)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let dots = String(repeating: ".", count: Int(t * 2).quotientAndRemainder(dividingBy: 4).remainder)
                Text("010101  LOADING\(dots)")
                    .font(.system(size: layout.captionFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, layout.padding)
            }
        }
    }
    
    private func loadingBar(layout: ResponsiveLayout) -> some View {
        let normalizedProgress = min(max(vm.loadingProgress, 0), 1)
        let currentPercent = Int(normalizedProgress * 100)
        let slideCount = max(1, vm.backgroundImages.count)
        let slideIndex = min(vm.currentImageIndex + 1, slideCount)
        
        return VStack(alignment: .leading, spacing: layout.scaled(8)) {
            loadingHeader(
                layout: layout,
                currentPercent: currentPercent,
                slideIndex: slideIndex,
                slideCount: slideCount
            )
            loadingProgressTrack(layout: layout, progress: normalizedProgress)
            loadingFooter(layout: layout)
        }
        .padding(.horizontal, layout.scaled(12))
        .padding(.vertical, layout.scaled(10))
        .background(
            RoundedRectangle(cornerRadius: max(layout.scaled(12), 12), style: .continuous)
                .fill(Color.black.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: max(layout.scaled(12), 12), style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: max(layout.scaled(12), 12), style: .continuous)
                .stroke(
                    Color.white.opacity(0.04),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.34), radius: layout.scaled(10), y: layout.scaled(6))
    }

    private func loadingHeader(
        layout: ResponsiveLayout,
        currentPercent: Int,
        slideIndex: Int,
        slideCount: Int
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: layout.scaled(10)) {
            VStack(alignment: .leading, spacing: layout.scaled(1)) {
                Text("Loading")
                    .font(.system(size: layout.bodyFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.96))

                Text("Showcase \(slideIndex) / \(slideCount)")
                    .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                    .foregroundColor(.white.opacity(0.52))
            }

            Spacer(minLength: layout.scaled(8))

            Text("\(currentPercent)%")
                .font(.system(size: layout.bodyFontSize + 3, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.95))
        }
    }

    private func loadingFooter(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.scaled(8)) {
            loadingStatusTicker(layout: layout)
            
            Spacer(minLength: layout.scaled(8))
            
            Text("NEURA")
                .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .semibold))
                .foregroundColor(.white.opacity(0.34))
        }
    }

    private func loadingStatusTicker(layout: ResponsiveLayout) -> some View {
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let step = Int(timeline.date.timeIntervalSinceReferenceDate * 2)
            let dots = String(repeating: ".", count: step % 4)
            Text("\(loadingStatusText)\(dots)")
                .font(.system(size: max(layout.captionFontSize - 1, 10), weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func loadingProgressTrack(layout: ResponsiveLayout, progress: CGFloat) -> some View {
        GeometryReader { geo in
            let barWidth = max(0, geo.size.width * progress)
            let barCorner = max(layout.scaled(3), 3)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                if barWidth > 0 {
                    RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.92),
                                    Color(red: 0.76, green: 0.90, blue: 0.97),
                                    Color(red: 0.63, green: 0.85, blue: 0.94)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(layout.scaled(6), barWidth))
                        .shadow(color: Color.cyan.opacity(0.12), radius: layout.scaled(4))
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: barCorner, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.18), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .overlay(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: layout.scaled(2), style: .continuous)
                                .fill(Color.white.opacity(0.70))
                                .frame(width: 1.5, height: layout.scaled(8))
                                .padding(.trailing, layout.scaled(2))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: barCorner, style: .continuous))
                }

                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { index in
                        Color.clear
                            .frame(maxWidth: .infinity)
                        if index < 11 {
                            Rectangle()
                                .fill(Color.white.opacity(0.035))
                                .frame(width: 1)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(height: max(layout.scaled(8), 8))
    }
    
    private func mainContent(mainRaise: CGFloat, layout: ResponsiveLayout) -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: layout.elementSpacing) {
                Text("TOUCH TO START")
                    .font(.system(size: layout.touchToStartSize, weight: .bold))
                    .tracking(layout.scaled(3))
                    .foregroundColor(.white)
                    .padding(.horizontal, layout.scaled(30))
                    .padding(.vertical, layout.scaled(10))
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                    )
                
                Text("made with love by chawabhon netisingha")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .opacity(vm.touchToStartOpacity)
            .padding(.bottom, mainRaise)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LoadingView()
        .preferredColorScheme(.dark)
}
