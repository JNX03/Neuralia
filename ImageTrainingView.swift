import SwiftUI

// MARK: - Drawing Sample
struct DrawingSample: Identifiable, Codable {
    let id = UUID()
    var label: String
    var grid: [[Bool]]
    
    static func fromStrokes(_ strokes: [[CGPoint]], label: String, canvasSize: CGSize) -> DrawingSample {
        let gridSize = 28
        var grid = Array(repeating: Array(repeating: false, count: gridSize), count: gridSize)
        
        for stroke in strokes {
            for point in stroke {
                let x = Int((point.x / canvasSize.width) * CGFloat(gridSize))
                let y = Int((point.y / canvasSize.height) * CGFloat(gridSize))
                if x >= 0 && x < gridSize && y >= 0 && y < gridSize {
                    grid[y][x] = true
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let nx = x + dx, ny = y + dy
                            if nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize {
                                grid[ny][nx] = true
                            }
                        }
                    }
                }
            }
        }
        return DrawingSample(label: label, grid: grid)
    }
    
    func featureVector() -> [Double] {
        var features: [Double] = []
        // Row densities (28)
        for row in grid {
            features.append(Double(row.filter { $0 }.count) / 28.0)
        }
        // Column densities (28)
        for col in 0..<28 {
            var count = 0
            for row in 0..<28 { if grid[row][col] { count += 1 } }
            features.append(Double(count) / 28.0)
        }
        // 4 quadrants
        for qy in 0..<2 {
            for qx in 0..<2 {
                var count = 0
                for y in (qy*14)..<((qy+1)*14) {
                    for x in (qx*14)..<((qx+1)*14) {
                        if grid[y][x] { count += 1 }
                    }
                }
                features.append(Double(count) / 196.0)
            }
        }
        // Center of mass
        var sumX = 0.0, sumY = 0.0, total = 0.0
        for y in 0..<28 {
            for x in 0..<28 {
                if grid[y][x] {
                    sumX += Double(x)
                    sumY += Double(y)
                    total += 1
                }
            }
        }
        features.append(total > 0 ? sumX / total / 28.0 : 0.5)
        features.append(total > 0 ? sumY / total / 28.0 : 0.5)
        return features
    }
}

// MARK: - KNN Classified
class KNNClassifier: ObservableObject {
    @Published var trainingSamples: [DrawingSample] = []
    @Published var k: Int = 3
    @Published var isTrained = false
    
    func addSample(_ sample: DrawingSample) {
        trainingSamples.append(sample)
    }
    
    func removeSample(id: UUID) {
        trainingSamples.removeAll { $0.id == id }
    }
    
    func removeSamples(for label: String) {
        trainingSamples.removeAll { $0.label == label }
        isTrained = !trainingSamples.isEmpty && Set(trainingSamples.map { $0.label }).count >= 2
    }
    
    func clear() {
        trainingSamples.removeAll()
        isTrained = false
    }
    
    func train() {
        let uniqueClasses = Set(trainingSamples.map { $0.label })
        isTrained = trainingSamples.count >= 2 && uniqueClasses.count >= 2
    }
    
    func classify(_ sample: DrawingSample) -> (label: String, confidence: Double) {
        guard isTrained else { return ("Untrained", 0.0) }
        
        let testFeatures = sample.featureVector()
        var distances: [(label: String, distance: Double)] = trainingSamples.map { train in
            let trainFeatures = train.featureVector()
            var sum = 0.0
            for i in 0..<min(testFeatures.count, trainFeatures.count) {
                let diff = testFeatures[i] - trainFeatures[i]
                sum += diff * diff
            }
            return (train.label, sqrt(sum))
        }
        
        distances.sort { $0.distance < $1.distance }
        let kNearest = distances.prefix(k)
        
        var votes: [String: Int] = [:]
        for n in kNearest { votes[n.label, default: 0] += 1 }
        
        let winner = votes.max { $0.value < $1.value }?.key ?? "Unknown"
        let confidence = Double(votes[winner] ?? 0) / Double(k)
        
        return (winner, confidence)
    }
}

