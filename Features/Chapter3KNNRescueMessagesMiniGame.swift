import SwiftUI
import PhotosUI

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

// MARK: - Image Feature Extractor
struct ImageFeatureExtractor {
    /// Extract feature vector from a UIImage (resize to 28x28, compute zone-based color features)
    static func extractFeatures(from image: UIImage) -> [Double] {
        let size = CGSize(width: 28, height: 28)
        guard let cgImage = image.cgImage else { return Array(repeating: 0.5, count: 50) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * Int(size.width)
        var pixelData = [UInt8](repeating: 0, count: Int(size.width) * Int(size.height) * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Array(repeating: 0.5, count: 50) }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        var features: [Double] = []
        let zoneSize = 7 // 28/4 = 7

        // 4x4 zones × 3 channels = 48 features
        for zy in 0..<4 {
            for zx in 0..<4 {
                var sumR = 0.0, sumG = 0.0, sumB = 0.0
                let count = Double(zoneSize * zoneSize)
                for y in (zy * zoneSize)..<((zy + 1) * zoneSize) {
                    for x in (zx * zoneSize)..<((zx + 1) * zoneSize) {
                        let offset = (y * Int(size.width) + x) * bytesPerPixel
                        sumR += Double(pixelData[offset]) / 255.0
                        sumG += Double(pixelData[offset + 1]) / 255.0
                        sumB += Double(pixelData[offset + 2]) / 255.0
                    }
                }
                features.append(sumR / count)
                features.append(sumG / count)
                features.append(sumB / count)
            }
        }

        // Overall brightness and contrast (2 features)
        var totalBrightness = 0.0
        var brightnessSq = 0.0
        let totalPixels = Double(Int(size.width) * Int(size.height))
        for i in 0..<Int(totalPixels) {
            let offset = i * bytesPerPixel
            let b = (Double(pixelData[offset]) + Double(pixelData[offset + 1]) + Double(pixelData[offset + 2])) / (3.0 * 255.0)
            totalBrightness += b
            brightnessSq += b * b
        }
        let meanBrightness = totalBrightness / totalPixels
        let variance = (brightnessSq / totalPixels) - (meanBrightness * meanBrightness)
        features.append(meanBrightness)
        features.append(sqrt(max(0, variance)))

        return features // 50 features total
    }

    /// Project high-dimensional features to 2D for scatter plot
    static func projectTo2D(features: [Double]) -> (x: Double, y: Double) {
        guard features.count >= 48 else { return (0.5, 0.5) }

        // Use weighted sums of different feature groups for x and y
        var xVal = 0.0, yVal = 0.0
        for i in stride(from: 0, to: 48, by: 3) {
            let zone = i / 3
            let row = zone / 4
            let col = zone % 4
            let r = features[i], g = features[i + 1], b = features[i + 2]
            
            // Map spatial color differences to [-0.5, 0.5] range roughly
            xVal += (r - g) * (Double(col) / 3.0 - 0.5) + (r - 0.5) * 0.2
            yVal += (b - (r + g) / 2.0) * (Double(row) / 3.0 - 0.5) + (b - 0.5) * 0.2
        }

        // Add brightness and variance (features 48 and 49) to spread further
        if features.count >= 50 {
            xVal += (features[48] - 0.5) * 1.5
            yVal += (features[49] - 0.1) * 3.0
        }

        // Small deterministic jitter based on feature sum to spread similar images
        let sum = features.reduce(0, +)
        let jitterX = (sum.truncatingRemainder(dividingBy: 1.0) - 0.5) * 0.15
        let jitterY = ((sum * 1.3).truncatingRemainder(dividingBy: 1.0) - 0.5) * 0.15

        // Normalize to 0.1...0.9 range
        let x = min(0.9, max(0.1, (xVal / 3.0) + 0.5 + jitterX))
        let y = min(0.9, max(0.1, (yVal / 3.0) + 0.5 + jitterY))
        return (x, y)
    }

    /// Euclidean distance between two feature vectors
    static func distance(_ a: [Double], _ b: [Double]) -> Double {
        let len = min(a.count, b.count)
        var sum = 0.0
        for i in 0..<len {
            sum += (a[i] - b[i]) * (a[i] - b[i])
        }
        return sqrt(sum)
    }
}

// MARK: - Photo Training Sample
struct PhotoTrainingSample: Identifiable {
    let id = UUID()
    let label: String
    let image: UIImage
    let features: [Double]
    let point2D: (x: Double, y: Double)
}

// MARK: - Drawing Training Sample (for draw mode)
struct DrawTrainingSample: Identifiable {
    let id = UUID()
    let label: String
    let strokes: [[CGPoint]]
    let canvasSize: CGSize
    let features: [Double]
    let point2D: (x: Double, y: Double)
}

// MARK: - Main MiniGame View
@MainActor
struct Chapter3KNNRescueMessagesMiniGame: View {
    let minigame: Chapter3KNNRescueMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void

    @Environment(\.accessibleColors) private var accessColors

    // Game phases
    enum GamePhase: Int, CaseIterable {
        case collect = 0, train = 1, test = 2, complete = 3
    }

    @State private var phase: GamePhase = .collect
    @State private var mode: Chapter3KNNRescueMode = .photo

