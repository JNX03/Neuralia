import SwiftUI
import PhotosUI

// MARK: - Training Chat Message
struct TrainingChatMessage: Identifiable, Equatable {
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

// MARK: - Training Sample Preview
struct TrainingSamplePreview: Identifiable {
    let id = UUID()
    let label: String
    let image: UIImage
}

// MARK: - Main MiniGame View (Classroom Style)
@MainActor
struct Chapter3KNNRescueMessagesMiniGame: View {
    let minigame: Chapter3KNNRescueMiniGame
    let layout: DialogAdaptiveLayout
    let isCompleted: Bool
    let onComplete: (String) -> Void
    
    @StateObject private var photoKNN = Chapter3PhotoKNNClassifier()
    
    @State private var mode: Chapter3KNNRescueMode = .photo
    @State private var selectedLabel: String
    @State private var chatMessages: [TrainingChatMessage] = []
    @State private var testRounds: [Chapter3KNNRescueTestRound] = []
    @State private var correctTestCount = 0
    
    // Training state
    @State private var trainingSamples: [TrainingSamplePreview] = []
    @State private var isTraining = false
    @State private var trainingProgress: Double = 0
    @State private var trainingResult: TrainingResult? = nil
    @State private var isTestingPhase = false
    @State private var currentTestRound = 0
    @State private var trainingTimer: Timer?
    
    @State private var showImagePicker = false
    @State private var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var captureIntent: Chapter3KNNCaptureIntent?
    
    // Drawing states
    @StateObject private var drawKNN = KNNClassifier()
    @State private var fallbackStrokes: [[CGPoint]] = []
    @State private var fallbackCurrentStroke: [CGPoint] = []
    @State private var fallbackCanvasSize: CGSize = .zero
    @State private var fallbackPrompt = "1"
    @State private var fallbackPrediction: (label: String, confidence: Double)?
    @State private var fallbackIsCorrect: Bool?
    @State private var drawCorrectCount = 0
    @State private var didLoadFallbackTemplates = false
    
    @State private var didInitializeChat = false
    @State private var didComplete = false
    
    // Training result enum
    enum TrainingResult {
        case success(correctCount: Int, totalCount: Int)
        case failure(correctCount: Int, totalCount: Int)
    }
    
    // AI Name from settings
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
    
    private var totalTrained: Int { trainingSamples.count }
    private var hasMinimumSamples: Bool {
        // At least 1 photo per class
        minigame.trainingLabels.allSatisfy { label in
            trainingSamples.contains { $0.label == label }
        }
    }
    private var photoRescuePassed: Bool { correctTestCount >= minigame.requiredCorrectTests }
    private var currentTestPrompt: String {
        let labels = minigame.trainingLabels
        guard !labels.isEmpty else { return "Pen" }
        return labels[testRounds.count % labels.count]
    }
    
    // Layout calculations
    private var stageMaxWidth: CGFloat {
        min(layout.width - (layout.isCompact ? 12 : 24), layout.isCompact ? 760 : 1500)
    }
    private var centerPanelMaxWidth: CGFloat {
        switch true {
        case layout.width < 700: return min(layout.width - 24, 700)
        case layout.width < 1100: return min(layout.width * 0.72, 820)
        default: return min(layout.width * 0.52, 860)
        }
    }
    private var spriteHeight: CGFloat {
        let lowerBound: CGFloat = layout.isCompact ? 205 : 265
        let upperBound: CGFloat = layout.isCompact ? 350 : 610
        return min(max(layout.height * (layout.isCompact ? 0.33 : 0.47), lowerBound), upperBound)
    }
    private var bottomDialogReserve: CGFloat {
        layout.width < 780 ? (layout.isCompact ? 264 : 286) : (layout.isCompact ? 220 : 256)
    }
    private var characterBottomOffset: CGFloat {
        max(0, bottomDialogReserve - (layout.isCompact ? 28 : 34))
    }
    