// MARK: - Adaptive Layout Helper
struct AdaptiveLayout {
    let width: CGFloat
    let height: CGFloat
    let isCompact: Bool
    let isPad: Bool
    let isPhone: Bool
    
    init(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) {
        width = size.width
        height = size.height
        isCompact = horizontalSizeClass == .compact
        isPad = UIDevice.current.userInterfaceIdiom == .pad
        isPhone = UIDevice.current.userInterfaceIdiom == .phone
    }
    
    var padding: CGFloat {
        if width < 400 { return 12 }
        if width < 800 { return 16 }
        return 24
    }
    
    var spacing: CGFloat {
        if width < 400 { return 8 }
        if width < 800 { return 12 }
        return 16
    }
    
    var cornerRadius: CGFloat {
        if width < 400 { return 8 }
        return 12
    }
    
    var buttonHeight: CGFloat {
        if width < 400 { return 40 }
        if width < 800 { return 44 }
        return 48
    }
    
    var fontSize: CGFloat {
        if width < 400 { return 14 }
        if width < 800 { return 16 }
        return 18
    }
    
    var titleSize: CGFloat {
        if width < 400 { return 18 }
        if width < 800 { return 22 }
        return 26
    }
    
    var canvasHeight: CGFloat {
        if isPhone && isCompact { return min(width * 0.7, 280) }
        if isPhone { return min(width * 0.5, 320) }
        return min(height * 0.35, 350)
    }
    
    var thumbSize: CGFloat {
        if width < 400 { return 50 }
        if width < 800 { return 60 }
        return 70
    }
}