    // Photo mode state
    @State private var photoSamples: [PhotoTrainingSample] = []
    @State private var penPickerItems: [PhotosPickerItem] = []
    @State private var handPickerItems: [PhotosPickerItem] = []
    @State private var bottlePickerItems: [PhotosPickerItem] = []

    // Drawing mode state
    @State private var drawSamples: [DrawTrainingSample] = []
    @State private var drawStrokes: [[CGPoint]] = []
    @State private var drawCurrentStroke: [CGPoint] = []
    @State private var drawCanvasSize: CGSize = .zero
    @State private var drawCurrentLabel: String = "1"
    @State private var drawCurrentIndex: Int = 0  // 0-2 for current label

    // Shared training data (projected to 2D for scatter plot)
    @State private var trainingPoints: [KNNDataPoint] = []
    @State private var trainingFeatures: [(label: String, features: [Double])] = []

    // Training animation
    @State private var isTraining = false
    @State private var trainingProgress: Double = 0
    @State private var trainingTask: Task<Void, Never>?

    // Testing state
    @State private var testImages: [(label: String, image: UIImage?, features: [Double])] = []
    @State private var currentTestIndex: Int = 0
    @State private var testPoint: KNNDataPoint?
    @State private var nearestNeighbors: [(point: KNNDataPoint, distance: Double)] = []
    @State private var knnPrediction: String?
    @State private var showTestResult = false
    @State private var correctCount = 0
    @State private var totalTests = 0
    @State private var showNeighborLines = false
    @State private var testPickerItems: [PhotosPickerItem] = []

    // Chat
    @State private var chatMessages: [TrainingChatMessage] = []
    @State private var didInitializeChat = false
    @State private var didComplete = false

    // Drawing test state
    @State private var isDrawingTest = false
    @State private var drawTestStrokes: [[CGPoint]] = []
    @State private var drawTestCurrentStroke: [CGPoint] = []
    @State private var drawTestCanvasSize: CGSize = .zero
    @State private var drawTestLabel: String = "1"

    // AI Name
    private var aiName: String {
        GlobalSettingsStore.shared.aiDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Ploy"
            : GlobalSettingsStore.shared.aiDisplayName
    }

    private var labels: [String] {
        mode == .photo ? ["Pen", "Hand", "Bottle"] : ["1", "2", "3"]
    }
    private let samplesPerClass = 3

    init(minigame: Chapter3KNNRescueMiniGame, layout: DialogAdaptiveLayout, isCompleted: Bool, onComplete: @escaping (String) -> Void) {
        self.minigame = minigame
        self.layout = layout
        self.isCompleted = isCompleted
        self.onComplete = onComplete
    }

    // MARK: - Computed Properties

    private var labelColors: [String: Color] {
        [
            "Pen": Color(hex: "3B82F6"),
            "Hand": Color(hex: "F59E0B"),
            "Bottle": Color(hex: "10B981"),
            "1": Color(hex: "3B82F6"),
            "2": Color(hex: "F59E0B"),
            "3": Color(hex: "10B981")
        ]
    }

    private var labelIcons: [String: String] {
        [
            "Pen": "pencil",
            "Hand": "hand.raised.fill",
            "Bottle": "cup.and.saucer.fill",
            "1": "1.circle.fill",
            "2": "2.circle.fill",
            "3": "3.circle.fill"
        ]
    }

    private func photoCountFor(_ label: String) -> Int {
        photoSamples.filter { $0.label == label }.count
    }

    private func drawCountFor(_ label: String) -> Int {
        drawSamples.filter { $0.label == label }.count
    }

    private var hasEnoughPhotos: Bool {
        labels.allSatisfy { photoCountFor($0) >= samplesPerClass }
    }

    private var hasEnoughDrawings: Bool {
        labels.allSatisfy { drawCountFor($0) >= samplesPerClass }
    }

    private var totalDrawingsNeeded: Int { labels.count * samplesPerClass }
    private var totalDrawingsCollected: Int { drawSamples.count }

