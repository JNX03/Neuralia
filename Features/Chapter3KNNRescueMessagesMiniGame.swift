import SwiftUI

// MARK: - KNN Data Point (for scatter plot visualization)
struct KNNDataPoint: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let x: Double
    let y: Double
    let emoji: String
    
    static func == (lhs: KNNDataPoint, rhs: KNNDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Training Chat Message
struct TrainingChatMessage: Identifiable, Equatable {
    static func == (lhs: TrainingChatMessage, rhs: TrainingChatMessage) -> Bool { lhs.id == rhs.id }
    
    let id = UUID()
    let text: String
    let isUser: Bool
    let image: UIImage?
    let predictionLabel: String?
    let confidence: Double?
    let isCorrect: Bool?
    let errorCode: String?
    let timestamp: Date
    
    init(text: String, isUser: Bool, image: UIImage? = nil, predictionLabel: String? = nil, confidence: Double? = nil, isCorrect: Bool? = nil, errorCode: String? = nil) {
        self.text = text
        self.isUser = isUser
        self.image = image
        self.predictionLabel = predictionLabel
        self.confidence = confidence
        self.isCorrect = isCorrect
        self.errorCode = errorCode
        self.timestamp = Date()
    }
}

// MARK: - Main MiniGame View
@MainActor
struct Chapter3KNNRescueMessagesMiniGame: View {
    let minigame: Chapter3KNNRescueMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void
    
    // Game phases
    enum GamePhase: Int, CaseIterable {
        case collect = 0, train = 1, test = 2, complete = 3
    }
    
    @State private var phase: GamePhase = .collect
    @State private var mode: Chapter3KNNRescueMode = .photo
    
    // Training data
    @State private var trainingData: [KNNDataPoint] = []
    @State private var selectedLabel: String
    
    // Training animation
    @State private var isTraining = false
    @State private var trainingProgress: Double = 0
    @State private var trainingTask: Task<Void, Never>?
    
    // Testing state
    @State private var testQueue: [KNNDataPoint] = []
    @State private var currentTest: KNNDataPoint?
    @State private var nearestNeighbors: [(point: KNNDataPoint, distance: Double)] = []
    @State private var userAnswer: String?
    @State private var knnAnswer: String?
    @State private var showResult = false
    @State private var correctCount = 0
    @State private var totalTests = 0
    @State private var showNeighborLines = false
    
    // Chat
    @State private var chatMessages: [TrainingChatMessage] = []
    @State private var didInitializeChat = false
    @State private var didComplete = false
    
    // Drawing fallback states
    @StateObject private var drawKNN = KNNClassifier()
    @State private var fallbackStrokes: [[CGPoint]] = []
    @State private var fallbackCurrentStroke: [CGPoint] = []
    @State private var fallbackCanvasSize: CGSize = .zero
    @State private var fallbackPrompt = "1"
    @State private var fallbackPrediction: (label: String, confidence: Double)?
    @State private var fallbackIsCorrect: Bool?
    @State private var drawCorrectCount = 0
    @State private var didLoadFallbackTemplates = false
    @State private var showDrawingResult = false
    
    // AI Name
    private var aiName: String {
        GlobalSettingsStore.shared.aiDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "Ploy" 
            : GlobalSettingsStore.shared.aiDisplayName
    }
    
    init(minigame: Chapter3KNNRescueMiniGame, layout: DialogAdaptiveLayout, isCompleted: Bool, onComplete: @escaping (String) -> Void) {
        self.minigame = minigame
        self.layout = layout
        self.isCompleted = isCompleted
        self.onComplete = onComplete
        _selectedLabel = State(initialValue: minigame.trainingLabels.first ?? "Pen")
    }
    
    // MARK: - Computed Properties
    
    private var labelEmojis: [String: String] {
        [
            "Pen": "✏️",
            "Hand": "✋",
            "Bottle": "🧴"
        ]
    }
    
    private var labelColors: [String: Color] {
        [
            "Pen": Color(hex: "3B82F6"),
            "Hand": Color(hex: "F59E0B"),
            "Bottle": Color(hex: "10B981")
        ]
    }
    
    // Cluster centers for scatter plot
    private var clusterCenters: [String: (x: Double, y: Double)] {
        [
            "Pen": (0.2, 0.25),
            "Hand": (0.75, 0.3),
            "Bottle": (0.45, 0.78)
        ]
    }
    
    private var sampleCount: [String: Int] {
        var counts: [String: Int] = [:]
        for label in minigame.trainingLabels {
            counts[label] = trainingData.filter { $0.label == label }.count
        }
        return counts
    }
    
    private var hasMinimumSamples: Bool {
        minigame.trainingLabels.allSatisfy { label in
            (sampleCount[label] ?? 0) >= 1
        }
    }
    
    private var rescuePassed: Bool {
        correctCount >= minigame.requiredCorrectTests || drawCorrectCount >= minigame.requiredCorrectTests
    }
    
    // MARK: - Layout
    
    private var stageMaxWidth: CGFloat {
        min(layout.width - (layout.isCompact ? 16 : 28), layout.isCompact ? 760 : 1500)
    }
    private var centerPanelMaxWidth: CGFloat {
        switch true {
        case layout.width < 700: return min(layout.width - 28, 700)
        case layout.width < 1100: return min(layout.width * 0.68, 780)
        default: return min(layout.width * 0.50, 840)
        }
    }
    private var spriteHeight: CGFloat {
        let lo: CGFloat = layout.isCompact ? 140 : 200
        let hi: CGFloat = layout.isCompact ? 250 : 420
        return min(max(layout.height * (layout.isCompact ? 0.22 : 0.34), lo), hi)
    }
    private var bottomDialogReserve: CGFloat {
        layout.isCompact ? 170 : 200
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            characterLayer
            
            VStack(spacing: 0) {
                topBar
                    .padding(.bottom, layout.isCompact ? 4 : 8)
                
                if mode == .photo {
                    stepIndicator
                        .padding(.bottom, layout.isCompact ? 6 : 10)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    centerPanel
                        .frame(maxWidth: centerPanelMaxWidth)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: layout.height - bottomDialogReserve - (layout.isCompact ? 90 : 120))
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .top)
            
            // Bottom gradient
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.55),
                    .init(color: Color.black.opacity(0.3), location: 0.68),
                    .init(color: Color.black.opacity(0.65), location: 0.82),
                    .init(color: Color.black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .zIndex(1)
            
            bottomDialog.zIndex(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { initChat() }
        .onDisappear {
            trainingTask?.cancel()
            trainingTask = nil
        }
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepDot(0, "Collect", "tray.and.arrow.down.fill")
            stepLine(phase.rawValue >= 1)
            stepDot(1, "Train", "cpu")
            stepLine(phase.rawValue >= 2)
            stepDot(2, "Test", "checkmark.seal.fill")
        }
        .padding(.horizontal, layout.isCompact ? 20 : 40)
        .frame(maxWidth: centerPanelMaxWidth)
    }
    
    private func stepDot(_ index: Int, _ label: String, _ icon: String) -> some View {
        let active = phase.rawValue >= index
        let current = phase.rawValue == index
        return VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(active
                          ? LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: layout.isCompact ? 28 : 34, height: layout.isCompact ? 28 : 34)
                if current {
                    Circle()
                        .stroke(Color(hex: "8B5CF6").opacity(0.5), lineWidth: 2)
                        .frame(width: layout.isCompact ? 36 : 42, height: layout.isCompact ? 36 : 42)
                }
                Image(systemName: icon)
                    .font(.system(size: layout.isCompact ? 11 : 13, weight: .semibold))
                    .foregroundColor(active ? .white : .white.opacity(0.35))
            }
            Text(label)
                .font(.system(size: layout.isCompact ? 9 : 10, weight: current ? .bold : .medium))
                .foregroundColor(active ? .white : .white.opacity(0.35))
        }
    }
    
    private func stepLine(_ active: Bool) -> some View {
        Rectangle()
            .fill(active
                  ? LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)
                  : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)], startPoint: .leading, endPoint: .trailing))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, layout.isCompact ? 16 : 20)
    }
    
    // MARK: - Character Layer
    
    private var characterLayer: some View {
        ZStack(alignment: .bottom) {
            HStack {
                Image("char").resizable().scaledToFit()
                    .frame(maxHeight: spriteHeight)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .opacity(0.8)
                Spacer()
            }
            HStack {
                Spacer()
                Image("gltich").resizable().scaledToFit()
                    .frame(maxHeight: spriteHeight)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .opacity(0.8)
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, layout.isCompact ? 8 : 14)
        .padding(.bottom, max(0, bottomDialogReserve - 20))
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: layout.captionFontSize - 1, weight: .semibold))
                    .foregroundColor(rescuePassed ? Color(red: 0.13, green: 0.72, blue: 0.45) : Color(hex: "F97316"))
                Text("KNN Rescue")
                    .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            
            Text("\(trainingData.count) samples")
                .font(.system(size: layout.captionFontSize - 1, weight: .bold, design: .monospaced))
                .foregroundColor(hasMinimumSamples ? Color(hex: "34D399") : Color(hex: "FBBF24"))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill((hasMinimumSamples ? Color(hex: "34D399") : Color(hex: "FBBF24")).opacity(0.12)))
            
            Spacer()
            
            Button(action: toggleMode) {
                HStack(spacing: 4) {
                    Image(systemName: mode == .photo ? "pencil.tip" : "square.grid.2x2.fill")
                        .font(.system(size: layout.captionFontSize - 2))
                    Text(mode == .photo ? "Draw" : "Cards")
                        .font(.system(size: layout.captionFontSize - 1, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "6366F1").opacity(0.5)))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Center Panel
    
    @ViewBuilder
    private var centerPanel: some View {
        if mode == .photo {
            knnGamePanel
        } else {
            drawingFallbackPanel
        }
    }
    
    // MARK: - KNN Game Panel (main educational game)
    
    private var knnGamePanel: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            // Phase-specific content
            switch phase {
            case .collect:
                collectPhaseView
            case .train:
                trainPhaseView
            case .test:
                testPhaseView
            case .complete:
                completePhaseView
            }
        }
        .padding(layout.isCompact ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 6)
        )
    }
    
    // MARK: - Phase 1: Collect
    
    private var collectPhaseView: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "818CF8"))
                Text("Step 1: Collect Training Data")
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text("Tap items below to scan them as KNN training samples. Each item becomes a data point with features (shape, size).")
                .font(.system(size: layout.isCompact ? 11 : 12, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            
            separator
            
            // Label tabs
            HStack(spacing: 8) {
                ForEach(minigame.trainingLabels, id: \.self) { label in
                    LabelButton(
                        label: "\(labelEmojis[label] ?? "📦") \(label)",
                        count: sampleCount[label] ?? 0,
                        isSelected: selectedLabel == label
                    ) { selectedLabel = label }
                }
            }
            
            // Scannable items grid
            scanItemsGrid
            
            // Scatter plot preview
            if !trainingData.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text("Feature Space")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)
                        Spacer()
                    }
                    scatterPlot(showTest: false, width: nil, height: layout.isCompact ? 120 : 150)
                }
            }
            
            // Train button
            Button(action: startTraining) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                    Text("Train KNN (K=3)")
                        .font(.system(size: layout.isCompact ? 13 : 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, layout.isCompact ? 12 : 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(hasMinimumSamples
                              ? LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasMinimumSamples)
            
            if !hasMinimumSamples {
                Text("Need at least 1 sample per label: \(minigame.trainingLabels.joined(separator: ", "))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // Scannable items grid
    private var scanItemsGrid: some View {
        let items: [(String, String, String)] = [
            ("Pen", "✏️", "Thin, long"),
            ("Pen", "🖊️", "Dark ink"),
            ("Pen", "🖋️", "Fountain"),
            ("Hand", "✋", "Open palm"),
            ("Hand", "🤚", "Back hand"),
            ("Hand", "👋", "Waving"),
            ("Bottle", "🧴", "Squeeze"),
            ("Bottle", "🍶", "Tall"),
            ("Bottle", "🫙", "Wide jar"),
        ]
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let alreadyAdded = trainingData.contains { $0.emoji == item.1 && $0.label == item.0 }
                
                Button(action: {
                    guard !alreadyAdded else { return }
                    addTrainingSample(label: item.0, emoji: item.1)
                }) {
                    VStack(spacing: 4) {
                        Text(item.1)
                            .font(.system(size: layout.isCompact ? 26 : 32))
                        Text(item.2)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.isCompact ? 8 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(alreadyAdded
                                  ? (labelColors[item.0] ?? .blue).opacity(0.2)
                                  : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(alreadyAdded
                                            ? (labelColors[item.0] ?? .blue).opacity(0.5)
                                            : Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .opacity(alreadyAdded ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(alreadyAdded)
            }
        }
    }
    
    // MARK: - Phase 2: Train
    
    private var trainPhaseView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "818CF8"))
                    .symbolEffect(.pulse, isActive: isTraining)
                Text("Step 2: Training KNN...")
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "A78BFA")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * trainingProgress, height: 6)
                        .animation(.linear(duration: 0.1), value: trainingProgress)
                }
            }
            .frame(height: 6)
            
            separator
            
            // Scatter plot growing
            scatterPlot(showTest: false, width: nil, height: layout.isCompact ? 160 : 200)
            
            Text("Mapping \(trainingData.count) samples to feature space... \(Int(trainingProgress * 100))%")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 16) {
                ForEach(minigame.trainingLabels, id: \.self) { label in
                    HStack(spacing: 4) {
                        Circle().fill(labelColors[label] ?? .gray).frame(width: 8, height: 8)
                        Text("\(labelEmojis[label] ?? "") \(label)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }
    
    // MARK: - Phase 3: Test
    
    private var testPhaseView: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "34D399"))
                Text("Step 3: Test Your KNN")
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(correctCount)/\(minigame.requiredCorrectTests)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "34D399"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "34D399").opacity(0.15)))
            }
            
            // Signal strength bar
            signalStrengthBar
            
            separator
            
            if let test = currentTest {
                // Scatter plot with test point
                scatterPlot(showTest: true, width: nil, height: layout.isCompact ? 160 : 200)
                
                if showResult, let answer = knnAnswer {
                    // Show result
                    let isCorrect = answer == test.label
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(isCorrect ? Color(hex: "34D399") : Color(hex: "EF4444"))
                            
                            Text(isCorrect ? "Correct! KNN found: \(answer)" : "KNN said \(answer), was \(test.label)")
                                .font(.system(size: layout.isCompact ? 13 : 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        Text("K=3 nearest neighbors voted: \(nearestNeighbors.map { $0.point.label }.joined(separator: ", "))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Button(action: nextTest) {
                            Label(correctCount >= minigame.requiredCorrectTests ? "Complete Rescue!" : "Next Test →", systemImage: correctCount >= minigame.requiredCorrectTests ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(Capsule().fill(
                                    LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)
                                ))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill((isCorrect ? Color(hex: "34D399") : Color(hex: "EF4444")).opacity(0.1)))
                } else {
                    // User picks answer
                    Text("What class is the ❓ mystery point?")
                        .font(.system(size: layout.isCompact ? 12 : 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 10) {
                        ForEach(minigame.trainingLabels, id: \.self) { label in
                            Button(action: { submitAnswer(label) }) {
                                VStack(spacing: 3) {
                                    Text(labelEmojis[label] ?? "📦")
                                        .font(.system(size: layout.isCompact ? 22 : 26))
                                    Text(label)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, layout.isCompact ? 10 : 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill((labelColors[label] ?? .gray).opacity(0.3))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke((labelColors[label] ?? .gray).opacity(0.5), lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // Signal strength
    private var signalStrengthBar: some View {
        GeometryReader { geo in
            let pct = min(Double(correctCount) / Double(max(minigame.requiredCorrectTests, 1)), 1.0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)).frame(height: 10)
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "22C55E")], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * pct, height: 10)
                    .animation(.easeOut(duration: 0.5), value: correctCount)
            }
            .overlay(alignment: .trailing) {
                Text("\(Int(pct * 99.98))% signal")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.trailing, 4)
            }
        }
        .frame(height: 10)
    }
    
    // MARK: - Phase 4: Complete
    
    private var completePhaseView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: layout.isCompact ? 44 : 56))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "22C55E")], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("Signal Stabilized!")
                .font(.system(size: layout.isCompact ? 20 : 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("KNN correctly anchored the signal at 99.98%")
                .font(.system(size: layout.isCompact ? 12 : 14, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            scatterPlot(showTest: false, width: nil, height: layout.isCompact ? 100 : 130)
        }
        .padding(.vertical, layout.isCompact ? 12 : 20)
    }
    
    // MARK: - Scatter Plot
    
    private func scatterPlot(showTest: Bool, width: CGFloat?, height: CGFloat?) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Grid
                ForEach(1..<4) { i in
                    Path { p in
                        p.move(to: CGPoint(x: w * Double(i) / 4.0, y: 0))
                        p.addLine(to: CGPoint(x: w * Double(i) / 4.0, y: h))
                    }.stroke(Color.white.opacity(0.05), lineWidth: 1)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * Double(i) / 4.0))
                        p.addLine(to: CGPoint(x: w, y: h * Double(i) / 4.0))
                    }.stroke(Color.white.opacity(0.05), lineWidth: 1)
                }
                
                // Nearest neighbor lines
                if showTest, showNeighborLines, let test = currentTest {
                    ForEach(nearestNeighbors.indices, id: \.self) { i in
                        let n = nearestNeighbors[i]
                        Path { p in
                            p.move(to: CGPoint(x: test.x * w, y: test.y * h))
                            p.addLine(to: CGPoint(x: n.point.x * w, y: n.point.y * h))
                        }
                        .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }
                }
                
                // Training data points
                ForEach(trainingData) { pt in
                    Circle()
                        .fill(labelColors[pt.label] ?? .gray)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: (labelColors[pt.label] ?? .gray).opacity(0.5), radius: 4)
                        .position(x: pt.x * w, y: pt.y * h)
                }
                
                // Test point
                if showTest, let test = currentTest {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("?")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .white.opacity(0.6), radius: 6)
                        .position(x: test.x * w, y: test.y * h)
                }
            }
        }
        .frame(height: height ?? 150)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Separator
    
    private var separator: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }
    
    // MARK: - Drawing Fallback Panel (with fix)
    
    private var drawingFallbackPanel: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            HStack {
                Image(systemName: "pencil.tip.crop.circle")
                    .foregroundColor(Color(hex: "FB923C"))
                Text("Drawing Mode")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(drawCorrectCount)/\(minigame.requiredCorrectTests)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "FB923C"))
            }
            
            separator
            
            // Prompt
            VStack(spacing: 6) {
                Text("DRAW THIS NUMBER:")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
                Text(fallbackPrompt)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "FB923C").opacity(0.12)))
            }
            
            // Canvas
            DrawingCanvasView(
                strokes: $fallbackStrokes,
                currentStroke: $fallbackCurrentStroke,
                canvasSize: $fallbackCanvasSize
            )
            
            // Controls
            if showDrawingResult, let pred = fallbackPrediction {
                // Result + Next button
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: (fallbackIsCorrect == true) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor((fallbackIsCorrect == true) ? Color(hex: "34D399") : Color(hex: "EF4444"))
                        Text("Predicted: \(pred.label) (\(Int(pred.confidence * 100))%)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    Button(action: advanceDrawing) {
                        Label("Next →", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill((fallbackIsCorrect == true ? Color(hex: "34D399") : Color(hex: "EF4444")).opacity(0.1)))
            } else {
                HStack(spacing: 10) {
                    Button(action: {
                        fallbackStrokes.removeAll()
                        fallbackCurrentStroke.removeAll()
                    }) {
                        Label("Clear", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "EF4444").opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: submitDrawing) {
                        Label("Submit", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(fallbackStrokes.isEmpty ? Color.white.opacity(0.1) : Color(hex: "22C55E")))
                    }
                    .buttonStyle(.plain)
                    .disabled(fallbackStrokes.isEmpty)
                }
            }
        }
        .padding(layout.isCompact ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(
                    LinearGradient(colors: [Color(hex: "FB923C").opacity(0.2), Color(hex: "FB923C").opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1
                ))
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 6)
        )
    }
    
    // Drawing canvas
    private struct DrawingCanvasView: View {
        @Binding var strokes: [[CGPoint]]
        @Binding var currentStroke: [CGPoint]
        @Binding var canvasSize: CGSize
        
        var body: some View {
            GeometryReader { geo in
                let size = min(geo.size.width, 260)
                Canvas { ctx, _ in
                    for stroke in strokes {
                        if stroke.count > 1 {
                            var path = Path()
                            path.move(to: stroke[0])
                            for p in stroke.dropFirst() { path.addLine(to: p) }
                            ctx.stroke(path, with: .color(.white), lineWidth: 5)
                        }
                    }
                    if currentStroke.count > 1 {
                        var path = Path()
                        path.move(to: currentStroke[0])
                        for p in currentStroke.dropFirst() { path.addLine(to: p) }
                        ctx.stroke(path, with: .color(.white), lineWidth: 5)
                    }
                }
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in currentStroke.append(v.location) }
                        .onEnded { _ in
                            if !currentStroke.isEmpty { strokes.append(currentStroke) }
                            currentStroke = []
                        }
                )
                .onAppear { canvasSize = CGSize(width: size, height: size) }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 260)
        }
    }
    
    // MARK: - Bottom Dialog
    
    private var bottomDialog: some View {
        VStack(spacing: layout.isCompact ? 5 : 8) {
            Spacer()
            
            HStack(alignment: .top, spacing: layout.isCompact ? 10 : 16) {
                dialogPane("You", "Student", chatMessages.last(where: { $0.isUser })?.text ?? "Helping with the KNN rescue...", Color(hex: "60A5FA"), false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                dialogPane(aiName, "AI Friend", chatMessages.last(where: { !$0.isUser })?.text ?? "Signal breaking... need anchors...", Color(hex: "FB923C"), true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            if (isCompleted || rescuePassed) && !didComplete {
                Button(action: {
                    guard !didComplete else { return }
                    didComplete = true
                    onComplete("KNN Rescue Complete!")
                }) {
                    Label("Continue Story", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Capsule().fill(LinearGradient(colors: [Color(hex: "22C55E"), Color(hex: "16A34A")], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: Color(hex: "22C55E").opacity(0.4), radius: 8, y: 4))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity).padding(.top, 4)
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .padding(.bottom, layout.isCompact ? 72 : 94)
    }
    
    private func dialogPane(_ name: String, _ role: String, _ text: String, _ accent: Color, _ trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            HStack(spacing: 5) {
                if trailing { Spacer() }
                Text(name)
                    .font(.system(size: layout.isCompact ? 16 : 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                Text(role)
                    .font(.system(size: layout.isCompact ? 9 : 12, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                if !trailing { Spacer() }
            }
            Text(text)
                .font(.system(size: layout.isCompact ? 11 : 14, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .multilineTextAlignment(trailing ? .trailing : .leading)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
    }
    
    // MARK: - Game Logic
    
    private func addTrainingSample(label: String, emoji: String) {
        let center = clusterCenters[label] ?? (0.5, 0.5)
        let point = KNNDataPoint(
            label: label,
            x: center.x + Double.random(in: -0.1...0.1),
            y: center.y + Double.random(in: -0.1...0.1),
            emoji: emoji
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            trainingData.append(point)
        }
        addChat("Scanned \(emoji) \(label)!", isUser: true)
        addChat("Got it! Features extracted: shape=\(String(format: "%.1f", point.x)), size=\(String(format: "%.1f", point.y))", isUser: false)
    }
    
    private func startTraining() {
        guard hasMinimumSamples else { return }
        phase = .train
        isTraining = true
        trainingProgress = 0
        
        addChat("Training KNN with K=3...", isUser: true)
        addChat("Processing \(trainingData.count) samples...", isUser: false)
        
        trainingTask?.cancel()
        trainingTask = Task { @MainActor in
            var p = 0.0
            while p < 1.0 {
                try? await Task.sleep(nanoseconds: 80_000_000)
                if Task.isCancelled { return }
                p += 0.04
                trainingProgress = min(p, 1.0)
            }
            guard !Task.isCancelled else { return }
            isTraining = false
            addChat("KNN trained! Ready for testing.", isUser: false)
            generateTests()
            withAnimation(.easeOut(duration: 0.3)) { phase = .test }
        }
    }
    
    private func generateTests() {
        testQueue = []
        for label in minigame.trainingLabels {
            let center = clusterCenters[label] ?? (0.5, 0.5)
            let test = KNNDataPoint(
                label: label,
                x: center.x + Double.random(in: -0.08...0.08),
                y: center.y + Double.random(in: -0.08...0.08),
                emoji: "❓"
            )
            testQueue.append(test)
        }
        testQueue.shuffle()
        currentTest = testQueue.first
        showResult = false
        showNeighborLines = false
    }
    
    private func submitAnswer(_ answer: String) {
        guard let test = currentTest else { return }
        
        // Find K=3 nearest neighbors
        let sorted = trainingData.sorted {
            distance($0, test) < distance($1, test)
        }
        let kNearest = Array(sorted.prefix(3))
        nearestNeighbors = kNearest.map { (point: $0, distance: distance($0, test)) }
        
        // Majority vote
        var votes: [String: Int] = [:]
        for n in kNearest { votes[n.label, default: 0] += 1 }
        knnAnswer = votes.max(by: { $0.value < $1.value })?.key ?? test.label
        userAnswer = answer
        
        let isCorrect = knnAnswer == test.label
        if isCorrect { correctCount += 1 }
        totalTests += 1
        
        addChat("Is it \(answer)?", isUser: true)
        addChat(isCorrect ? "Correct! KNN's 3 nearest neighbors agree: \(knnAnswer!)." : "KNN says \(knnAnswer!). The neighbors voted differently.", isUser: false)
        
        withAnimation(.easeOut(duration: 0.3)) {
            showNeighborLines = true
            showResult = true
        }
    }
    
    private func nextTest() {
        if correctCount >= minigame.requiredCorrectTests {
            withAnimation(.easeOut(duration: 0.4)) { phase = .complete }
            addChat("Signal stabilized at 99.98%!", isUser: false)
            return
        }
        
        // Next test
        if let idx = testQueue.firstIndex(where: { $0.id == currentTest?.id }),
           idx + 1 < testQueue.count {
            currentTest = testQueue[idx + 1]
        } else {
            // Regenerate
            generateTests()
        }
        showResult = false
        showNeighborLines = false
        knnAnswer = nil
        userAnswer = nil
        nearestNeighbors = []
    }
    
    private func distance(_ a: KNNDataPoint, _ b: KNNDataPoint) -> Double {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
    
    // Drawing mode
    
    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            mode = (mode == .photo) ? .drawFallback : .photo
        }
        if mode == .drawFallback {
            addChat("Switching to drawing mode...", isUser: true)
        } else {
            addChat("Back to KNN card mode.", isUser: true)
        }
    }
    
    private func submitDrawing() {
        guard !fallbackStrokes.isEmpty, fallbackCanvasSize != .zero else { return }
        loadFallbackDigitTemplatesIfNeeded()
        
        let sample = DrawingSample.fromStrokes(fallbackStrokes, label: "test", canvasSize: fallbackCanvasSize)
        let result = drawKNN.classify(sample)
        fallbackPrediction = result
        
        let isCorrect = result.label == fallbackPrompt
        fallbackIsCorrect = isCorrect
        if isCorrect { drawCorrectCount += 1 }
        
        addChat(isCorrect ? "Correct! Drew \(fallbackPrompt)" : "Tried \(fallbackPrompt), got \(result.label)", isUser: true)
        addChat(isCorrect ? "Recognized as \(result.label)!" : "Looks like \(result.label). Try next!", isUser: false)
        
        showDrawingResult = true
        
        if drawCorrectCount >= minigame.requiredCorrectTests && !didComplete {
            didComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete("KNN Rescue Complete via Drawing!")
            }
        }
    }
    
    private func advanceDrawing() {
        fallbackStrokes.removeAll()
        fallbackCurrentStroke.removeAll()
        fallbackPrediction = nil
        fallbackIsCorrect = nil
        fallbackPrompt = randomDigit()
        showDrawingResult = false
    }
    
    private func loadFallbackDigitTemplatesIfNeeded() {
        guard !didLoadFallbackTemplates else { return }
        didLoadFallbackTemplates = true
        let canvas = CGSize(width: 260, height: 260)
        let templates: [(String, [[CGPoint]])] = [
            ("1", [[CGPoint(x: 130, y: 50), CGPoint(x: 130, y: 210)]]),
            ("1", [[CGPoint(x: 110, y: 70), CGPoint(x: 130, y: 50), CGPoint(x: 130, y: 210)]]),
            ("2", [[CGPoint(x: 80, y: 70), CGPoint(x: 140, y: 50), CGPoint(x: 180, y: 90), CGPoint(x: 80, y: 200), CGPoint(x: 180, y: 200)]]),
            ("3", [[CGPoint(x: 80, y: 60), CGPoint(x: 170, y: 60), CGPoint(x: 130, y: 130), CGPoint(x: 170, y: 200), CGPoint(x: 80, y: 200)]]),
            ("0", [[CGPoint(x: 130, y: 50), CGPoint(x: 180, y: 90), CGPoint(x: 180, y: 180), CGPoint(x: 130, y: 210), CGPoint(x: 80, y: 180), CGPoint(x: 80, y: 90), CGPoint(x: 130, y: 50)]]),
            ("4", [[CGPoint(x: 160, y: 50), CGPoint(x: 160, y: 210)], [CGPoint(x: 80, y: 140), CGPoint(x: 190, y: 140)]]),
            ("5", [[CGPoint(x: 170, y: 50), CGPoint(x: 90, y: 50), CGPoint(x: 85, y: 120), CGPoint(x: 160, y: 130), CGPoint(x: 170, y: 180), CGPoint(x: 90, y: 210)]])
        ]
        for (lbl, strks) in templates {
            drawKNN.addSample(DrawingSample.fromStrokes(strks, label: lbl, canvasSize: canvas))
        }
        drawKNN.k = 3
        drawKNN.train()
    }
    
    private func randomDigit() -> String {
        ["0", "1", "2", "3", "4", "5"].randomElement() ?? "1"
    }
    
    // Chat helpers
    
    private func initChat() {
        guard !didInitializeChat else { return }
        didInitializeChat = true
        addChat("Signal fragmenting... I need KNN anchors. Scan objects: \(minigame.trainingLabels.joined(separator: ", "))", isUser: false)
        addChat("On it! Starting the rescue.", isUser: true)
    }
    
    private func addChat(_ text: String, isUser: Bool) {
        chatMessages.append(TrainingChatMessage(text: text, isUser: isUser))
    }
}

// MARK: - Supporting Views

struct LabelButton: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.white.opacity(isSelected ? 0.3 : 0.12))
                        .cornerRadius(3)
                }
            }
            .font(.system(size: layout.isCompact ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.65))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.white.opacity(0.06))
            )
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color(hex: "8B5CF6").opacity(0.4) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    // LabelButton doesn't have access to layout, use fixed sizes
    private var layout: (isCompact: Bool, Void) { (UIScreen.main.bounds.width < 700, ()) }
}