// MARK: - Main View
struct ImageTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var knn = KNNClassifier()
    
    // Training
    @State private var trainStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var trainCanvasSize: CGSize = .zero
    
    // Testing
    @State private var testStrokes: [[CGPoint]] = []
    @State private var testStroke: [CGPoint] = []
    @State private var testCanvasSize: CGSize = .zero
    @State private var prediction: (label: String, confidence: Double)?
    
    // Classes
    @State private var classes = ["Circle", "Square", "Triangle"]
    @State private var selectedClass = "Circle"
    @State private var showAddClass = false
    @State private var classToDelete: String?
    
    var body: some View {
        GeometryReader { geo in
            let layout = AdaptiveLayout(size: geo.size, horizontalSizeClass: horizontalSizeClass)
            
            NavigationStack {
                Group {
                    if layout.isPhone && layout.isCompact {
                        // iPhone Portrait - Tab style
                        PhonePortraitView(layout: layout, knn: knn, classes: $classes, selected: $selectedClass, 
                                        trainStrokes: $trainStrokes, currentStroke: $currentStroke, trainCanvasSize: $trainCanvasSize,
                                        testStrokes: $testStrokes, testStroke: $testStroke, testCanvasSize: $testCanvasSize,
                                        prediction: $prediction, classToDelete: $classToDelete)
                    } else if layout.isPhone {
                        // iPhone Landscape - Split
                        PhoneLandscapeView(layout: layout, knn: knn, classes: $classes, selected: $selectedClass,
                                         trainStrokes: $trainStrokes, currentStroke: $currentStroke, trainCanvasSize: $trainCanvasSize,
                                         testStrokes: $testStrokes, testStroke: $testStroke, testCanvasSize: $testCanvasSize,
                                         prediction: $prediction, classToDelete: $classToDelete)
                    } else {
                        // iPad/Mac - Full layout
                        TabletView(layout: layout, knn: knn, classes: $classes, selected: $selectedClass,
                                  trainStrokes: $trainStrokes, currentStroke: $currentStroke, trainCanvasSize: $trainCanvasSize,
                                  testStrokes: $testStrokes, testStroke: $testStroke, testCanvasSize: $testCanvasSize,
                                  prediction: $prediction, classToDelete: $classToDelete)
                    }
                }
                .navigationTitle("Drawing Classifier")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if knn.trainingSamples.count > 0 {
                            Button(action: { knn.clear() }) {
                                Text("Reset")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddClass) {
                AddClassSheet(classes: $classes, selected: $selectedClass, isPresented: $showAddClass)
            }
            .alert("Delete Class?", isPresented: .constant(classToDelete != nil), presenting: classToDelete) { className in
                Button("Cancel", role: .cancel) { classToDelete = nil }
                Button("Delete", role: .destructive) {
                    classes.removeAll { $0 == className }
                    knn.removeSamples(for: className)
                    if selectedClass == className, let first = classes.first {
                        selectedClass = first
                    }
                    classToDelete = nil
                }
            } message: { className in
                Text("Delete '\(className)' and all its samples?")
            }
        }
    }
}

// MARK: - iPhone Portrait
struct PhonePortraitView: View {
    let layout: AdaptiveLayout
    @ObservedObject var knn: KNNClassifier
    @Binding var classes: [String]
    @Binding var selected: String
    @Binding var trainStrokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]
    @Binding var trainCanvasSize: CGSize
    @Binding var testStrokes: [[CGPoint]]
    @Binding var testStroke: [CGPoint]
    @Binding var testCanvasSize: CGSize
    @Binding var prediction: (label: String, confidence: Double)?
    @Binding var classToDelete: String?
    @State private var selectedTab = 0
    @State private var showAddClass = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Train Tab
            ScrollView {
                VStack(spacing: layout.spacing) {
                    ClassSelector(classes: $classes, selected: $selected, samples: knn.trainingSamples, layout: layout) {
                        showAddClass = true
                    } onDelete: { classToDelete = $0 }
                    
                    DrawingCanvas(strokes: $trainStrokes, currentStroke: $currentStroke, canvasSize: $trainCanvasSize, layout: layout, accent: .blue)
                    
                    HStack(spacing: layout.spacing) {
                        SecondaryButton(title: "Clear", action: { trainStrokes.removeAll() }, layout: layout)
                        PrimaryButton(title: "Add Sample", action: addSample, layout: layout, disabled: trainStrokes.isEmpty)
                    }
                    
                    if knn.trainingSamples.count > 0 {
                        DatasetSection(knn: knn, layout: layout)
                    }
                }
                .padding(layout.padding)
            }
            .tabItem {
                Image(systemName: "pencil")
                Text("Train")
            }
            .tag(0)
            
            // Test Tab
            ScrollView {
                VStack(spacing: layout.spacing) {
                    if knn.isTrained {
                        StatusBadge(status: .ready, layout: layout)
                    } else {
                        StatusBadge(status: .needsTraining, layout: layout)
                    }
                    
                    DrawingCanvas(strokes: $testStrokes, currentStroke: $testStroke, canvasSize: $testCanvasSize, layout: layout, accent: .green)
                    
                    HStack(spacing: layout.spacing) {
                        SecondaryButton(title: "Clear", action: { testStrokes.removeAll(); prediction = nil }, layout: layout)
                        PrimaryButton(title: "Predict", action: predict, layout: layout, disabled: !knn.isTrained || testStrokes.isEmpty, color: .green)
                    }
                    
                    if let result = prediction {
                        PredictionCard(result: result, layout: layout)
                    }
                    
                    if knn.isTrained {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("K-Neighbors: \(knn.k)")
                                .font(.system(size: layout.fontSize - 2))
                                .foregroundColor(.secondary)
                            Slider(value: .init(get: { Double(knn.k) }, set: { knn.k = Int($0) }), in: 1...10, step: 1)
                        }
                        .padding(layout.padding)
                        .background(Color(.systemGray6))
                        .cornerRadius(layout.cornerRadius)
                    }
                }
                .padding(layout.padding)
            }
            .tabItem {
                Image(systemName: "eye")
                Text("Test")
            }
            .tag(1)
        }
        .sheet(isPresented: $showAddClass) {
            AddClassSheet(classes: $classes, selected: $selected, isPresented: $showAddClass)
        }
    }
    
    private func addSample() {
        guard !trainStrokes.isEmpty && trainCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(trainStrokes, label: selected, canvasSize: trainCanvasSize)
        knn.addSample(sample)
        knn.train()
        trainStrokes.removeAll()
    }
    
    private func predict() {
        guard !testStrokes.isEmpty && testCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(testStrokes, label: "test", canvasSize: testCanvasSize)
        prediction = knn.classify(sample)
    }
}

