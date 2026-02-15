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
            for i in 0..<stroke.count {
                let point = stroke[i]
                let x = Int((point.x / canvasSize.width) * CGFloat(gridSize))
                let y = Int((point.y / canvasSize.height) * CGFloat(gridSize))
                if x >= 0 && x < gridSize && y >= 0 && y < gridSize {
                    grid[y][x] = true
                    // Thicker lines
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
        // Row densities
        for row in grid {
            features.append(Double(row.filter { $0 }.count) / 28.0)
        }
        // Column densities
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
        isTrained = !trainingSamples.isEmpty
    }
    
    func removeSamples(for label: String) {
        trainingSamples.removeAll { $0.label == label }
        isTrained = !trainingSamples.isEmpty
    }
    
    func clear() {
        trainingSamples.removeAll()
        isTrained = false
    }
    
    func train() {
        isTrained = trainingSamples.count >= 2
    }
    
    func classify(_ sample: DrawingSample) -> (label: String, confidence: Double, allDistances: [(label: String, distance: Double)]) {
        guard isTrained && !trainingSamples.isEmpty else {
            return ("Untrained", 0.0, [])
        }
        
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
        
        return (winner, confidence, distances)
    }
}

// MARK: - Main View (Landscape)
struct ImageTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var knn = KNNClassifier()
    
    // Left side - Training
    @State private var trainStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var trainCanvasSize: CGSize = .zero
    
    // Right side - Preview
    @State private var previewStrokes: [[CGPoint]] = []
    @State private var previewStroke: [CGPoint] = []
    @State private var previewCanvasSize: CGSize = .zero
    @State private var predictionResult: (label: String, confidence: Double)?
    
    // Classes
    @State private var classes = ["Circle", "Square", "Triangle"]
    @State private var selectedClass = "Circle"
    @State private var showAddClass = false
    @State private var newClassName = ""
    @State private var classToDelete: String?
    @State private var showDeleteConfirm = false
    
    // UI States
    @State private var isDrawingMode = true
    
    var body: some View {
        GeometryReader { geo in
            let layout = ResponsiveLayout(width: geo.size.width, height: geo.size.height, safeAreaInsets: geo.safeAreaInsets)
            
            ZStack {
                MeshGradientBackground()
                
                HStack(spacing: layout.sectionSpacing) {
                    // LEFT SIDE: Training Area (55%)
                    VStack(spacing: layout.sectionSpacing) {
                        // Header
                        HStack {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: layout.scaled(24)))
                                .foregroundColor(.cyan)
                            Text("Training Data")
                                .font(.system(size: layout.headlineFontSize, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(knn.trainingSamples.count) samples")
                                .font(.system(size: layout.captionFontSize))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Class Selector
                        ClassBarView(classes: $classes, selected: $selectedClass, samples: knn.trainingSamples, layout: layout) {
                            showAddClass = true
                        } onDelete: { className in
                            classToDelete = className
                            showDeleteConfirm = true
                        }
                        
                        // Drawing Canvas
                        DrawingCanvas(
                            strokes: $trainStrokes,
                            currentStroke: $currentStroke,
                            canvasSize: $trainCanvasSize,
                            layout: layout,
                            title: "Draw \(selectedClass)",
                            color: .cyan
                        )
                        
                        // Training Actions
                        HStack(spacing: layout.elementSpacing) {
                            Button(action: { trainStrokes.removeAll() }) {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .orange, layout: layout))
                            
                            Button(action: addTrainingSample) {
                                Label("Add Sample", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .green, layout: layout))
                            .disabled(trainStrokes.isEmpty)
                            
                            Spacer()
                            
                            Button(action: { knn.train() }) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                    Text(knn.isTrained ? "Retrain" : "Train Model")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(color: knn.isTrained ? .purple : .cyan, layout: layout))
                            .disabled(knn.trainingSamples.count < 2)
                        }
                        
                        // Dataset Manager (Lower Left)
                        DatasetManagerView(knn: knn, layout: layout)
                    }
                    .frame(width: geo.size.width * 0.55)
                    
                    // RIGHT SIDE: Preview/Testing (45%)
                    VStack(spacing: layout.sectionSpacing) {
                        // Header
                        HStack {
                            Image(systemName: "eye.fill")
                                .font(.system(size: layout.scaled(24)))
                                .foregroundColor(.pink)
                            Text("Preview & Test")
                                .font(.system(size: layout.headlineFontSize, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        // Status
                        HStack {
                            Circle()
                                .fill(knn.isTrained ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(knn.isTrained ? "Model Ready" : "Need Training (2+ samples)")
                                .font(.system(size: layout.captionFontSize))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            if knn.isTrained {
                                Text("K = \(knn.k)")
                                    .font(.system(size: layout.captionFontSize))
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        // Preview Canvas
                        DrawingCanvas(
                            strokes: $previewStrokes,
                            currentStroke: $previewStroke,
                            canvasSize: $previewCanvasSize,
                            layout: layout,
                            title: "Test Drawing",
                            color: .pink
                        )
                        
                        // Prediction Actions
                        HStack(spacing: layout.elementSpacing) {
                            Button(action: { 
                                previewStrokes.removeAll()
                                predictionResult = nil
                            }) {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .orange, layout: layout))
                            
                            Spacer()
                            
                            Button(action: predict) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Predict")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .pink, layout: layout))
                            .disabled(!knn.isTrained || previewStrokes.isEmpty)
                        }
                        
                        // Result Display
                        if let result = predictionResult {
                            ResultCard(result: result, layout: layout)
                        } else {
                            PlaceholderCard(layout: layout)
                        }
                        
                        Spacer()
                        
                        // K Slider
                        if knn.isTrained {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("K-Neighbors: \(knn.k)")
                                    .font(.system(size: layout.captionFontSize))
                                    .foregroundColor(.white)
                                Slider(value: .init(
                                    get: { Double(knn.k) },
                                    set: { knn.k = Int($0) }
                                ), in: 1...10, step: 1)
                                .tint(.pink)
                            }
                            .padding(layout.padding)
                            .background(RoundedRectangle(cornerRadius: layout.cornerRadius).fill(.ultraThinMaterial))
                        }
                        
                        BackButton(action: { dismiss() }, layout: layout)
                    }
                    .frame(width: geo.size.width * 0.42)
                }
                .padding(.horizontal, layout.padding)
                .padding(.vertical, layout.padding)
            }
        }
        .sheet(isPresented: $showAddClass) {
            AddClassSheet(classes: $classes, selected: $selectedClass, isPresented: $showAddClass)
        }
        .alert("Delete Class?", isPresented: $showDeleteConfirm, presenting: classToDelete) { className in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                classes.removeAll { $0 == className }
                knn.removeSamples(for: className)
                if selectedClass == className, let first = classes.first {
                    selectedClass = first
                }
            }
        } message: { className in
            Text("This will delete all \(knn.trainingSamples.filter { $0.label == className }.count) samples for '\(className)'")
        }
    }
    
    private func addTrainingSample() {
        guard !trainStrokes.isEmpty && trainCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(trainStrokes, label: selectedClass, canvasSize: trainCanvasSize)
        knn.addSample(sample)
        withAnimation {
            trainStrokes.removeAll()
        }
    }
    
    private func predict() {
        guard !previewStrokes.isEmpty && previewCanvasSize != .zero else { return }
        let sample = DrawingSample.fromStrokes(previewStrokes, label: "test", canvasSize: previewCanvasSize)
        let result = knn.classify(sample)
        withAnimation {
            predictionResult = (result.label, result.confidence)
        }
    }
}

// MARK: - Class Bar
struct ClassBarView: View {
    @Binding var classes: [String]
    @Binding var selected: String
    let samples: [DrawingSample]
    let layout: ResponsiveLayout
    let onAdd: () -> Void
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack {
                Text("CLASSES")
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Class")
                    }
                    .font(.system(size: layout.captionFontSize))
                    .foregroundColor(.cyan)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: layout.elementSpacing) {
                    ForEach(classes, id: \.self) { className in
                        ClassPill(
                            name: className,
                            count: samples.filter { $0.label == className }.count,
                            isSelected: selected == className,
                            layout: layout
                        ) {
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
    let layout: ResponsiveLayout
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: layout.bodyFontSize, weight: .semibold))
                Text("\(count) samples")
                    .font(.system(size: layout.captionFontSize - 1))
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: layout.captionFontSize + 2))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
        .padding(.horizontal, layout.padding)
        .padding(.vertical, layout.elementSpacing)
        .background(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .fill(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Drawing Canvas
struct DrawingCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]
    @Binding var canvasSize: CGSize
    let layout: ResponsiveLayout
    let title: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack {
                Text(title)
                    .font(.system(size: layout.captionFontSize, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Text("\(strokes.count) strokes")
                    .font(.system(size: layout.captionFontSize - 1))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            GeometryReader { geo in
                ZStack {
                    // Grid
                    Canvas { context, size in
                        let step: CGFloat = 20
                        for x in stride(from: 0, to: size.width, by: step) {
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(p, with: .color(.white.opacity(0.03)), lineWidth: 1)
                        }
                        for y in stride(from: 0, to: size.height, by: step) {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(p, with: .color(.white.opacity(0.03)), lineWidth: 1)
                        }
                    }
                    
                    // Strokes
                    Canvas { context, size in
                        for stroke in strokes {
                            if stroke.count > 1 {
                                var p = Path()
                                p.move(to: stroke[0])
                                for i in 1..<stroke.count { p.addLine(to: stroke[i]) }
                                context.stroke(p, with: .color(.white), lineWidth: 5)
                            }
                        }
                        if currentStroke.count > 1 {
                            var p = Path()
                            p.move(to: currentStroke[0])
                            for i in 1..<currentStroke.count { p.addLine(to: currentStroke[i]) }
                            context.stroke(p, with: .color(color), lineWidth: 5)
                        }
                    }
                }
                .background(Color.black.opacity(0.4))
                .cornerRadius(layout.cornerRadius)
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
                .onChange(of: geo.size) { canvasSize = $0 }
            }
        }
        .padding(layout.padding)
        .background(RoundedRectangle(cornerRadius: layout.cornerRadius).fill(.ultraThinMaterial))
    }
}

// MARK: - Dataset Manager
struct DatasetManagerView: View {
    @ObservedObject var knn: KNNClassifier
    let layout: ResponsiveLayout
    @State private var expandedClass: String?
    
    var grouped: [(label: String, samples: [DrawingSample])] {
        let g = Dictionary(grouping: knn.trainingSamples) { $0.label }
        return g.map { (label: $0.key, samples: $0.value) }.sorted { $0.label < $1.label }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.elementSpacing) {
            HStack {
                Text("DATASET")
                    .font(.system(size: layout.captionFontSize, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if !knn.trainingSamples.isEmpty {
                    Button(action: { knn.clear() }) {
                        Text("Clear All")
                            .font(.system(size: layout.captionFontSize))
                            .foregroundColor(.red)
                    }
                }
            }
            
            if knn.trainingSamples.isEmpty {
                Text("No samples yet. Draw and add samples to train.")
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                        ForEach(grouped, id: \.label) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(group.label)
                                        .font(.system(size: layout.bodyFontSize, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("(\(group.samples.count))")
                                        .font(.system(size: layout.captionFontSize))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            expandedClass = expandedClass == group.label ? nil : group.label
                                        }
                                    }) {
                                        Image(systemName: expandedClass == group.label ? "chevron.down" : "chevron.right")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if expandedClass == group.label {
                                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.scaled(60))), count: 4), spacing: 8) {
                                        ForEach(group.samples) { sample in
                                            SampleThumb(sample: sample, layout: layout) {
                                                knn.removeSample(id: sample.id)
                                            }
                                        }
                                    }
                                } else {
                                    // Collapsed view - show count only
                                    HStack(spacing: -8) {
                                        ForEach(group.samples.prefix(5)) { sample in
                                            MiniThumb(sample: sample, layout: layout)
                                        }
                                        if group.samples.count > 5 {
                                            Text("+\(group.samples.count - 5)")
                                                .font(.system(size: layout.captionFontSize))
                                                .foregroundColor(.white.opacity(0.5))
                                                .padding(.leading, 12)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(layout.padding)
        .background(RoundedRectangle(cornerRadius: layout.cornerRadius).fill(.ultraThinMaterial))
    }
}

struct SampleThumb: View {
    let sample: DrawingSample
    let layout: ResponsiveLayout
    let onDelete: () -> Void
    @State private var showingDelete = false
    
    var body: some View {
        Button(action: { showingDelete = true }) {
            GridView(grid: sample.grid)
                .frame(width: layout.scaled(60), height: layout.scaled(60))
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete sample?", isPresented: $showingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

struct MiniThumb: View {
    let sample: DrawingSample
    let layout: ResponsiveLayout
    
    var body: some View {
        GridView(grid: sample.grid)
            .frame(width: layout.scaled(30), height: layout.scaled(30))
            .background(Color.black.opacity(0.3))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

struct GridView: View {
    let grid: [[Bool]]
    
    var body: some View {
        Canvas { context, size in
            let w = size.width / 28
            let h = size.height / 28
            for y in 0..<28 {
                for x in 0..<28 {
                    if grid[y][x] {
                        let rect = CGRect(x: CGFloat(x) * w, y: CGFloat(y) * h, width: w + 0.5, height: h + 0.5)
                        context.fill(Path(rect), with: .color(.white))
                    }
                }
            }
        }
    }
}

// MARK: - Result Card
struct ResultCard: View {
    let result: (label: String, confidence: Double)
    let layout: ResponsiveLayout
    
    var body: some View {
        VStack(spacing: layout.elementSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prediction")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.6))
                    Text(result.label)
                        .font(.system(size: layout.headlineFontSize + 4, weight: .bold))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Confidence")
                        .font(.system(size: layout.captionFontSize))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(Int(result.confidence * 100))%")
                        .font(.system(size: layout.headlineFontSize, weight: .bold))
                        .foregroundColor(result.confidence > 0.7 ? .green : .orange)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * result.confidence, height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding(layout.padding)
        .background(RoundedRectangle(cornerRadius: layout.cornerRadius).fill(Color.green.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }
}

struct PlaceholderCard: View {
    let layout: ResponsiveLayout
    var body: some View {
        VStack(spacing: layout.elementSpacing) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: layout.scaled(32)))
                .foregroundColor(.white.opacity(0.3))
            Text("Draw something and tap Predict")
                .font(.system(size: layout.bodyFontSize))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(layout.padding * 2)
        .background(RoundedRectangle(cornerRadius: layout.cornerRadius).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Add Class Sheet
struct AddClassSheet: View {
    @Binding var classes: [String]
    @Binding var selected: String
    @Binding var isPresented: Bool
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Class Name") {
                    TextField("e.g., Star, Heart", text: $name)
                        .autocapitalization(.words)
                }
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

// MARK: - Button Style
struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    let layout: ResponsiveLayout
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: layout.bodyFontSize, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, layout.padding)
            .padding(.vertical, layout.scaled(10))
            .background(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(color.opacity(configuration.isPressed ? 0.5 : 0.3))
                    .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(color.opacity(0.5), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

// MARK: - Preview
#Preview {
    ImageTrainingView()
        .preferredColorScheme(.dark)
}