    private var rescuePassed: Bool {
        correctCount >= 1
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

                stepIndicator
                    .padding(.bottom, layout.isCompact ? 6 : 10)

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
            VStack {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.black.opacity(0.25), location: 0.15),
                        .init(color: Color.black.opacity(0.55), location: 0.35),
                        .init(color: Color.black.opacity(0.82), location: 0.6),
                        .init(color: Color.black.opacity(0.95), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: bottomDialogReserve + 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .zIndex(1)

            bottomDialog.zIndex(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .onAppear { initChat() }
        .onDisappear {
            trainingTask?.cancel()
            trainingTask = nil
        }
        .onChange(of: penPickerItems) { _, items in
            handlePhotoPick(items: items, label: "Pen")
        }
        .onChange(of: handPickerItems) { _, items in
            handlePhotoPick(items: items, label: "Hand")
        }
        .onChange(of: bottlePickerItems) { _, items in
            handlePhotoPick(items: items, label: "Bottle")
        }
        .onChange(of: testPickerItems) { _, items in
            handleTestPhotoPick(items: items)
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

    private var activeGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var inactiveGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func stepDot(_ index: Int, _ label: String, _ icon: String) -> some View {
        let active: Bool = phase.rawValue >= index
        let current: Bool = phase.rawValue == index
        let dotFill: LinearGradient = active ? activeGradient : inactiveGradient
        let dotSize: CGFloat = layout.isCompact ? 28 : 34
        let ringSize: CGFloat = layout.isCompact ? 36 : 42
        let iconSize: CGFloat = layout.isCompact ? 11 : 13
        let labelSize: CGFloat = layout.isCompact ? 9 : 10
        let iconColor: Color = active ? .white : .white.opacity(0.35)
        let labelWeight: Font.Weight = current ? .bold : .medium

        return VStack(spacing: 3) {
            ZStack {
                Circle().fill(dotFill).frame(width: dotSize, height: dotSize)
                if current {
                    Circle()
                        .stroke(Color(hex: "8B5CF6").opacity(0.5), lineWidth: 2)
                        .frame(width: ringSize, height: ringSize)
                }
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(label)
                .font(.system(size: labelSize, weight: labelWeight))
                .foregroundColor(iconColor)
        }
    }

    private func stepLine(_ active: Bool) -> some View {
        let lineFill: LinearGradient = active
            ? LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
        return Rectangle()
            .fill(lineFill)
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

    private var topBarSampleCount: Int {
        mode == .photo ? photoSamples.count : drawSamples.count
    }

    private var topBarEnough: Bool {
        mode == .photo ? hasEnoughPhotos : hasEnoughDrawings
    }

    private var topBarStatusColor: Color {
        topBarEnough ? accessColors.success : accessColors.warning
    }

    private var topBarModeIcon: String {
        mode == .photo ? "pencil.tip" : "photo.on.rectangle"
    }

    private var topBarModeLabel: String {
        mode == .photo ? "Draw" : "Photo"
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            topBarLeading
            topBarSampleBadge
            Spacer()
            topBarModeButton
        }
    }

    private var topBarLeading: some View {
        HStack(spacing: 5) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: layout.captionFontSize - 1, weight: .semibold))
                .foregroundColor(rescuePassed ? accessColors.success : accessColors.warning)
            Text("KNN Rescue")
                .font(.system(size: layout.captionFontSize + 1, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private var topBarSampleBadge: some View {
        Text("\(topBarSampleCount)/\(totalDrawingsNeeded) samples")
            .font(.system(size: layout.captionFontSize - 1, weight: .bold, design: .monospaced))
            .foregroundColor(topBarStatusColor)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Capsule().fill(topBarStatusColor.opacity(0.12)))
    }

    private var topBarModeButton: some View {
        Button(action: toggleMode) {
            HStack(spacing: 4) {
                Image(systemName: topBarModeIcon)
                    .font(.system(size: layout.captionFontSize - 2))
                Text(topBarModeLabel)
                    .font(.system(size: layout.captionFontSize - 1, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: "6366F1").opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(phase != .collect)
        .opacity(phase == .collect ? 1.0 : 0.4)
    }

    // MARK: - Center Panel

    @ViewBuilder
    private var centerPanel: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            switch phase {
            case .collect:
                if mode == .photo {
                    photoCollectView
                } else {
                    drawingCollectView
                }
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

    // MARK: - Photo Collect Phase

    private var photoCollectView: some View {
        VStack(spacing: layout.isCompact ? 10 : 14) {
            photoCollectHeader
            separator
            ForEach(labels, id: \.self) { label in
                photoClassRow(label: label)
            }
            photoCollectScatterPreview
            photoCollectTrainButton
            photoCollectHint
        }
    }

    private var photoCollectHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "818CF8"))
                Text("Step 1: Upload Training Photos")
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            Text("Upload 3 photos for each class. The KNN will learn to distinguish them by extracting color and shape features.")
                .font(.system(size: layout.isCompact ? 11 : 12, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var photoCollectScatterPreview: some View {
        if !trainingPoints.isEmpty {
            VStack(spacing: 4) {
                HStack {
                    Text("Feature Space Preview")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.5)
                    Spacer()
                }
                scatterPlot(showTest: false, height: layout.isCompact ? 120 : 150)
            }
        }
    }

    private var photoTrainButtonGradient: LinearGradient {
        hasEnoughPhotos
            ? LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
    }

    private var photoCollectTrainButton: some View {
        Button(action: startTraining) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                Text("Train KNN (K=3)")
                    .font(.system(size: layout.isCompact ? 13 : 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout.isCompact ? 12 : 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(photoTrainButtonGradient))
        }
        .buttonStyle(.plain)
        .disabled(!hasEnoughPhotos)
    }

    @ViewBuilder
    private var photoCollectHint: some View {
        if !hasEnoughPhotos {
            Text("Need 3 photos per class (\(photoSamples.count)/9)")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    private func pickerBinding(for label: String) -> Binding<[PhotosPickerItem]> {
        switch label {
        case "Pen": return $penPickerItems
        case "Hand": return $handPickerItems
        case "Bottle": return $bottlePickerItems
        default: return $penPickerItems
        }
    }

    // Photo class row: label header + 3 photo slots
    private func photoClassRow(label: String) -> some View {
        let color: Color = labelColors[label] ?? .gray
        let icon: String = labelIcons[label] ?? "questionmark"
        let count: Int = photoCountFor(label)
        let countColor: Color = count >= 3 ? accessColors.success : .white.opacity(0.4)
        let thumbSize: CGFloat = layout.isCompact ? 70 : 85

        return VStack(alignment: .leading, spacing: 6) {
            photoClassHeader(label: label, icon: icon, color: color, count: count, countColor: countColor)
            photoClassThumbnails(label: label, color: color, count: count, thumbSize: thumbSize)
        }
        .padding(10)
        .background(photoClassBackground(color: color))
    }

    private func photoClassHeader(label: String, icon: String, color: Color, count: Int, countColor: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("\(count)/3")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(countColor)
            Spacer()
        }
    }

    @ViewBuilder
    private func photoClassThumbnails(label: String, color: Color, count: Int, thumbSize: CGFloat) -> some View {
        let samples = photoSamples.filter { $0.label == label }
        HStack(spacing: 8) {
            ForEach(samples) { sample in
                photoThumbnail(image: sample.image, color: color, size: thumbSize)
            }
            if count < 3 {
                photoAddButton(label: label, color: color, remaining: 3 - count, size: thumbSize)
            }
            Spacer()
        }
    }

    private func photoThumbnail(image: UIImage, color: Color, size: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.6), lineWidth: 2)
            )
    }

    private func photoAddButton(label: String, color: Color, remaining: Int, size: CGFloat) -> some View {
        PhotosPicker(
            selection: pickerBinding(for: label),
            maxSelectionCount: remaining,
            matching: .images
        ) {
            VStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(color.opacity(0.6))
                Text("Add")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    )
            )
        }
    }

    private func photoClassBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(color.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.12), lineWidth: 1)
            )
    }

    // MARK: - Drawing Collect Phase

    private var drawingCollectView: some View {
        let spacing: CGFloat = layout.isCompact ? 10 : 14
        let drawColor: Color = labelColors[drawCurrentLabel] ?? .gray
        let drawIcon: String = labelIcons[drawCurrentLabel] ?? "questionmark"
        let drawNum: Int = drawCountFor(drawCurrentLabel) + 1

        return VStack(spacing: spacing) {
            drawCollectHeader
            separator
            drawProgressView
            separator
            drawPromptSection(color: drawColor, icon: drawIcon, num: drawNum)
            KNNDrawingCanvas(strokes: $drawStrokes, currentStroke: $drawCurrentStroke, canvasSize: $drawCanvasSize)
            drawCollectControls
            drawCollectTrainButton
        }
    }

    private var drawCollectHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "FB923C"))
                Text("Step 1: Draw Training Samples")
                    .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            Text("Draw the numbers 1, 2, and 3 — three samples each. The KNN will learn from your drawings.")
                .font(.system(size: layout.isCompact ? 11 : 12, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func drawPromptSection(color: Color, icon: String, num: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text("Draw: \(drawCurrentLabel)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("(\(num)/3)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.12)))

            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(color.opacity(0.5))
        }
    }

    private var drawCollectControls: some View {
        let submitBg: Color = drawStrokes.isEmpty ? Color.white.opacity(0.1) : accessColors.success
        return HStack(spacing: 10) {
            Button(action: {
                drawStrokes.removeAll()
                drawCurrentStroke.removeAll()
            }) {
                Label("Clear", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "EF4444").opacity(0.5)))
            }
            .buttonStyle(.plain)

            Button(action: submitDrawingSample) {
                Label("Submit Drawing", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(submitBg))
            }
            .buttonStyle(.plain)
            .disabled(drawStrokes.isEmpty)
        }
    }

    @ViewBuilder
    private var drawCollectTrainButton: some View {
        if hasEnoughDrawings && phase == .collect {
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
                        .fill(LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // Drawing progress for all classes
    private var drawProgressView: some View {
        HStack(spacing: 12) {
            ForEach(labels, id: \.self) { label in
                drawProgressItem(label: label)
            }
        }
    }

    private func drawProgressItem(label: String) -> some View {
        let count: Int = drawCountFor(label)
        let isCurrent: Bool = drawCurrentLabel == label
        let color: Color = labelColors[label] ?? .gray
        let fontWeight: Font.Weight = isCurrent ? .bold : .medium
        let textColor: Color = isCurrent ? .white : .white.opacity(0.5)
        let bgFill: Color = isCurrent ? color.opacity(0.15) : Color.clear
        let bgStroke: Color = isCurrent ? color.opacity(0.3) : Color.clear

        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11, weight: fontWeight, design: .rounded))
                    .foregroundColor(textColor)
            }
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < count ? color : Color.white.opacity(0.1))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bgFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(bgStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Train Phase

    private var trainPhaseSampleCount: Int {
        mode == .photo ? photoSamples.count : drawSamples.count
    }

    private var trainPhaseView: some View {
        VStack(spacing: 14) {
            trainPhaseHeader
            trainProgressBar
            separator
            scatterPlot(showTest: false, height: layout.isCompact ? 160 : 200)
            Text("Mapping \(trainPhaseSampleCount) samples to feature space... \(Int(trainingProgress * 100))%")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            trainPhaseLegend
        }
    }

    private var trainPhaseHeader: some View {
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
    }

    private var trainProgressBar: some View {
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
    }

    private var trainPhaseLegend: some View {
        HStack(spacing: 16) {
            ForEach(labels, id: \.self) { label in
                HStack(spacing: 4) {
                    Circle().fill(labelColors[label] ?? .gray).frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Test Phase

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
                Text("\(correctCount)/3")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "34D399"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "34D399").opacity(0.15)))
            }

            signalStrengthBar

            separator

            if mode == .photo {
                photoTestContent
            } else {
                drawingTestContent
            }
        }
    }

    // Photo test: show asset images
    @ViewBuilder
    private var photoTestContent: some View {
        if currentTestIndex < testImages.count {
            let test = testImages[currentTestIndex]
            let testColor = labelColors[test.label] ?? .gray
            
            VStack(spacing: 10) {
                photoTestHeader(label: test.label, color: testColor)
                scatterPlot(showTest: testPoint != nil, height: layout.isCompact ? 140 : 180)
                if showTestResult {
                    testResultView(actualLabel: test.label)
                } else if let img = test.image {
                    photoTestImagePreview(test: test)
                    classifyPhotoButton
                } else {
                    photoTestUploadButton(label: test.label, color: testColor)
                }
            }
        }
    }

    private func photoTestHeader(label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("Test \(currentTestIndex + 1) of 3: Upload \(label)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func photoTestUploadButton(label: String, color: Color) -> some View {
        PhotosPicker(selection: $testPickerItems, maxSelectionCount: 1, matching: .images) {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24))
                Text("Upload Test Photo")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5])))
        }
    }

    @ViewBuilder
    private func photoTestImagePreview(test: (label: String, image: UIImage?, features: [Double])) -> some View {
        if let img = test.image {
            VStack(spacing: 6) {
                Text("Test Image \(currentTestIndex + 1) of 3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.5)
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: layout.isCompact ? 100 : 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )
            }
        }
    }

    private var classifyPhotoButton: some View {
        VStack(spacing: 8) {
            Text("KNN is classifying this image...")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Button(action: { runKNNTest() }) {
                Label("Classify with KNN", systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // Drawing test content
    @ViewBuilder
    private var drawingTestContent: some View {
        if currentTestIndex < 3 {
            let testLabel: String = labels[currentTestIndex]
            let testColor: Color = labelColors[testLabel] ?? .gray
            let testIcon: String = labelIcons[testLabel] ?? "questionmark"
            VStack(spacing: 10) {
                drawTestHeader(label: testLabel, color: testColor, icon: testIcon)
                scatterPlot(showTest: testPoint != nil, height: layout.isCompact ? 120 : 150)
                if showTestResult {
                    testResultView(actualLabel: testLabel)
                } else {
                    drawTestCanvas
                    drawTestControls
                }
            }
        }
    }

    private func drawTestHeader(label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Text("Test \(currentTestIndex + 1) of 3: Draw \(label)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color.opacity(0.6))
        }
    }

    private var drawTestCanvas: some View {
        KNNDrawingCanvas(
            strokes: $drawTestStrokes,
            currentStroke: $drawTestCurrentStroke,
            canvasSize: $drawTestCanvasSize
        )
    }

    private var drawTestControls: some View {
        let classifyBg: Color = drawTestStrokes.isEmpty ? Color.white.opacity(0.1) : Color(hex: "6366F1")
        return HStack(spacing: 10) {
            Button(action: {
                drawTestStrokes.removeAll()
                drawTestCurrentStroke.removeAll()
            }) {
                Label("Clear", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "EF4444").opacity(0.5)))
            }
            .buttonStyle(.plain)

            Button(action: { runDrawingTest() }) {
                Label("Classify", systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(classifyBg))
            }
            .buttonStyle(.plain)
            .disabled(drawTestStrokes.isEmpty)
        }
    }

    // Test result view (shared between photo and drawing modes)
    private func testResultView(actualLabel: String) -> some View {
        let isCorrect: Bool = knnPrediction == actualLabel
        let resultIcon: String = isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        let resultColor: Color = isCorrect ? accessColors.success : accessColors.error
        let prediction: String = knnPrediction ?? "?"
        let resultText: String = isCorrect ? "Correct! KNN predicted: \(prediction)" : "KNN predicted \(prediction), was \(actualLabel)"
        let neighborVotes: String = nearestNeighbors.map { $0.point.label }.joined(separator: ", ")
        let canComplete: Bool = correctCount >= 1 && currentTestIndex >= 2
        let nextBtnLabel: String = canComplete ? "Complete Rescue!" : "Next Test"
        let nextBtnIcon: String = canComplete ? "checkmark.circle.fill" : "arrow.right.circle.fill"

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: resultIcon)
                    .font(.system(size: 22))
                    .foregroundColor(resultColor)
                Text(resultText)
                    .font(.system(size: layout.isCompact ? 13 : 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            if !nearestNeighbors.isEmpty {
                Text("K=3 neighbors voted: \(neighborVotes)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Button(action: nextTest) {
                Label(nextBtnLabel, systemImage: nextBtnIcon)
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
        .background(RoundedRectangle(cornerRadius: 14).fill(resultColor.opacity(0.1)))
    }

    // Signal strength
    private var signalStrengthBar: some View {
        GeometryReader { geo in
            let pct = min(Double(correctCount) / 3.0, 1.0)
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

    // MARK: - Complete Phase

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

            scatterPlot(showTest: false, height: layout.isCompact ? 100 : 130)
        }
        .padding(.vertical, layout.isCompact ? 12 : 20)
    }

    // MARK: - Scatter Plot

    private func scatterPlot(showTest: Bool, height: CGFloat?) -> some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            let h: CGFloat = geo.size.height
            ZStack {
                scatterGridLines(w: w, h: h)
                scatterNeighborLines(showTest: showTest, w: w, h: h)
                scatterTrainingDots(w: w, h: h)
                scatterTestDot(showTest: showTest, w: w, h: h)
            }
        }
        .frame(height: height ?? 150)
        .background(scatterPlotBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scatterGridLines(w: CGFloat, h: CGFloat) -> some View {
        let gridColor: Color = Color.white.opacity(0.05)
        return ForEach(1..<4, id: \.self) { i in
            Path { p in
                let x: CGFloat = w * CGFloat(i) / 4.0
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: h))
            }.stroke(gridColor, lineWidth: 1)
            Path { p in
                let y: CGFloat = h * CGFloat(i) / 4.0
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: w, y: y))
            }.stroke(gridColor, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func scatterNeighborLines(showTest: Bool, w: CGFloat, h: CGFloat) -> some View {
        if showTest, showNeighborLines, let test = testPoint {
            ForEach(nearestNeighbors.indices, id: \.self) { i in
                let n = nearestNeighbors[i]
                Path { p in
                    p.move(to: CGPoint(x: test.x * w, y: test.y * h))
                    p.addLine(to: CGPoint(x: n.point.x * w, y: n.point.y * h))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }
        }
    }

    private func scatterTrainingDots(w: CGFloat, h: CGFloat) -> some View {
        ForEach(trainingPoints) { pt in
            let ptColor: Color = labelColors[pt.label] ?? .gray
            Circle()
                .fill(ptColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: ptColor.opacity(0.5), radius: 4)
                .position(x: pt.x * w, y: pt.y * h)
        }
    }

    @ViewBuilder
    private func scatterTestDot(showTest: Bool, w: CGFloat, h: CGFloat) -> some View {
        if showTest, let test = testPoint {
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

    private var scatterPlotBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.4))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Separator

    private var separator: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }

    // MARK: - Bottom Dialog

    private var lastUserChat: String {
        chatMessages.last(where: { $0.isUser })?.text ?? "Helping with the KNN rescue..."
    }

    private var lastAIChat: String {
        chatMessages.last(where: { !$0.isUser })?.text ?? "Signal breaking... need anchors..."
    }

    private var showContinueButton: Bool {
        (isCompleted || rescuePassed) && !didComplete && phase == .complete
    }

    private var bottomDialog: some View {
        VStack(spacing: layout.isCompact ? 5 : 8) {
            Spacer()
            bottomDialogPanes
            if showContinueButton {
                continueStoryButton
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .padding(.bottom, layout.isCompact ? 72 : 94)
    }

    private var bottomDialogPanes: some View {
        HStack(alignment: .top, spacing: layout.isCompact ? 10 : 16) {
            dialogPane("You", "Student", lastUserChat, Color(hex: "60A5FA"), false)
                .frame(maxWidth: .infinity, alignment: .leading)
            dialogPane(aiName, "AI Friend", lastAIChat, Color(hex: "FB923C"), true)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var continueStoryButton: some View {
        let successColor: Color = accessColors.success
        return Button(action: {
            guard !didComplete else { return }
            didComplete = true
            onComplete("KNN Rescue Complete!")
        }) {
            Label("Continue Story", systemImage: "arrow.right.circle.fill")
                .font(.system(size: layout.isCompact ? 14 : 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(
                    Capsule().fill(LinearGradient(colors: [successColor, successColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: successColor.opacity(0.4), radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity).padding(.top, 4)
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

    // Handle photo picker results
    private func handlePhotoPick(items: [PhotosPickerItem], label: String) {
        guard !items.isEmpty else { return }
        for item in items {
            guard photoCountFor(label) < samplesPerClass else { break }
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    if case .success(let data) = result, let data = data, let uiImage = UIImage(data: data) {
                        let features = ImageFeatureExtractor.extractFeatures(from: uiImage)
                        let point2D = ImageFeatureExtractor.projectTo2D(features: features)

                        let sample = PhotoTrainingSample(
                            label: label,
                            image: uiImage,
                            features: features,
                            point2D: point2D
                        )

                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            photoSamples.append(sample)
                            trainingPoints.append(KNNDataPoint(
                                label: label,
                                x: point2D.x,
                                y: point2D.y,
                                emoji: ""
                            ))
                            trainingFeatures.append((label: label, features: features))
                        }

                        addChat("Added \(label) photo!", isUser: true)
                        addChat("Features extracted. \(self.photoSamples.count)/9 samples collected.", isUser: false)
                    }
                }
            }
        }
        // Clear picker after processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch label {
            case "Pen": penPickerItems.removeAll()
            case "Hand": handPickerItems.removeAll()
            case "Bottle": bottlePickerItems.removeAll()
            default: break
            }
        }
    }

    private func handleTestPhotoPick(items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                if case .success(let data) = result, let data = data, let uiImage = UIImage(data: data) {
                    let features = ImageFeatureExtractor.extractFeatures(from: uiImage)
                    testImages[currentTestIndex].image = uiImage
                    testImages[currentTestIndex].features = features
                    
                    let pt = ImageFeatureExtractor.projectTo2D(features: features)
                    testPoint = KNNDataPoint(label: "?", x: pt.x, y: pt.y, emoji: "?")
                    
                    addChat("Uploaded test photo!", isUser: true)
                }
                self.testPickerItems.removeAll()
            }
        }
    }

    // Submit a drawing sample
    private func submitDrawingSample() {
        guard !drawStrokes.isEmpty, drawCanvasSize != .zero else { return }

        let sample = DrawingSample.fromStrokes(drawStrokes, label: drawCurrentLabel, canvasSize: drawCanvasSize)
        let features = sample.featureVector()

        // Project drawing features to 2D
        let x = projectDrawingFeatureX(features)
        let y = projectDrawingFeatureY(features)

        let drawSample = DrawTrainingSample(
            label: drawCurrentLabel,
            strokes: drawStrokes,
            canvasSize: drawCanvasSize,
            features: features,
            point2D: (x, y)
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            drawSamples.append(drawSample)
            trainingPoints.append(KNNDataPoint(
                label: drawCurrentLabel,
                x: x,
                y: y,
                emoji: ""
            ))
            trainingFeatures.append((label: drawCurrentLabel, features: features))
        }

        addChat("Drew \(drawCurrentLabel) sample!", isUser: true)
        addChat("Got it! \(drawSamples.count)/\(totalDrawingsNeeded) samples.", isUser: false)

        // Clear canvas and advance
        drawStrokes.removeAll()
        drawCurrentStroke.removeAll()
        advanceDrawingPrompt()
    }

    private func projectDrawingFeatureX(_ features: [Double]) -> Double {
        // Use a subset of features for X projection
        guard features.count > 30 else { return 0.5 }
        var sum = 0.0
        for i in 0..<min(28, features.count) {
            sum += (features[i] - 0.5) * (i % 2 == 0 ? 1.0 : -1.0)
        }
        let hashVal = features.reduce(0, +).truncatingRemainder(dividingBy: 1.0)
        let jitter = (hashVal - 0.5) * 0.1
        return min(0.9, max(0.1, (sum / 5.0) + 0.5 + jitter))
    }

    private func projectDrawingFeatureY(_ features: [Double]) -> Double {
        guard features.count > 56 else { return 0.5 }
        var sum = 0.0
        for i in 28..<min(56, features.count) {
            sum += (features[i] - 0.5) * (i % 2 == 0 ? -1.0 : 1.0)
        }
        let hashVal = features.reduce(0, +).truncatingRemainder(dividingBy: 1.0)
        let jitter = ((hashVal * 1.7).truncatingRemainder(dividingBy: 1.0) - 0.5) * 0.1
        return min(0.9, max(0.1, (sum / 5.0) + 0.5 + jitter))
    }

    private func advanceDrawingPrompt() {
        let count = drawCountFor(drawCurrentLabel)
        if count >= samplesPerClass {
            // Move to next label
            if let idx = labels.firstIndex(of: drawCurrentLabel), idx + 1 < labels.count {
                drawCurrentLabel = labels[idx + 1]
            }
            // If all labels done, hasEnoughDrawings will be true
        }
    }

    // Start training
    private func startTraining() {
        let enough = mode == .photo ? hasEnoughPhotos : hasEnoughDrawings
        guard enough else { return }
        phase = .train
        isTraining = true
        trainingProgress = 0

        addChat("Training KNN with K=3...", isUser: true)
        addChat("Processing samples into feature space...", isUser: false)

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
            prepareTests()
            withAnimation(.easeOut(duration: 0.3)) { phase = .test }
        }
    }

    // Prepare test images
    private func prepareTests() {
        testImages = []

        if mode == .photo {
            for label in labels {
                testImages.append((label: label, image: nil, features: []))
            }
        }

        currentTestIndex = 0
        showTestResult = false
        showNeighborLines = false
        knnPrediction = nil
        testPoint = nil
        testPickerItems.removeAll()
    }

    // Run KNN test on current photo test image
    private func runKNNTest() {
        guard currentTestIndex < testImages.count else { return }
        let test = testImages[currentTestIndex]

        // Find K=3 nearest neighbors using feature distance
        var distances: [(index: Int, label: String, distance: Double, point: KNNDataPoint)] = []
        for i in 0..<trainingFeatures.count {
            let d = ImageFeatureExtractor.distance(test.features, trainingFeatures[i].features)
            distances.append((index: i, label: trainingFeatures[i].label, distance: d, point: trainingPoints[i]))
        }
        distances.sort { $0.distance < $1.distance }

        let kNearest = Array(distances.prefix(3))
        nearestNeighbors = kNearest.map { (point: $0.point, distance: $0.distance) }

        // Majority vote
        var votes: [String: Int] = [:]
        for n in kNearest { votes[n.label, default: 0] += 1 }
        knnPrediction = votes.max(by: { $0.value < $1.value })?.key ?? test.label

        let isCorrect = knnPrediction == test.label
        if isCorrect { correctCount += 1 }
        totalTests += 1

        addChat("Testing \(test.label) image...", isUser: true)
        addChat(isCorrect ? "Correct! KNN identified \(knnPrediction!)." : "KNN predicted \(knnPrediction!), actual was \(test.label).", isUser: false)

        withAnimation(.easeOut(duration: 0.3)) {
            showNeighborLines = true
            showTestResult = true
        }
    }

    // Run KNN test on drawn test sample
    private func runDrawingTest() {
        guard !drawTestStrokes.isEmpty, drawTestCanvasSize != .zero else { return }

        let sample = DrawingSample.fromStrokes(drawTestStrokes, label: "test", canvasSize: drawTestCanvasSize)
        let features = sample.featureVector()
        let testLabel = labels[currentTestIndex]

        // Project to 2D
        let x = projectDrawingFeatureX(features)
        let y = projectDrawingFeatureY(features)
        testPoint = KNNDataPoint(label: "?", x: x, y: y, emoji: "?")

        // Find K=3 nearest neighbors
        var distances: [(index: Int, label: String, distance: Double, point: KNNDataPoint)] = []
        for i in 0..<trainingFeatures.count {
            let d = euclideanDistance(features, trainingFeatures[i].features)
            distances.append((index: i, label: trainingFeatures[i].label, distance: d, point: trainingPoints[i]))
        }
        distances.sort { $0.distance < $1.distance }

        let kNearest = Array(distances.prefix(3))
        nearestNeighbors = kNearest.map { (point: $0.point, distance: $0.distance) }

        var votes: [String: Int] = [:]
        for n in kNearest { votes[n.label, default: 0] += 1 }
        knnPrediction = votes.max(by: { $0.value < $1.value })?.key ?? testLabel

        let isCorrect = knnPrediction == testLabel
        if isCorrect { correctCount += 1 }
        totalTests += 1

        addChat("Testing drawing for \(testLabel)...", isUser: true)
        addChat(isCorrect ? "Correct! Recognized as \(knnPrediction!)." : "Predicted \(knnPrediction!), expected \(testLabel).", isUser: false)

        withAnimation(.easeOut(duration: 0.3)) {
            showNeighborLines = true
            showTestResult = true
        }
    }

    private func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        let len = min(a.count, b.count)
        var sum = 0.0
        for i in 0..<len { sum += (a[i] - b[i]) * (a[i] - b[i]) }
        return sqrt(sum)
    }

    // Move to next test
    private func nextTest() {
        currentTestIndex += 1

        if currentTestIndex >= 3 || (correctCount >= 1 && currentTestIndex >= 3) {
            // All tests done
            if correctCount >= 1 {
                withAnimation(.easeOut(duration: 0.4)) { phase = .complete }
                addChat("Signal stabilized at 99.98%!", isUser: false)
            } else {
                // Failed all 3 — restart test
                addChat("Signal too weak. Trying again...", isUser: false)
                prepareTests()
            }
            return
        }

        // Reset for next test
        showTestResult = false
        showNeighborLines = false
        knnPrediction = nil
        nearestNeighbors = []
        testPoint = nil
        drawTestStrokes.removeAll()
        drawTestCurrentStroke.removeAll()

        if mode == .photo, currentTestIndex < testImages.count {
            let next = testImages[currentTestIndex]
            if !next.features.isEmpty {
                let pt = ImageFeatureExtractor.projectTo2D(features: next.features)
                testPoint = KNNDataPoint(label: "?", x: pt.x, y: pt.y, emoji: "?")
            }
        }
    }

    // Mode toggle
    private func toggleMode() {
        let newMode: Chapter3KNNRescueMode = (mode == .photo) ? .drawFallback : .photo
        withAnimation(.easeInOut(duration: 0.25)) {
            mode = newMode
        }
        // Reset collect state when switching
        trainingPoints.removeAll()
        trainingFeatures.removeAll()
        if newMode == .photo {
            addChat("Switching to photo mode...", isUser: true)
        } else {
            drawCurrentLabel = "1"
            drawCurrentIndex = 0
            drawSamples.removeAll()
            addChat("Switching to drawing mode...", isUser: true)
        }
    }

    // Chat helpers

    private func initChat() {
        guard !didInitializeChat else { return }
        didInitializeChat = true
        addChat("Signal fragmenting... I need KNN anchors. Upload photos or draw samples to train KNN!", isUser: false)
        addChat("On it! Starting the rescue.", isUser: true)
    }

    private func addChat(_ text: String, isUser: Bool) {
        chatMessages.append(TrainingChatMessage(text: text, isUser: isUser))
    }
}

// MARK: - Drawing Canvas (improved with proper centering)
private struct KNNDrawingCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]
    @Binding var canvasSize: CGSize

    private static func renderStroke(_ stroke: [CGPoint], in ctx: inout GraphicsContext) {
        let style = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        if stroke.count > 1 {
            var path = Path()
            path.move(to: stroke[0])
            for i in 1..<stroke.count {
                let prev = stroke[i - 1]
                let curr = stroke[i]
                let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                path.addQuadCurve(to: mid, control: prev)
            }
            if let last = stroke.last {
                path.addLine(to: last)
            }
            ctx.stroke(path, with: .color(.white), style: style)
        } else if stroke.count == 1 {
            let pt = stroke[0]
            let rect = CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)
            ctx.fill(Circle().path(in: rect), with: .color(.white))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = min(geo.size.width, 260)
            canvasView(size: size)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 260)
    }

    private func canvasView(size: CGFloat) -> some View {
        Canvas { ctx, _ in
            for stroke in strokes {
                KNNDrawingCanvas.renderStroke(stroke, in: &ctx)
            }
            KNNDrawingCanvas.renderStroke(currentStroke, in: &ctx)
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    let clamped = CGPoint(
                        x: min(max(v.location.x, 0), size),
                        y: min(max(v.location.y, 0), size)
                    )
                    currentStroke.append(clamped)
                }
                .onEnded { _ in
                    if !currentStroke.isEmpty {
                        strokes.append(currentStroke)
                    }
                    currentStroke = []
                }
        )
        .onAppear { canvasSize = CGSize(width: size, height: size) }
    }
}