// MARK: - iPhone Landscape
struct PhoneLandscapeView: View {
    let layout: AdaptiveLayout
    @ObservedObject var knn: KNNClassifier
    @Binding var classes: [String]
    @Binding var selected: String
    @Binding var trainStrokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]
    @Binding var trainCanvasSize: CGSize
    @Binding var testStrokes: [[CGPoint]]
    @Binding var testStroke: [CGPoint]
    @Binding var testCanvasSize: CGSize
    @Binding var prediction: (label: String, confidence: Double)?
    @Binding var classToDelete: String?
    @State private var showAddClass = false
    @State private var showDataset = false
    
    var body: some View {
        HStack(spacing: layout.spacing) {
            // Left: Training
            ScrollView {
                VStack(spacing: layout.spacing) {
                    ClassSelector(classes: $classes, selected: $selected, samples: knn.trainingSamples, layout: layout) {
                        showAddClass = true
                    } onDelete: { classToDelete = $0 }
                    
                    DrawingCanvas(strokes: $trainStrokes, currentStroke: $currentStroke, canvasSize: $trainCanvasSize, layout: layout, accent: .blue)
                    
                    HStack(spacing: layout.spacing) {
                        SecondaryButton(title: "Clear", action: { trainStrokes.removeAll() }, layout: layout)
                        PrimaryButton(title: "Add", action: addSample, layout: layout, disabled: trainStrokes.isEmpty)
                    }
                    
                    if knn.trainingSamples.count > 0 {
                        Button(action: { showDataset = true }) {
                            HStack {
                                Text("View Dataset (\(knn.trainingSamples.count))")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: layout.fontSize))
                            .foregroundColor(.primary)
                            .padding(layout.padding)
                            .background(Color(.systemGray6))
                            .cornerRadius(layout.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(layout.padding)
            }
            .frame(width: layout.width * 0.5)
            
            Divider()
            
            // Right: Testing
            ScrollView {
                VStack(spacing: layout.spacing) {
                    if knn.isTrained {
                        StatusBadge(status: .ready, layout: layout)
                    } else {
                        StatusBadge(status: .needsTraining, layout: layout)
                    }
                    
                    DrawingCanvas(strokes: $testStrokes, currentStroke: $testStroke, canvasSize: $testCanvasSize, layout: layout, accent: .green)
                    
                    HStack(spacing: layout.spacing) {
                        SecondaryButton(title: "Clear", action: { testStrokes.removeAll(); prediction = nil }, layout: layout)
                        PrimaryButton(title: "Predict", action: predict, layout: layout, disabled: !knn.isTrained || testStrokes.isEmpty, color: .green)
                    }
                    
                    if let result = prediction {
                        PredictionCard(result: result, layout: layout)
                    } else {
                        PlaceholderCard(layout: layout)
                    }
                }
                .padding(layout.padding)
            }
            .frame(width: layout.width * 0.5)
        }
        .sheet(isPresented: $showAddClass) {
            AddClassSheet(classes: $classes, selected: $selected, isPresented: $showAddClass)
        }
        .sheet(isPresented: $showDataset) {
            DatasetSheet(knn: knn, layout: layout)
        }
    }
    
    private func addSample() {
        guard !trainStrokes.isEmpty && trainCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(trainStrokes, label: selected, canvasSize: trainCanvasSize)
        knn.addSample(sample)
        knn.train()
        trainStrokes.removeAll()
    }
    
    private func predict() {
        guard !testStrokes.isEmpty && testCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(testStrokes, label: "test", canvasSize: testCanvasSize)
        prediction = knn.classify(sample)
    }
}

// MARK: - iPad/Mac View
struct TabletView: View {
    let layout: AdaptiveLayout
    @ObservedObject var knn: KNNClassifier
    @Binding var classes: [String]
    @Binding var selected: String
    @Binding var trainStrokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]
    @Binding var trainCanvasSize: CGSize
    @Binding var testStrokes: [[CGPoint]]
    @Binding var testStroke: [CGPoint]
    @Binding var testCanvasSize: CGSize
    @Binding var prediction: (label: String, confidence: Double)?
    @Binding var classToDelete: String?
    @State private var showAddClass = false
    
    var body: some View {
        HStack(spacing: layout.spacing * 2) {
            // Left Column: Training
            VStack(spacing: layout.spacing) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training")
                            .font(.system(size: layout.titleSize, weight: .bold))
                        Text("\(knn.trainingSamples.count) total samples")
                            .font(.system(size: layout.fontSize - 2))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                ClassSelector(classes: $classes, selected: $selected, samples: knn.trainingSamples, layout: layout) {
                    showAddClass = true
                } onDelete: { classToDelete = $0 }
                
                DrawingCanvas(strokes: $trainStrokes, currentStroke: $currentStroke, canvasSize: $trainCanvasSize, layout: layout, accent: .blue)
                
                HStack(spacing: layout.spacing) {
                    SecondaryButton(title: "Clear Canvas", action: { trainStrokes.removeAll() }, layout: layout)
                    PrimaryButton(title: "Add Sample", action: addSample, layout: layout, disabled: trainStrokes.isEmpty)
                }
                
                if knn.trainingSamples.count > 0 {
                    DatasetSection(knn: knn, layout: layout)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Divider
            Divider()
            
            // Right Column: Testing
            VStack(spacing: layout.spacing) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Testing")
                            .font(.system(size: layout.titleSize, weight: .bold))
                        if knn.isTrained {
                            Label("Model Ready", systemImage: "checkmark.circle.fill")
                                .font(.system(size: layout.fontSize - 2))
                                .foregroundColor(.green)
                        } else {
                            Label("Need 2+ classes with samples", systemImage: "exclamationmark.circle")
                                .font(.system(size: layout.fontSize - 2))
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                }
                
                DrawingCanvas(strokes: $testStrokes, currentStroke: $testStroke, canvasSize: $testCanvasSize, layout: layout, accent: .green)
                
                HStack(spacing: layout.spacing) {
                    SecondaryButton(title: "Clear", action: { testStrokes.removeAll(); prediction = nil }, layout: layout)
                    PrimaryButton(title: "Predict", action: predict, layout: layout, disabled: !knn.isTrained || testStrokes.isEmpty, color: .green)
                }
                
                if let result = prediction {
                    PredictionCard(result: result, layout: layout)
                } else {
                    PlaceholderCard(layout: layout)
                }
                
                if knn.isTrained {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("K-Neighbors")
                                .font(.system(size: layout.fontSize - 1))
                            Spacer()
                            Text("\(knn.k)")
                                .font(.system(size: layout.fontSize - 1, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: .init(get: { Double(knn.k) }, set: { knn.k = Int($0) }), in: 1...10, step: 1)
                    }
                    .padding(layout.padding)
                    .background(Color(.systemGray6))
                    .cornerRadius(layout.cornerRadius)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(layout.padding)
        .sheet(isPresented: $showAddClass) {
            AddClassSheet(classes: $classes, selected: $selected, isPresented: $showAddClass)
        }
    }
    
    private func addSample() {
        guard !trainStrokes.isEmpty && trainCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(trainStrokes, label: selected, canvasSize: trainCanvasSize)
        knn.addSample(sample)
        knn.train()
        trainStrokes.removeAll()
    }
    
    private func predict() {
        guard !testStrokes.isEmpty && testCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(testStrokes, label: "test", canvasSize: testCanvasSize)
        prediction = knn.classify(sample)
    }
}

// MARK: - Components

struct ClassSelector: View {
    @Binding var classes: [String]
    @Binding var selected: String
    let samples: [DrawingSample]
    let layout: AdaptiveLayout
    let onAdd: () -> Void
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            HStack {
                Text("Classes")
                    .font(.system(size: layout.fontSize - 2, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: layout.fontSize - 2))
                    .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(classes, id: \.self) { className in
                        let count = samples.filter { $0.label == className }.count
                        ClassPill(name: className, count: count, isSelected: selected == className, layout: layout) {
                            selected = className
                        } onDelete: {
                            onDelete(className)
                        }
                    }
                }
            }
        }
    }
}

struct ClassPill: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let layout: AdaptiveLayout
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: layout.fontSize - 1, weight: isSelected ? .semibold : .regular))
            Text("\(count)")
                .font(.system(size: layout.fontSize - 3))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .cornerRadius(4)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: layout.fontSize - 4))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .foregroundColor(isSelected ? .blue : .primary)
        .cornerRadius(layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture(perform: onSelect)
    }
}