    var body: some View {
        ZStack {
            characterLayer
            
            VStack(spacing: layout.isCompact ? 6 : 8) {
                topUtilityRow
                
                VStack(spacing: 0) {
                    Spacer(minLength: layout.isCompact ? 8 : 12)
                    
                    centerTrainingPanel
                        .frame(maxWidth: centerPanelMaxWidth)
                    
                    Spacer(minLength: bottomDialogReserve)
                }
            }
            .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .top)
            
            bottomGradientOverlay
                .zIndex(1)
            
            bottomDialogLayer
                .zIndex(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showImagePicker, onDismiss: { captureIntent = nil }) {
            StoryDeviceImagePicker(sourceType: pickerSourceType) { image in
                handlePickedImage(image)
                showImagePicker = false
            } onCancel: {
                showImagePicker = false
            }
        }
        .onAppear {
            initializeChat()
        }
        .onDisappear {
            trainingTimer?.invalidate()
            trainingTimer = nil
        }
    }
    
    private var characterLayer: some View {
        ZStack(alignment: .bottom) {
            // Student/Player on left
            HStack {
                Image("char")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: spriteHeight)
                    .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                Spacer(minLength: 0)
            }
            
            // AI/Glitch on right
            HStack {
                Spacer(minLength: 0)
                Image("gltich")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: spriteHeight)
                    .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, layout.isCompact ? 6 : 10)
        .padding(.bottom, characterBottomOffset)
    }
    
    private var topUtilityRow: some View {
        HStack(spacing: 10) {
            Text("KNN Rescue")
                .font(.system(size: layout.captionFontSize + 2, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.34), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            
            if mode == .photo {
                Text("Photo Training Mode")
                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.24), in: Capsule())
            } else {
                Text("Drawing Fallback Mode")
                    .font(.system(size: layout.captionFontSize + 1, weight: .semibold))
                    .foregroundColor(.orange.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.24), in: Capsule())
            }
            
            Spacer(minLength: 8)
            
            // Mode toggle button
            Button(action: toggleMode) {
                Label(mode == .photo ? "Draw Mode" : "Photo Mode", systemImage: mode == .photo ? "pencil" : "camera")
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(mode == .photo ? Color.orange.opacity(0.5) : Color.blue.opacity(0.5), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var bottomGradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.58),
                .init(color: Color.black.opacity(0.22), location: 0.66),
                .init(color: Color.black.opacity(0.48), location: 0.78),
                .init(color: Color.black.opacity(0.78), location: 0.90),
                .init(color: Color.black.opacity(0.94), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, -(layout.dialogPadding + (layout.isCompact ? 18 : 28)))
        .allowsHitTesting(false)
    }
    