struct DrawingCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]
    @Binding var canvasSize: CGSize
    let layout: AdaptiveLayout
    let accent: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                
                // Subtle grid
                Canvas { context, size in
                    let step: CGFloat = 20
                    for x in stride(from: 0, to: size.width, by: step) {
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(p, with: .color(Color(.systemGray5)), lineWidth: 0.5)
                    }
                    for y in stride(from: 0, to: size.height, by: step) {
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(p, with: .color(Color(.systemGray5)), lineWidth: 0.5)
                    }
                }
                
                // Strokes
                Canvas { context, size in
                    for stroke in strokes {
                        if stroke.count > 1 {
                            var p = Path()
                            p.move(to: stroke[0])
                            for i in 1..<stroke.count { p.addLine(to: stroke[i]) }
                            context.stroke(p, with: .color(.black), lineWidth: 4)
                        }
                    }
                    if currentStroke.count > 1 {
                        var p = Path()
                        p.move(to: currentStroke[0])
                        for i in 1..<currentStroke.count { p.addLine(to: currentStroke[i]) }
                        context.stroke(p, with: .color(accent), lineWidth: 4)
                    }
                }
            }
            .cornerRadius(layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        currentStroke.append(value.location)
                    }
                    .onEnded { _ in
                        if !currentStroke.isEmpty {
                            strokes.append(currentStroke)
                            currentStroke = []
                        }
                    }
            )
            .onAppear { canvasSize = geo.size }
        }
        .frame(height: layout.canvasHeight)
    }
}

struct DatasetSection: View {
    @ObservedObject var knn: KNNClassifier
    let layout: AdaptiveLayout
    @State private var expandedClass: String?
    
    var grouped: [(label: String, samples: [DrawingSample])] {
        Dictionary(grouping: knn.trainingSamples) { $0.label }
            .map { (label: $0.key, samples: $0.value) }
            .sorted { $0.label < $1.label }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            Text("Dataset")
                .font(.system(size: layout.fontSize - 2, weight: .medium))
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: layout.spacing) {
                ForEach(grouped, id: \.label) { group in
                    DatasetClassRow(group: group, layout: layout, expanded: expandedClass == group.label) {
                        withAnimation {
                            expandedClass = expandedClass == group.label ? nil : group.label
                        }
                    } onDeleteSample: { sample in
                        knn.removeSample(id: sample.id)
                    }
                }
            }
        }
        .padding(layout.padding)
        .background(Color(.systemGray6))
        .cornerRadius(layout.cornerRadius)
    }
}

struct DatasetClassRow: View {
    let group: (label: String, samples: [DrawingSample])
    let layout: AdaptiveLayout
    let expanded: Bool
    let onExpand: () -> Void
    let onDeleteSample: (DrawingSample) -> Void
    
    var body: some View {
        VStack(spacing: layout.spacing) {
            Button(action: onExpand) {
                HStack {
                    Text(group.label)
                        .font(.system(size: layout.fontSize, weight: .medium))
                    Text("\(group.samples.count)")
                        .font(.system(size: layout.fontSize - 2))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            
            if expanded {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.thumbSize)), count: 4), spacing: 8) {
                    ForEach(group.samples) { sample in
                        SampleThumbnail(sample: sample, layout: layout) {
                            onDeleteSample(sample)
                        }
                    }
                }
            }
        }
        .padding(layout.padding)
        .background(Color.white)
        .cornerRadius(layout.cornerRadius)
    }
}

struct SampleThumbnail: View {
    let sample: DrawingSample
    let layout: AdaptiveLayout
    let onDelete: () -> Void
    @State private var showDelete = false
    