    private var bottomDialogLayer: some View {
        VStack(spacing: layout.isCompact ? 8 : 10) {
            Spacer()
            
            HStack(alignment: .top, spacing: layout.isCompact ? 12 : 18) {
                // Student dialog (left)
                dialogPane(
                    name: "You",
                    role: "Student",
                    text: lastUserMessage?.text ?? "Helping with the KNN rescue...",
                    accent: Color(hex: "2DA6FF"),
                    alignTrailing: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // AI dialog (right)
                dialogPane(
                    name: aiName,
                    role: "AI Friend",
                    text: lastAIMessage?.text ?? "Signal breaking... need anchors...",
                    accent: Color(hex: "F97316"),
                    alignTrailing: true
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            if (isCompleted || photoRescuePassed) && !didComplete {
                Button(action: { 
                    guard !didComplete else { return }
                    didComplete = true
                    onComplete("KNN Rescue Complete!") 
                }) {
                    Label("Continue Story", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: layout.isCompact ? 16 : 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.95))
                                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: stageMaxWidth, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .padding(.bottom, layout.isCompact ? 84 : 110)
    }
    
    private var lastUserMessage: TrainingChatMessage? {
        chatMessages.last { $0.isUser }
    }
    
    private var lastAIMessage: TrainingChatMessage? {
        chatMessages.last { !$0.isUser }
    }
    
    private func dialogPane(name: String, role: String, text: String, accent: Color, alignTrailing: Bool) -> some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: layout.isCompact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if alignTrailing { Spacer(minLength: 0) }
                
                Text(name)
                    .font(.system(size: layout.isCompact ? 20 : 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 2)
                
                Text(role)
                    .font(.system(size: layout.isCompact ? 12 : 15, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 1)
                
                if !alignTrailing { Spacer(minLength: 0) }
            }
            
            Text(text)
                .font(.system(size: layout.isCompact ? 13 : 17, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.97))
                .lineSpacing(layout.isCompact ? 3 : 5)
                .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
                .multilineTextAlignment(alignTrailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 2)
        }
        .padding(.horizontal, layout.isCompact ? 0 : 2)
    }
    
    @ViewBuilder
    private var centerTrainingPanel: some View {
        if mode == .photo {
            photoTrainingPanel
        } else {
            drawingFallbackPanel
        }
    }
    
    private var photoTrainingPanel: some View {
        VStack(spacing: 12) {
            // Header with progress
            HStack {
                Image(systemName: photoRescuePassed ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(photoRescuePassed ? .green : .orange)
                
                Text(photoRescuePassed ? "Rescue Complete" : isTraining ? "Training..." : (trainingResult != nil ? "Training Done" : "Collect Training Data"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(trainingSamples.count) photos")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(hasMinimumSamples ? .green : .orange)
            }
            
            // Progress bar
            if isTraining {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * trainingProgress, height: 6)
                            .animation(.linear(duration: 0.1), value: trainingProgress)
                    }
                }
                .frame(height: 6)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            if photoRescuePassed {
                // Completed state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Rescue Complete!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Signal stabilized at 99.98%")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 20)
            } else if isTraining {
                // Training animation state
                trainingAnimationView
            } else if let result = trainingResult {
                // Training result state
                trainingResultView(result: result)
            } else if isTestingPhase {
                // Testing phase
                testingPanel
            } else {
                // Collection UI
                VStack(spacing: 10) {
                    Text("ADD 1 PHOTO PER OBJECT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1)
                    
                    // Label indicators with counts
                    HStack(spacing: 8) {
                        ForEach(minigame.trainingLabels, id: \.self) { label in
                            LabelButton(
                                label: label,
                                count: sampleCount(for: label),
                                isSelected: selectedLabel == label
                            ) {
                                selectedLabel = label
                            }
                        }
                    }
                    
                    // Photo preview grid with delete option
                    if !trainingSamples.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(trainingSamples) { sample in
                                    samplePreviewCard(sample: sample)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .frame(height: 90)
                    }
                    
                    // Capture buttons
                    HStack(spacing: 12) {
                        Button(action: { presentPicker(source: .camera, intent: .training(label: selectedLabel)) }) {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                Text("Capture")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { presentPicker(source: .photoLibrary, intent: .training(label: selectedLabel)) }) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 20))
                                Text("Upload")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple.opacity(0.6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Train button (only enabled when minimum samples met)
                    Button(action: startTraining) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                            Text("Train KNN")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(hasMinimumSamples ? Color.green.opacity(0.7) : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasMinimumSamples)
                    
                    if !hasMinimumSamples {
                        Text("Add at least 1 photo for each: \(minigame.trainingLabels.joined(separator: ", "))")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private func samplePreviewCard(sample: TrainingSamplePreview) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: sample.image)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipped()
                .cornerRadius(8)
            
            // Delete button
            Button(action: { deleteSample(sample) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                    .background(Color.white.clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            
            // Label badge
            Text(sample.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 4, y: -4)
        }
    }
    
    private var trainingAnimationView: some View {
        VStack(spacing: 16) {
            // Animated neural network visualization
            ZStack {
                // Background circles
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.blue.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: 60 + CGFloat(i) * 30, height: 60 + CGFloat(i) * 30)
                        .scaleEffect(1 + 0.1 * sin(trainingProgress * 10 + Double(i)))
                }
                
                // Center core
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue, .purple],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "cpu")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    )
                    .rotationEffect(.degrees(trainingProgress * 360))
            }
            .frame(height: 120)
            
            Text("Training KNN... \(Int(trainingProgress * 100))%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Processing features from assets...")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }
    
    private func trainingResultView(result: TrainingResult) -> some View {
        VStack(spacing: 16) {
            switch result {
            case .success(let correct, let total):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Training Successful!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("KNN correctly classified \(correct)/\(total) test objects")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Ready for testing! Show me a photo of any object.")
                    .font(.system(size: 12))
                    .foregroundColor(.green.opacity(0.9))
                
                Button(action: startTesting) {
                    Label("Start Testing", systemImage: "play.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.7))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                
            case .failure(let correct, let total):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("Training Failed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("KNN only got \(correct)/\(total) correct")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Need at least 1 correct to continue. Try adding clearer photos.")
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.9))
                
                Button(action: resetTraining) {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.6))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var drawingFallbackPanel: some View {
        VStack(spacing: 12) {
            drawingFallbackHeader
            Divider().background(Color.white.opacity(0.2))
            drawingPrompt
            DrawingCanvasView(
                strokes: $fallbackStrokes,
                currentStroke: $fallbackCurrentStroke,
                canvasSize: $fallbackCanvasSize
            )
            drawingControls
            drawingPredictionView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var drawingFallbackHeader: some View {
        HStack {
            Image(systemName: "pencil.tip.crop.circle")
                .foregroundColor(.orange)
            Text("Drawing Fallback Mode")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    private var drawingPrompt: some View {
        VStack(spacing: 8) {
            Text("DRAW THIS NUMBER:")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)
            Text(fallbackPrompt)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                        )
                )
        }
    }
    
    private var drawingControls: some View {
        HStack(spacing: 12) {
            Button(action: {
                fallbackStrokes.removeAll()
                fallbackCurrentStroke.removeAll()
                fallbackPrediction = nil
            }) {
                Label("Clear", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.6))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Button(action: submitDrawing) {
                Label("Submit", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(fallbackStrokes.isEmpty ? Color.gray.opacity(0.5) : Color.green)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(fallbackStrokes.isEmpty)
        }
    }
    
    @ViewBuilder
    private var drawingPredictionView: some View {
        if let pred = fallbackPrediction {
            HStack {
                Text("Predicted: \(pred.label) (\(Int((pred.confidence * 100).rounded()))%)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if let isCorrect = fallbackIsCorrect {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                }
            }
            .padding(10)
            .background((fallbackIsCorrect == true ? Color.green : Color.red).opacity(0.15))
            .cornerRadius(10)
        }
    }
    
    private struct DrawingCanvasView: View {
        @Binding var strokes: [[CGPoint]]
        @Binding var currentStroke: [CGPoint]
        @Binding var canvasSize: CGSize
        
        private let baseCanvas: CGFloat = 280
        
        var body: some View {
            GeometryReader { geo in
                let size: CGFloat = min(geo.size.width, 280)
                Canvas { context, _ in
                    for stroke in strokes {
                        if stroke.count > 1 {
                            var path = Path()
                            path.move(to: stroke[0])
                            for point in stroke.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(path, with: .color(.white), lineWidth: 6)
                        }
                    }
                    if currentStroke.count > 1 {
                        var path = Path()
                        path.move(to: currentStroke[0])
                        for point in currentStroke.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(path, with: .color(.white), lineWidth: 6)
                    }
                }
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            var newStroke = currentStroke
                            let scaleX = size > 0 ? baseCanvas / size : 1
                            let scaleY = size > 0 ? baseCanvas / size : 1
                            newStroke.append(CGPoint(x: value.location.x * scaleX, y: value.location.y * scaleY))
                            currentStroke = newStroke
                        }
                        .onEnded { _ in
                            var newStrokes = strokes
                            newStrokes.append(currentStroke)
                            strokes = newStrokes
                            currentStroke = []
                        }
                )
                .onAppear {
                    canvasSize = CGSize(width: baseCanvas, height: baseCanvas)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 200)
        }
    }
    
    private func sampleCount(for label: String) -> Int {
        trainingSamples.filter { $0.label == label }.count
    }
    
    private func toggleMode() {
        withAnimation {
            mode = mode == .photo ? .drawFallback : .photo
            if mode == .drawFallback {
                addChatMessage("Switching to drawing fallback mode...", isUser: true)
                addChatMessage("Drawing mode active. Please draw the numbers I request.", isUser: false)
            } else {
                addChatMessage("Switching back to photo mode...", isUser: true)
            }
        }
    }
    
    private func presentPicker(source: UIImagePickerController.SourceType, intent: Chapter3KNNCaptureIntent) {
        pickerSourceType = source
        captureIntent = intent
        showImagePicker = true
    }
    
    private func handlePickedImage(_ image: UIImage) {
        guard let intent = captureIntent else { return }
        
        switch intent {
        case .training(let label):
            // Add to preview samples
            let preview = TrainingSamplePreview(label: label, image: image)
            trainingSamples.append(preview)
            addChatMessage("Added \(label) photo", isUser: true)
            
        case .testing(let expectedLabel):
            // Test mode - use trained KNN
            if let result = photoKNN.classify(image: image) {
                let isCorrect = result.label == expectedLabel
                let round = Chapter3KNNRescueTestRound(
                    expectedLabel: expectedLabel,
                    predictedLabel: result.label,
                    confidence: result.confidence,
                    isCorrect: isCorrect,
                    thumbnailData: image.jpegData(compressionQuality: 0.7)
                )
                testRounds.append(round)
                if isCorrect { correctTestCount += 1 }
                
                addChatMessage("Test: \(expectedLabel)", isUser: true, image: image, predictionLabel: result.label, confidence: result.confidence, isCorrect: isCorrect)
                
                if isCorrect {
                    addChatMessage("Correct! Confidence: \(Int((result.confidence * 100).rounded()))%", isUser: false)
                } else {
                    addChatMessage("Got \(result.label) instead. Try again!", isUser: false)
                }
                
                if correctTestCount >= minigame.requiredCorrectTests && !didComplete {
                    didComplete = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete("KNN Rescue Complete! 99.98% signal achieved.")
                    }
                }
            }
        }
    }
    
    private func deleteSample(_ sample: TrainingSamplePreview) {
        trainingSamples.removeAll { $0.id == sample.id }
        addChatMessage("Removed \(sample.label) photo", isUser: true)
    }
    
    private func startTraining() {
        guard hasMinimumSamples else { return }
        
        isTraining = true
        trainingProgress = 0
        trainingResult = nil
        
        addChatMessage("Starting KNN training...", isUser: true)
        addChatMessage("Processing... Please wait.", isUser: false)
        
        // Animate training progress
        var progress = 0.0
        trainingTimer?.invalidate()
        trainingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress += 0.05
            trainingProgress = min(progress, 1.0)
            
            if progress >= 1.0 {
                trainingTimer?.invalidate()
                trainingTimer = nil
                
                // Load asset images for evaluation
                evaluateTrainingWithAssets()
            }
        }
    }
    
    private func evaluateTrainingWithAssets() {
        // Load the user's training samples into KNN
        for sample in trainingSamples {
            _ = photoKNN.addSample(image: sample.image, label: sample.label)
        }
        
        // Test against asset images
        let testAssets = [
            (name: "bottle", label: "Bottle"),
            (name: "pen", label: "Pen"),
            (name: "hand", label: "Hand")
        ]
        
        var correct = 0
        var total = 0
        
        for asset in testAssets {
            if let image = UIImage(named: asset.name) {
                if let result = photoKNN.classify(image: image) {
                    total += 1
                    if result.label == asset.label {
                        correct += 1
                    }
                }
            }
        }
        
        isTraining = false
        
        if correct >= 1 {
            trainingResult = .success(correctCount: correct, totalCount: total)
            addChatMessage("Training complete! \(correct)/\(total) correct. Ready for testing.", isUser: false)
        } else {
            trainingResult = .failure(correctCount: correct, totalCount: total)
            addChatMessage("Training failed. Only \(correct)/\(total) correct. Try clearer photos.", isUser: false)
        }
    }
    
    private func resetTraining() {
        trainingResult = nil
        trainingSamples.removeAll()
        photoKNN.reset()
        isTestingPhase = false
        currentTestRound = 0
        correctTestCount = 0
        testRounds.removeAll()
        didComplete = false
        trainingTimer?.invalidate()
        trainingTimer = nil
        addChatMessage("Reset training data. Add new photos.", isUser: true)
    }
    
    private func startTesting() {
        withAnimation {
            trainingResult = nil
            isTestingPhase = true
            currentTestRound = 0
        }
        addChatMessage("Starting testing phase! Show me a photo of an object.", isUser: false)
    }
    
    private var testingPanel: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.green)
                
                Text("Testing Phase")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(correctTestCount)/\(minigame.requiredCorrectTests) correct")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(correctTestCount > 0 ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Progress
            HStack(spacing: 8) {
                ForEach(0..<minigame.requiredCorrectTests, id: \.self) { i in
                    Circle()
                        .fill(i < correctTestCount ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 12, height: 12)
                }
            }
            
            // Test prompt
            VStack(spacing: 8) {
                Text("TEST WITH AN OBJECT:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                
                Text("Show camera a photo of any trained object")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
            
            // Test buttons
            HStack(spacing: 12) {
                Button(action: { presentPicker(source: .camera, intent: .testing(expectedLabel: currentTestPrompt)) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22))
                        Text("Test Photo")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: { presentPicker(source: .photoLibrary, intent: .testing(expectedLabel: currentTestPrompt)) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                        Text("Upload")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.teal.opacity(0.6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            
            // Test results
            if !testRounds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Tests:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 8) {
                        ForEach(testRounds.prefix(3), id: \.id) { round in
                            testRoundBadge(round: round)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func testRoundBadge(round: Chapter3KNNRescueTestRound) -> some View {
        HStack(spacing: 4) {
            Image(systemName: round.isCorrect ? "checkmark" : "xmark")
                .font(.system(size: 10, weight: .bold))
            Text(round.expectedLabel.prefix(3))
                .font(.system(size: 10))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(round.isCorrect ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
        .cornerRadius(6)
    }
    
    private func submitDrawing() {
        guard !fallbackStrokes.isEmpty, fallbackCanvasSize != .zero else { return }
        
        // Load templates if needed
        loadFallbackDigitTemplatesIfNeeded()
        
        // Classify using KNN
        let sample = DrawingSample.fromStrokes(fallbackStrokes, label: "test", canvasSize: fallbackCanvasSize)
        let result = drawKNN.classify(sample)
        fallbackPrediction = result
        
        let isCorrect = result.label == fallbackPrompt
        fallbackIsCorrect = isCorrect
        
        if isCorrect {
            drawCorrectCount += 1
            addChatMessage("Correct! Drew \(fallbackPrompt)", isUser: true, predictionLabel: result.label, confidence: result.confidence, isCorrect: true)
            addChatMessage("Perfect! Recognized as \(result.label) with \(Int((result.confidence * 100).rounded()))% confidence.", isUser: false)
        } else {
            addChatMessage("Tried to draw \(fallbackPrompt)", isUser: true, predictionLabel: result.label, confidence: result.confidence, isCorrect: false)
            addChatMessage("I saw \(result.label) instead. Let's try again!", isUser: false)
        }
        
        // Generate next prompt
        fallbackStrokes.removeAll()
        fallbackCurrentStroke.removeAll()
        fallbackPrompt = randomFallbackDigit()
        
        if drawCorrectCount >= minigame.requiredCorrectTests && !didComplete {
            didComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete("KNN Rescue Complete via Drawing! 99.98% signal achieved.")
            }
        }
    }
    
    private func loadFallbackDigitTemplatesIfNeeded() {
        guard !didLoadFallbackTemplates else { return }
        didLoadFallbackTemplates = true
        
        let canvas = CGSize(width: 280, height: 280)
        let templates: [(String, [[CGPoint]])] = [
            ("1", [[CGPoint(x: 130, y: 50), CGPoint(x: 140, y: 50), CGPoint(x: 140, y: 230)]]),
            ("1", [[CGPoint(x: 120, y: 70), CGPoint(x: 135, y: 50), CGPoint(x: 135, y: 230)]]),
            
            ("2", [[CGPoint(x: 80, y: 70), CGPoint(x: 120, y: 50), CGPoint(x: 170, y: 55), CGPoint(x: 190, y: 95), CGPoint(x: 90, y: 210), CGPoint(x: 200, y: 210)]]),
            ("2", [[CGPoint(x: 85, y: 65), CGPoint(x: 140, y: 45), CGPoint(x: 180, y: 70), CGPoint(x: 170, y: 115), CGPoint(x: 80, y: 180), CGPoint(x: 85, y: 230), CGPoint(x: 200, y: 230)]]),
            
            ("3", [[CGPoint(x: 80, y: 70), CGPoint(x: 150, y: 55), CGPoint(x: 190, y: 85), CGPoint(x: 140, y: 135), CGPoint(x: 190, y: 185), CGPoint(x: 150, y: 230), CGPoint(x: 80, y: 215)]]),
            
            ("0", [[CGPoint(x: 110, y: 50), CGPoint(x: 170, y: 50), CGPoint(x: 190, y: 90), CGPoint(x: 190, y: 190), CGPoint(x: 170, y: 230), CGPoint(x: 110, y: 230), CGPoint(x: 90, y: 190), CGPoint(x: 90, y: 90), CGPoint(x: 110, y: 50)]]),
            
            ("4", [[CGPoint(x: 170, y: 50), CGPoint(x: 170, y: 230), CGPoint(x: 80, y: 140), CGPoint(x: 200, y: 140)]]),
            
            ("5", [[CGPoint(x: 180, y: 50), CGPoint(x: 100, y: 50), CGPoint(x: 90, y: 120), CGPoint(x: 170, y: 130), CGPoint(x: 190, y: 180), CGPoint(x: 160, y: 230), CGPoint(x: 90, y: 220)]])
        ]
        
        for (label, stroke) in templates {
            let sample = DrawingSample.fromStrokes(stroke, label: label, canvasSize: canvas)
            drawKNN.addSample(sample)
        }
        drawKNN.k = 3
        drawKNN.train()
    }
    
    private func randomFallbackDigit() -> String {
        ["0", "1", "2", "3", "4", "5"].randomElement() ?? "1"
    }
    
    private func initializeChat() {
        guard !didInitializeChat else { return }
        didInitializeChat = true
        
        addChatMessage("The signal is breaking... I need KNN anchors. Train me with: \(minigame.trainingLabels.joined(separator: ", "))", isUser: false)
        addChatMessage("I'll help! Starting the training now.", isUser: true)
    }
    
    private func addChatMessage(_ text: String, isUser: Bool, image: UIImage? = nil, predictionLabel: String? = nil, confidence: Double? = nil, isCorrect: Bool? = nil) {
        chatMessages.append(TrainingChatMessage(
            text: text,
            isUser: isUser,
            image: image,
            predictionLabel: predictionLabel,
            confidence: confidence,
            isCorrect: isCorrect
        ))
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
            HStack(spacing: 6) {
                Text(label)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(4)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.white.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