    var body: some View {
        Button(action: { showDelete = true }) {
            GridRenderer(grid: sample.grid)
                .frame(width: layout.thumbSize, height: layout.thumbSize)
                .background(Color(.systemGray6))
                .cornerRadius(layout.cornerRadius / 2)
        }
        .buttonStyle(.plain)
        .alert("Delete sample?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

struct GridRenderer: View {
    let grid: [[Bool]]
    
    var body: some View {
        Canvas { context, size in
            let w = size.width / 28
            let h = size.height / 28
            for y in 0..<28 {
                for x in 0..<28 {
                    if grid[y][x] {
                        let rect = CGRect(x: CGFloat(x) * w, y: CGFloat(y) * h, width: w + 0.5, height: h + 0.5)
                        context.fill(Path(rect), with: .color(.black))
                    }
                }
            }
        }
    }
}

struct PredictionCard: View {
    let result: (label: String, confidence: Double)
    let layout: AdaptiveLayout
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prediction")
                        .font(.system(size: layout.fontSize - 2))
                        .foregroundColor(.secondary)
                    Text(result.label)
                        .font(.system(size: layout.titleSize, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Confidence")
                        .font(.system(size: layout.fontSize - 2))
                        .foregroundColor(.secondary)
                    Text("\(Int(result.confidence * 100))%")
                        .font(.system(size: layout.fontSize + 4, weight: .semibold))
                        .foregroundColor(result.confidence > 0.7 ? .green : .orange)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(result.confidence > 0.7 ? Color.green : Color.orange)
                        .frame(width: geo.size.width * result.confidence, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(layout.padding)
        .background(Color.green.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(layout.cornerRadius)
    }
}

struct PlaceholderCard: View {
    let layout: AdaptiveLayout
    
    var body: some View {
        VStack(spacing: layout.spacing) {
            Image(systemName: "hand.draw")
                .font(.system(size: layout.fontSize * 2))
                .foregroundColor(Color(.systemGray4))
            Text("Draw and tap Predict")
                .font(.system(size: layout.fontSize))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(layout.padding * 2)
        .background(Color(.systemGray6))
        .cornerRadius(layout.cornerRadius)
    }
}

struct StatusBadge: View {
    enum Status { case ready, needsTraining }
    let status: Status
    let layout: AdaptiveLayout
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status == .ready ? "checkmark.circle.fill" : "exclamationmark.circle")
            Text(status == .ready ? "Model Ready" : "Add samples from 2+ classes")
        }
        .font(.system(size: layout.fontSize - 2))
        .foregroundColor(status == .ready ? .green : .orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((status == .ready ? Color.green : Color.orange).opacity(0.1))
        .cornerRadius(layout.cornerRadius / 2)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let layout: AdaptiveLayout
    var disabled: Bool = false
    var color: Color = .blue
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: layout.fontSize, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: layout.buttonHeight)
                .background(disabled ? Color(.systemGray5) : color)
                .foregroundColor(disabled ? .secondary : .white)
                .cornerRadius(layout.cornerRadius)
        }
        .disabled(disabled)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    let layout: AdaptiveLayout
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: layout.fontSize, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: layout.buttonHeight)
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(layout.cornerRadius)
        }
    }
}

struct AddClassSheet: View {
    @Binding var classes: [String]
    @Binding var selected: String
    @Binding var isPresented: Bool
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Class name", text: $name)
                    .autocapitalization(.words)
            }
            .navigationTitle("New Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && !classes.contains(trimmed) {
                            classes.append(trimmed)
                            selected = trimmed
                        }
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct DatasetSheet: View {
    @ObservedObject var knn: KNNClassifier
    let layout: AdaptiveLayout
    @Environment(\.dismiss) private var dismiss
    
    var grouped: [(label: String, samples: [DrawingSample])] {
        Dictionary(grouping: knn.trainingSamples) { $0.label }
            .map { (label: $0.key, samples: $0.value) }
            .sorted { $0.label < $1.label }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.label) { group in
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.thumbSize)), count: 4), spacing: 8) {
                            ForEach(group.samples) { sample in
                                SampleThumbnail(sample: sample, layout: layout) {
                                    knn.removeSample(id: sample.id)
                                }
                            }
                        }
                    } header: {
                        Text("\(group.label) (\(group.samples.count))")
                    }
                }
            }
            .navigationTitle("Dataset")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ImageTrainingView()
}
