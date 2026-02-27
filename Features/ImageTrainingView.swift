import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Drawing Sample with High-Resolution Gridde
struct DrawingSample: Identifiable, Codable {
    let id: UUID
    var label: String
    var grid: [[Bool]]
    var highResGrid: [[Bool]]  // 56x56 for better quality
    var originalStrokes: [[CGPoint]]  // Original canvas coordinates for display
    var normalizedStrokes: [[CGPoint]] // Normalized 0-1 for classification
    var canvasSize: CGSize
    
    static let gridSize = 28
    static let highResGridSize = 56
    
    init(id: UUID = UUID(), label: String, grid: [[Bool]], highResGrid: [[Bool]]? = nil, 
         originalStrokes: [[CGPoint]] = [], normalizedStrokes: [[CGPoint]] = [], canvasSize: CGSize = .zero) {
        self.id = id
        self.label = label
        self.grid = grid
        self.highResGrid = highResGrid ?? grid
        self.originalStrokes = originalStrokes
        self.normalizedStrokes = normalizedStrokes
        self.canvasSize = canvasSize
    }
    
    static func fromStrokes(_ strokes: [[CGPoint]], label: String, canvasSize: CGSize) -> DrawingSample {
        let gridSize = gridSize
        let highResSize = highResGridSize
        
        var grid = Array(repeating: Array(repeating: false, count: gridSize), count: gridSize)
        var highResGrid = Array(repeating: Array(repeating: false, count: highResSize), count: highResSize)
        
        // Normalize strokes to center and fit for classification
        let normalizedStrokes = normalizeStrokes(strokes, canvasSize: canvasSize)
        
        // Rasterize to low-res grid (28x28) with anti-aliasing
        for stroke in normalizedStrokes {
            for i in 0..<stroke.count {
                let point = stroke[i]
                let x = Int(point.x * CGFloat(gridSize))
                let y = Int(point.y * CGFloat(gridSize))
                
                if x >= 0 && x < gridSize && y >= 0 && y < gridSize {
                    grid[y][x] = true
                    // Add neighbors for thicker lines
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let nx = x + dx, ny = y + dy
                            if nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize {
                                grid[ny][nx] = true
                            }
                        }
                    }
                }
                
                // Draw line segments for continuous strokes
                if i > 0 {
                    let prev = stroke[i-1]
                    drawLineOnGrid(&grid, from: prev, to: point, gridSize: gridSize)
                }
            }
        }
        
        // Rasterize to high-res grid (56x56)
        for stroke in normalizedStrokes {
            for i in 0..<stroke.count {
                let point = stroke[i]
                let x = Int(point.x * CGFloat(highResSize))
                let y = Int(point.y * CGFloat(highResSize))
                
                if x >= 0 && x < highResSize && y >= 0 && y < highResSize {
                    highResGrid[y][x] = true
                    // Smaller brush for high-res
                    for dy in 0...1 {
                        for dx in 0...1 {
                            let nx = x + dx, ny = y + dy
                            if nx >= 0 && nx < highResSize && ny >= 0 && ny < highResSize {
                                highResGrid[ny][nx] = true
                            }
                        }
                    }
                }
                
                if i > 0 {
                    let prev = stroke[i-1]
                    drawLineOnGrid(&highResGrid, from: CGPoint(x: prev.x * CGFloat(highResSize), y: prev.y * CGFloat(highResSize)), 
                                  to: CGPoint(x: point.x * CGFloat(highResSize), y: point.y * CGFloat(highResSize)), gridSize: highResSize)
                }
            }
        }
        
        return DrawingSample(label: label, grid: grid, highResGrid: highResGrid, 
                             originalStrokes: strokes, normalizedStrokes: normalizedStrokes, canvasSize: canvasSize)
    }
    
    static func normalizeStrokes(_ strokes: [[CGPoint]], canvasSize: CGSize) -> [[CGPoint]] {
        // Find bounding box
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        
        for stroke in strokes {
            for point in stroke {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
        }
        
        let width = maxX - minX
        let height = maxY - minY
        let maxDim = max(width, height)
        
        guard maxDim > 0 else { return strokes }
        
        // Add padding
        let padding = maxDim * 0.15
        let scale = 1.0 / (maxDim + 2 * padding)
        
        // Center offset
        let offsetX = (maxDim - width) / 2 - padding
        let offsetY = (maxDim - height) / 2 - padding
        
        return strokes.map { stroke in
            stroke.map { point in
                CGPoint(
                    x: (point.x - minX + offsetX) * scale,
                    y: (point.y - minY + offsetY) * scale
                )
            }
        }
    }
    
    static func drawLineOnGrid(_ grid: inout [[Bool]], from: CGPoint, to: CGPoint, gridSize: Int) {
        let dx = abs(Int(to.x) - Int(from.x))
        let dy = abs(Int(to.y) - Int(from.y))
        let sx = from.x < to.x ? 1 : -1
        let sy = from.y < to.y ? 1 : -1
        var err = dx - dy
        var x = Int(from.x)
        var y = Int(from.y)
        
        while true {
            if x >= 0 && x < gridSize && y >= 0 && y < gridSize {
                grid[y][x] = true
            }
            if x == Int(to.x) && y == Int(to.y) { break }
            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }
    }
    
    // MARK: - Advanced Feature Extraction
    func featureVector() -> [Double] {
        var features: [Double] = []
        let size = DrawingSample.gridSize
        
        // 1. Row densities (28)
        for row in grid {
            features.append(Double(row.filter { $0 }.count) / Double(size))
        }
        
        // 2. Column densities (28)
        for col in 0..<size {
            var count = 0
            for row in 0..<size { if grid[row][col] { count += 1 } }
            features.append(Double(count) / Double(size))
        }
        
        // 3. Zone-based features (16 zones, 4x4)
        let zoneSize = size / 4
        for zy in 0..<4 {
            for zx in 0..<4 {
                var count = 0
                for y in (zy*zoneSize)..<((zy+1)*zoneSize) {
                    for x in (zx*zoneSize)..<((zx+1)*zoneSize) {
                        if grid[y][x] { count += 1 }
                    }
                }
                features.append(Double(count) / Double(zoneSize * zoneSize))
            }
        }
        
        // 4. Center of mass and spread
        var sumX = 0.0, sumY = 0.0, total = 0.0
        var sumX2 = 0.0, sumY2 = 0.0
        for y in 0..<size {
            for x in 0..<size {
                if grid[y][x] {
                    sumX += Double(x)
                    sumY += Double(y)
                    sumX2 += Double(x * x)
                    sumY2 += Double(y * y)
                    total += 1
                }
            }
        }
        
        if total > 0 {
            let meanX = sumX / total
            let meanY = sumY / total
            features.append(meanX / Double(size))
            features.append(meanY / Double(size))
            // Variance (spread)
            features.append(sqrt(sumX2/total - meanX*meanX) / Double(size))
            features.append(sqrt(sumY2/total - meanY*meanY) / Double(size))
        } else {
            features.append(contentsOf: [0.5, 0.5, 0, 0])
        }
        
        // 5. Perimeter and compactness
        var perimeter = 0
        for y in 0..<size {
            for x in 0..<size {
                if grid[y][x] {
                    // Check if edge pixel
                    var isEdge = false
                    for dy in -1...1 {
                        for dx in -1...1 {
                            if dx == 0 && dy == 0 { continue }
                            let nx = x + dx, ny = y + dy
                            if nx < 0 || nx >= size || ny < 0 || ny >= size || !grid[ny][nx] {
                                isEdge = true
                            }
                        }
                    }
                    if isEdge { perimeter += 1 }
                }
            }
        }
        features.append(Double(perimeter) / Double(size * 4))
        features.append(total > 0 ? Double(perimeter * perimeter) / total / 100.0 : 0)
        
        // 6. Horizontal and vertical projections (profile)
        for i in 0..<size/2 {
            // Left vs right density
            var left = 0, right = 0
            for y in 0..<size {
                for x in 0..<i {
                    if grid[y][x] { left += 1 }
                }
                for x in i..<size {
                    if grid[y][x] { right += 1 }
                }
            }
            features.append(Double(left) / max(Double(left + right), 1))
        }
        
        for i in 0..<size/2 {
            // Top vs bottom density
            var top = 0, bottom = 0
            for y in 0..<i {
                for x in 0..<size {
                    if grid[y][x] { top += 1 }
                }
            }
            for y in i..<size {
                for x in 0..<size {
                    if grid[y][x] { bottom += 1 }
                }
            }
            features.append(Double(top) / max(Double(top + bottom), 1))
        }
        
        // 7. Diagonal features
        var diag1 = 0, diag2 = 0, diag3 = 0, diag4 = 0
        for y in 0..<size {
            for x in 0..<size {
                if grid[y][x] {
                    if x > y { diag1 += 1 }
                    if x + y < size { diag2 += 1 }
                    if x > size/2 && y > size/2 { diag3 += 1 }
                    if x < size/2 && y > size/2 { diag4 += 1 }
                }
            }
        }
        features.append(Double(diag1) / Double(size * size))
        features.append(Double(diag2) / Double(size * size))
        features.append(Double(diag3) / Double(size * size / 4))
        features.append(Double(diag4) / Double(size * size / 4))
        
        // 8. Euler number (connectivity approximation)
        var components = 0
        var visited = Array(repeating: Array(repeating: false, count: size), count: size)
        for y in 0..<size {
            for x in 0..<size {
                if grid[y][x] && !visited[y][x] {
                    components += 1
                    // Flood fill
                    var stack = [(x, y)]
                    while !stack.isEmpty {
                        let (cx, cy) = stack.removeLast()
                        if cx < 0 || cx >= size || cy < 0 || cy >= size || visited[cy][cx] || !grid[cy][cx] {
                            continue
                        }
                        visited[cy][cx] = true
                        stack.append((cx+1, cy))
                        stack.append((cx-1, cy))
                        stack.append((cx, cy+1))
                        stack.append((cx, cy-1))
                    }
                }
            }
        }
        features.append(Double(min(components, 5)) / 5.0)
        
        // 9. Aspect ratio from bounding box
        var minX = size, maxX = 0, minY = size, maxY = 0
        for y in 0..<size {
            for x in 0..<size {
                if grid[y][x] {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        let bboxWidth = max(maxX - minX, 1)
        let bboxHeight = max(maxY - minY, 1)
        features.append(Double(bboxWidth) / Double(size))
        features.append(Double(bboxHeight) / Double(size))
        features.append(Double(bboxWidth) / Double(bboxHeight))
        
        return features
    }
    
    // Augment sample with small variations
    func augmentedSamples(count: Int) -> [DrawingSample] {
        var augmented: [DrawingSample] = [self]
        let size = DrawingSample.gridSize
        
        for _ in 0..<count {
            // Random small shifts
            let shiftX = Int.random(in: -1...1)
            let shiftY = Int.random(in: -1...1)
            
            var shifted = Array(repeating: Array(repeating: false, count: size), count: size)
            for y in 0..<size {
                for x in 0..<size {
                    if grid[y][x] {
                        let nx = x + shiftX
                        let ny = y + shiftY
                        if nx >= 0 && nx < size && ny >= 0 && ny < size {
                            shifted[ny][nx] = true
                        }
                    }
                }
            }
            
            // Small noise removal or addition
            for y in 0..<size {
                for x in 0..<size {
                    if Double.random(in: 0...1) < 0.02 {
                        shifted[y][x] = !shifted[y][x]
                    }
                }
            }
            
            augmented.append(DrawingSample(label: label, grid: shifted))
        }
        
        return augmented
    }
}

// MARK: - KNN Classifier with Advanced Features
class KNNClassifier: ObservableObject {
    @Published var trainingSamples: [DrawingSample] = []
    @Published var k: Int = 5
    @Published var isTrained = false
    @Published var useAugmentation = false
    @Published var augmentationFactor = 3
    @Published var featureWeights: [Double] = []
    @Published var distanceMetric: DistanceMetric = .euclidean
    @Published var lastPredictionDetails: PredictionDetails?
    
    enum DistanceMetric: String, CaseIterable {
        case euclidean = "Euclidean"
        case manhattan = "Manhattan"
        case cosine = "Cosine"
        case minkowski = "Minkowski"
    }
    
    struct PredictionDetails {
        let topMatches: [(label: String, distance: Double, sampleId: UUID)]
        let featureSimilarities: [Double]
        let processingTime: TimeInterval
    }
    
    func addSample(_ sample: DrawingSample) {
        trainingSamples.append(sample)
        updateTrainingStatus()
    }
    
    func removeSample(id: UUID) {
        trainingSamples.removeAll { $0.id == id }
        updateTrainingStatus()
    }
    
    func removeSamples(for label: String) {
        trainingSamples.removeAll { $0.label == label }
        updateTrainingStatus()
    }
    
    func clear() {
        trainingSamples.removeAll()
        isTrained = false
        lastPredictionDetails = nil
    }
    
    private func updateTrainingStatus() {
        let uniqueClasses = Set(trainingSamples.map { $0.label })
        isTrained = trainingSamples.count >= 2 && uniqueClasses.count >= 2
    }
    
    func train() {
        updateTrainingStatus()
        // Compute optimal feature weights based on variance
        computeFeatureWeights()
    }
    
    private func computeFeatureWeights() {
        guard !trainingSamples.isEmpty else { return }
        
        let features = trainingSamples.map { $0.featureVector() }
        let featureCount = features[0].count
        var weights = Array(repeating: 1.0, count: featureCount)
        
        // Calculate variance for each feature
        for i in 0..<featureCount {
            let values = features.map { $0[i] }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            // Higher weight for features with lower variance within classes and higher variance between classes
            weights[i] = 1.0 / (1.0 + variance)
        }
        
        featureWeights = weights
    }
    
    func classify(_ sample: DrawingSample) -> (label: String, confidence: Double) {
        guard isTrained else { return ("Untrained", 0.0) }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let testFeatures = sample.featureVector()
        
        // Get all samples including augmented if enabled
        var allSamples = trainingSamples
        if useAugmentation {
            for sample in trainingSamples {
                allSamples.append(contentsOf: sample.augmentedSamples(count: augmentationFactor))
            }
        }
        
        var distances: [(label: String, distance: Double, sampleId: UUID)] = allSamples.map { train in
            let trainFeatures = train.featureVector()
            let distance = calculateDistance(testFeatures, trainFeatures)
            return (train.label, distance, train.id)
        }
        
        distances.sort { $0.distance < $1.distance }
        let kNearest = distances.prefix(k)
        
        // Weighted voting by distance
        var votes: [String: Double] = [:]
        var totalWeight = 0.0
        
        for neighbor in kNearest {
            let weight = 1.0 / (1.0 + neighbor.distance)  // Inverse distance weighting
            votes[neighbor.label, default: 0] += weight
            totalWeight += weight
        }
        
        // Find winner
        let sortedVotes = votes.sorted { $0.value > $1.value }
        guard let winner = sortedVotes.first else {
            return ("Unknown", 0.0)
        }
        
        // Calculate confidence
        let winnerVotes = winner.value
        let confidence = winnerVotes / totalWeight
        
        // Store prediction details
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        lastPredictionDetails = PredictionDetails(
            topMatches: Array(kNearest),
            featureSimilarities: calculateSimilarities(testFeatures, allSamples),
            processingTime: processingTime
        )
        
        return (winner.key, confidence)
    }
    
    private func calculateDistance(_ a: [Double], _ b: [Double]) -> Double {
        let minCount = min(a.count, b.count)
        let weights = featureWeights.isEmpty ? Array(repeating: 1.0, count: minCount) : featureWeights
        
        switch distanceMetric {
        case .euclidean:
            var sum = 0.0
            for i in 0..<minCount {
                let diff = (a[i] - b[i]) * weights[i]
                sum += diff * diff
            }
            return sqrt(sum)
            
        case .manhattan:
            var sum = 0.0
            for i in 0..<minCount {
                sum += abs(a[i] - b[i]) * weights[i]
            }
            return sum
            
        case .cosine:
            var dot = 0.0, normA = 0.0, normB = 0.0
            for i in 0..<minCount {
                dot += a[i] * b[i] * weights[i]
                normA += a[i] * a[i] * weights[i]
                normB += b[i] * b[i] * weights[i]
            }
            return 1.0 - dot / (sqrt(normA) * sqrt(normB) + 1e-10)
            
        case .minkowski:
            let p = 3.0
            var sum = 0.0
            for i in 0..<minCount {
                sum += pow(abs(a[i] - b[i]) * weights[i], p)
            }
            return pow(sum, 1.0 / p)
        }
    }
    
    private func calculateSimilarities(_ testFeatures: [Double], _ samples: [DrawingSample]) -> [Double] {
        // Calculate average similarity per feature group
        let featureGroups = [
            ("Rows", 0..<28),
            ("Cols", 28..<56),
            ("Zones", 56..<72),
            ("Center", 72..<76),
            ("Shape", 76..<80)
        ]
        
        return featureGroups.map { _, range in
            var totalSim = 0.0
            for sample in samples.prefix(10) {
                let features = sample.featureVector()
                for i in range {
                    if i < testFeatures.count && i < features.count {
                        totalSim += 1.0 - abs(testFeatures[i] - features[i])
                    }
                }
            }
            return totalSim / Double(range.count * 10)
        }
    }
    
    func crossValidation() -> Double {
        guard trainingSamples.count >= 5 else { return 0.0 }
        
        var correct = 0
        var total = 0
        
        for i in 0..<trainingSamples.count {
            var tempSamples = trainingSamples
            let testSample = tempSamples.remove(at: i)
            
            // Temporarily set samples and classify
            let savedSamples = trainingSamples
            trainingSamples = tempSamples
            
            let result = classify(testSample)
            if result.label == testSample.label {
                correct += 1
            }
            total += 1
            
            trainingSamples = savedSamples
        }
        
        return Double(correct) / Double(total)
    }
}

// MARK: - Adaptive Layout Helper
struct AdaptiveLayout {
    let width: CGFloat
    let height: CGFloat
    let isCompact: Bool
    let isPad: Bool
    let isPhone: Bool
    
    @MainActor
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
        return canvasSize
    }
    
    var canvasSize: CGFloat {
        // Square canvas based on available width
        if isPhone && isCompact { 
            return min(width - (padding * 2), 320) 
        }
        if isPhone { 
            return min(width * 0.45, 320) 
        }
        return min(min(width * 0.4, height * 0.4), 350)
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
    @State private var classToDelete: String?
    
    var body: some View {
        GeometryReader { geo in
            let layout = AdaptiveLayout(size: geo.size, horizontalSizeClass: horizontalSizeClass)
            
            NavigationStack {
                platformContent(layout: layout)
                .navigationTitle("Drawing Classifier")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { navigationToolbar }
            }
            .alert("Delete Class?", isPresented: deleteClassAlertPresented, presenting: classToDelete) { className in
                Button("Cancel", role: .cancel) { classToDelete = nil }
                Button("Delete", role: .destructive) {
                    deleteClass(named: className)
                }
            } message: { className in
                Text("Delete '\(className)' and all its samples?")
            }
        }
    }
    
    @ViewBuilder
    private func platformContent(layout: AdaptiveLayout) -> some View {
        if layout.isPhone && layout.isCompact {
            phonePortraitContent(layout: layout)
        } else if layout.isPhone {
            phoneLandscapeContent(layout: layout)
        } else {
            tabletContent(layout: layout)
        }
    }
    
    private func phonePortraitContent(layout: AdaptiveLayout) -> some View {
        PhonePortraitView(
            layout: layout,
            knn: knn,
            classes: $classes,
            selected: $selectedClass,
            trainStrokes: $trainStrokes,
            currentStroke: $currentStroke,
            trainCanvasSize: $trainCanvasSize,
            testStrokes: $testStrokes,
            testStroke: $testStroke,
            testCanvasSize: $testCanvasSize,
            prediction: $prediction,
            classToDelete: $classToDelete
        )
    }
    
    private func phoneLandscapeContent(layout: AdaptiveLayout) -> some View {
        PhoneLandscapeView(
            layout: layout,
            knn: knn,
            classes: $classes,
            selected: $selectedClass,
            trainStrokes: $trainStrokes,
            currentStroke: $currentStroke,
            trainCanvasSize: $trainCanvasSize,
            testStrokes: $testStrokes,
            testStroke: $testStroke,
            testCanvasSize: $testCanvasSize,
            prediction: $prediction,
            classToDelete: $classToDelete
        )
    }
    
    private func tabletContent(layout: AdaptiveLayout) -> some View {
        TabletView(
            layout: layout,
            knn: knn,
            classes: $classes,
            selected: $selectedClass,
            trainStrokes: $trainStrokes,
            currentStroke: $currentStroke,
            trainCanvasSize: $trainCanvasSize,
            testStrokes: $testStrokes,
            testStroke: $testStroke,
            testCanvasSize: $testCanvasSize,
            prediction: $prediction,
            classToDelete: $classToDelete
        )
    }
    
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
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
    
    private var deleteClassAlertPresented: Binding<Bool> {
        Binding(
            get: { classToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    classToDelete = nil
                }
            }
        )
    }
    
    private func deleteClass(named className: String) {
        classes.removeAll { $0 == className }
        knn.removeSamples(for: className)
        
        if selectedClass == className, let first = classes.first {
            selectedClass = first
        }
        
        classToDelete = nil
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
    @State private var showSettings = false
    
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
                        PredictionCard(result: result, details: knn.lastPredictionDetails, layout: layout)
                    }
                    
                    if knn.isTrained {
                        AdvancedSettingsSection(knn: knn, layout: layout)
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
                        PredictionCard(result: result, details: knn.lastPredictionDetails, layout: layout)
                    } else {
                        PlaceholderCard(layout: layout)
                    }
                    
                    if knn.isTrained {
                        AdvancedSettingsSection(knn: knn, layout: layout)
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
                    PredictionCard(result: result, details: knn.lastPredictionDetails, layout: layout)
                } else {
                    PlaceholderCard(layout: layout)
                }
                
                if knn.isTrained {
                    AdvancedSettingsSection(knn: knn, layout: layout)
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
                
                // Strokes with smooth rendering
                Canvas { context, size in
                    for stroke in strokes {
                        if stroke.count > 1 {
                            var p = Path()
                            p.move(to: stroke[0])
                            // Use Catmull-Rom or simple smoothing
                            for i in 1..<stroke.count {
                                p.addLine(to: stroke[i])
                            }
                            context.stroke(p, with: .color(.black), lineWidth: 5)
                        }
                    }
                    if currentStroke.count > 1 {
                        var p = Path()
                        p.move(to: currentStroke[0])
                        for i in 1..<currentStroke.count {
                            p.addLine(to: currentStroke[i])
                        }
                        context.stroke(p, with: .color(accent), lineWidth: 5)
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
        .frame(width: layout.canvasSize, height: layout.canvasSize)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(group.label), \(group.samples.count) samples")
            .accessibilityHint(expanded ? "Double tap to collapse" : "Double tap to expand")
            
            if true { // Always open to prevent crash
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
            SmoothGridRenderer(sample: sample)
                .frame(width: layout.thumbSize, height: layout.thumbSize)
                .background(Color(.systemGray6))
                .cornerRadius(layout.cornerRadius / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sample drawing")
        .accessibilityHint("Double tap to delete")
        .alert("Delete sample?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

struct SmoothGridRenderer: View {
    let sample: DrawingSample
    
    // Calculate bounding box of all strokes
    private func calculateBounds(_ strokes: [[CGPoint]]) -> CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        
        for stroke in strokes {
            for point in stroke {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
        }
        
        if minX == CGFloat.infinity {
            return CGRect.zero
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.white
                
                // Render using original canvas strokes with proper bounds calculation
                if !sample.originalStrokes.isEmpty {
                    Canvas { context, size in
                        let bounds = calculateBounds(sample.originalStrokes)
                        guard bounds.width > 0 && bounds.height > 0 else { return }
                        
                        // Add padding around the drawing
                        let padding: CGFloat = 10
                        let availableWidth = size.width - padding * 2
                        let availableHeight = size.height - padding * 2
                        
                        // Scale to fit the thumbnail while maintaining aspect ratio
                        let scale = min(availableWidth / bounds.width, availableHeight / bounds.height)
                        
                        // Center the drawing in the thumbnail
                        let scaledWidth = bounds.width * scale
                        let scaledHeight = bounds.height * scale
                        let offsetX = (size.width - scaledWidth) / 2 - bounds.minX * scale
                        let offsetY = (size.height - scaledHeight) / 2 - bounds.minY * scale
                        
                        for stroke in sample.originalStrokes {
                            if stroke.count > 1 {
                                var p = Path()
                                p.move(to: CGPoint(
                                    x: stroke[0].x * scale + offsetX,
                                    y: stroke[0].y * scale + offsetY
                                ))
                                for i in 1..<stroke.count {
                                    p.addLine(to: CGPoint(
                                        x: stroke[i].x * scale + offsetX,
                                        y: stroke[i].y * scale + offsetY
                                    ))
                                }
                                context.stroke(p, with: .color(.black), lineWidth: 3)
                            }
                        }
                    }
                } else if !sample.normalizedStrokes.isEmpty {
                    // Fallback: use normalized strokes scaled to fit
                    Canvas { context, size in
                        for stroke in sample.normalizedStrokes {
                            if stroke.count > 1 {
                                var p = Path()
                                p.move(to: CGPoint(x: stroke[0].x * size.width, y: stroke[0].y * size.height))
                                for i in 1..<stroke.count {
                                    p.addLine(to: CGPoint(x: stroke[i].x * size.width, y: stroke[i].y * size.height))
                                }
                                context.stroke(p, with: .color(.black), lineWidth: 3)
                            }
                        }
                    }
                } else {
                    // Fallback to high-res grid
                    Canvas { context, size in
                        let grid = sample.highResGrid
                        let cellW = size.width / CGFloat(DrawingSample.highResGridSize)
                        let cellH = size.height / CGFloat(DrawingSample.highResGridSize)
                        
                        for y in 0..<DrawingSample.highResGridSize {
                            for x in 0..<DrawingSample.highResGridSize {
                                if grid[y][x] {
                                    let rect = CGRect(
                                        x: CGFloat(x) * cellW - 0.5,
                                        y: CGFloat(y) * cellH - 0.5,
                                        width: cellW + 1,
                                        height: cellH + 1
                                    )
                                    context.fill(Path(rect), with: .color(.black))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PredictionCard: View {
    let result: (label: String, confidence: Double)
    let details: KNNClassifier.PredictionDetails?
    let layout: AdaptiveLayout
    @EnvironmentObject private var settings: GlobalSettingsStore
    @State private var showDetails = false

    private var colors: AccessibleColors {
        AccessibleColors(colorBlindMode: settings.colorBlindMode)
    }

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
                    HStack(spacing: 4) {
                        // Always show icon for accessibility (not just in colorBlindMode)
                        Image(systemName: colors.confidenceIcon(for: result.confidence))
                            .font(.system(size: layout.fontSize))
                            .foregroundColor(colors.confidenceColor(for: result.confidence))
                        Text("\(Int(result.confidence * 100))%")
                            .font(.system(size: layout.fontSize + 4, weight: .semibold))
                            .foregroundColor(colors.confidenceColor(for: result.confidence))
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.confidenceColor(for: result.confidence))
                        .frame(width: geo.size.width * result.confidence, height: 8)
                }
            }
            .frame(height: 8)
            
            if let details = details {
                Divider()
                
                Button(action: { showDetails.toggle() }) {
                    HStack {
                        Text("Match Details")
                            .font(.system(size: layout.fontSize - 2))
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if true { // Always open to prevent crash
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(details.topMatches.prefix(5), id: \.sampleId) { match in
                            HStack {
                                Text(match.label)
                                    .font(.system(size: layout.fontSize - 2))
                                Spacer()
                                Text(String(format: "%.3f", match.distance))
                                    .font(.system(size: layout.fontSize - 3, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if details.processingTime > 0 {
                            Text("Processing: \(String(format: "%.2f", details.processingTime * 1000))ms")
                                .font(.system(size: layout.fontSize - 4))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(layout.padding)
        .background(colors.success.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(colors.success.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(layout.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prediction: \(result.label), \(colors.confidenceLabel(for: result.confidence)), \(Int(result.confidence * 100)) percent")
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
        .foregroundColor(status == .ready ? Color(red: 0.13, green: 0.72, blue: 0.45) : Color(red: 0.95, green: 0.55, blue: 0.15))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((status == .ready ? Color(red: 0.13, green: 0.72, blue: 0.45) : Color(red: 0.95, green: 0.55, blue: 0.15)).opacity(0.1))
        .cornerRadius(layout.cornerRadius / 2)
        .accessibilityLabel(status == .ready ? "Model is ready for predictions" : "Add samples from 2 or more classes to train")
    }
}

struct AdvancedSettingsSection: View {
    @ObservedObject var knn: KNNClassifier
    let layout: AdaptiveLayout
    @State private var showAdvanced = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            Button(action: { showAdvanced.toggle() }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: layout.fontSize - 2))
                    Text("Training Settings")
                        .font(.system(size: layout.fontSize - 1, weight: .medium))
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            
            if true { // Always open to prevent crash
                VStack(spacing: 12) {
                    // K-Neighbors
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("K-Neighbors")
                                .font(.system(size: layout.fontSize - 2))
                            Spacer()
                            Text("\(knn.k)")
                                .font(.system(size: layout.fontSize - 2, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Slider(value: .init(get: { Double(knn.k) }, set: { knn.k = Int($0) }), in: 1...15, step: 1)
                    }
                    
                    Divider()
                    
                    // Distance Metric
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distance Metric")
                            .font(.system(size: layout.fontSize - 2))
                        Picker("Metric", selection: $knn.distanceMetric) {
                            ForEach(KNNClassifier.DistanceMetric.allCases, id: \.self) { metric in
                                Text(metric.rawValue).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    // Data Augmentation
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Data Augmentation", isOn: $knn.useAugmentation)
                            .font(.system(size: layout.fontSize - 2))
                        
                        if knn.useAugmentation {
                            HStack {
                                Text("Augmentation Factor")
                                    .font(.system(size: layout.fontSize - 3))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(knn.augmentationFactor)")
                                    .font(.system(size: layout.fontSize - 3))
                            }
                            Slider(value: .init(get: { Double(knn.augmentationFactor) }, set: { knn.augmentationFactor = Int($0) }), in: 1...10, step: 1)
                        }
                    }
                    
                    // Cross-validation score
                    if knn.trainingSamples.count >= 5 {
                        Divider()
                        HStack {
                            Text("Cross-Validation Accuracy")
                                .font(.system(size: layout.fontSize - 2))
                            Spacer()
                            let accuracy = knn.crossValidation()
                            Text("\(Int(accuracy * 100))%")
                                .font(.system(size: layout.fontSize - 2, weight: .medium))
                                .foregroundColor(accuracy > 0.8 ? Color(red: 0.13, green: 0.72, blue: 0.45) : (accuracy > 0.5 ? Color(red: 0.95, green: 0.55, blue: 0.15) : Color(red: 0.90, green: 0.25, blue: 0.20)))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(layout.padding)
        .background(Color(.systemGray6))
        .cornerRadius(layout.cornerRadius)
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

// MARK: - Chapter 3 Story KNN Rescue (Photo + Draw Fallback)

struct Chapter3PhotoKNNSample: Identifiable {
    let id: UUID
    let label: String
    let features: [Double]
    let thumbnailData: Data?

    init(id: UUID = UUID(), label: String, features: [Double], thumbnailData: Data?) {
        self.id = id
        self.label = label
        self.features = features
        self.thumbnailData = thumbnailData
    }
}

@MainActor
final class Chapter3PhotoKNNClassifier: ObservableObject {
    @Published private(set) var trainingSamples: [Chapter3PhotoKNNSample] = []
    var k: Int = 3

    var trainedLabels: [String] {
        Array(Set(trainingSamples.map(\.label))).sorted()
    }

    var isTrained: Bool {
        trainedLabels.count >= 2 && trainingSamples.count >= 2
    }

    func addSample(image: UIImage, label: String) -> Bool {
        guard let features = Chapter3PhotoFeatureExtractor.featureVector(from: image) else {
            return false
        }
        trainingSamples.append(
            Chapter3PhotoKNNSample(
                label: label,
                features: features,
                thumbnailData: Chapter3PhotoFeatureExtractor.thumbnailData(from: image)
            )
        )
        return true
    }

    func classify(image: UIImage) -> (label: String, confidence: Double)? {
        guard isTrained, let testFeatures = Chapter3PhotoFeatureExtractor.featureVector(from: image) else {
            return nil
        }

        let ranked = trainingSamples
            .map { sample in
                (sample: sample, distance: euclidean(testFeatures, sample.features))
            }
            .sorted { $0.distance < $1.distance }

        let neighbors = ranked.prefix(max(1, min(k, ranked.count)))
        var votes: [String: Double] = [:]
        var totalWeight = 0.0

        for entry in neighbors {
            let weight = 1.0 / max(entry.distance, 0.0001)
            votes[entry.sample.label, default: 0] += weight
            totalWeight += weight
        }

        guard let winner = votes.max(by: { $0.value < $1.value }) else { return nil }
        let confidence = totalWeight > 0 ? (winner.value / totalWeight) : 0
        return (winner.key, min(max(confidence, 0), 1))
    }
    
    func reset() {
        trainingSamples.removeAll()
    }

    private func euclidean(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return .greatestFiniteMagnitude }
        var sum = 0.0
        for i in 0..<count {
            let diff = lhs[i] - rhs[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
}

enum Chapter3PhotoFeatureExtractor {
    static func featureVector(from image: UIImage) -> [Double]? {
        let side = 32
        guard let normalized = resizedImage(image, side: side),
              let cgImage = normalized.cgImage else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var pixels = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let drawSucceeded = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: side,
                    height: side,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }

        guard drawSucceeded else { return nil }

        let gridCells = 8
        let cellSize = side / gridCells
        var gridLuma = Array(repeating: 0.0, count: gridCells * gridCells)
        var histogram = Array(repeating: 0.0, count: 27)
        var luminanceValues = Array(repeating: 0.0, count: side * side)
        var saturationSum = 0.0

        for y in 0..<side {
            for x in 0..<side {
                let offset = (y * side + x) * bytesPerPixel
                let r = Double(pixels[offset]) / 255.0
                let g = Double(pixels[offset + 1]) / 255.0
                let b = Double(pixels[offset + 2]) / 255.0

                let maxChannel = max(r, max(g, b))
                let minChannel = min(r, min(g, b))
                let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
                saturationSum += saturation

                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                luminanceValues[y * side + x] = luma

                let gx = min(gridCells - 1, x / cellSize)
                let gy = min(gridCells - 1, y / cellSize)
                gridLuma[(gy * gridCells) + gx] += luma

                let rBin = min(2, Int(r * 3.0))
                let gBin = min(2, Int(g * 3.0))
                let bBin = min(2, Int(b * 3.0))
                let histIndex = (rBin * 9) + (gBin * 3) + bBin
                histogram[histIndex] += 1
            }
        }

        let pixelsPerCell = Double(cellSize * cellSize)
        for index in gridLuma.indices {
            gridLuma[index] /= pixelsPerCell
        }

        let pixelCount = Double(side * side)
        for index in histogram.indices {
            histogram[index] /= pixelCount
        }

        let meanLuma = luminanceValues.reduce(0, +) / pixelCount
        let variance = luminanceValues.map { pow($0 - meanLuma, 2) }.reduce(0, +) / pixelCount
        let stdLuma = sqrt(variance)
        let meanSaturation = saturationSum / pixelCount

        var edgeSum = 0.0
        var edgeCount = 0.0
        if side > 1 {
            for y in 0..<(side - 1) {
                for x in 0..<(side - 1) {
                    let current = luminanceValues[y * side + x]
                    let right = luminanceValues[y * side + (x + 1)]
                    let down = luminanceValues[(y + 1) * side + x]
                    edgeSum += abs(current - right) + abs(current - down)
                    edgeCount += 2
                }
            }
        }
        let meanEdge = edgeCount > 0 ? edgeSum / edgeCount : 0

        var features: [Double] = []
        features.append(contentsOf: gridLuma)
        features.append(contentsOf: histogram)
        features.append(contentsOf: [meanLuma, stdLuma, meanSaturation, meanEdge])
        return features
    }

    static func thumbnailData(from image: UIImage, maxSide: CGFloat = 144) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let thumb = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: target)).fill()
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return thumb.jpegData(compressionQuality: 0.72)
    }

    private static func resizedImage(_ image: UIImage, side: Int) -> UIImage? {
        guard side > 0 else { return nil }
        let targetSize = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

enum Chapter3KNNRescueMode {
    case photo
    case drawFallback
}

enum Chapter3KNNCaptureIntent {
    case training(label: String)
    case testing(expectedLabel: String)
}

struct Chapter3KNNRescueTestRound: Identifiable {
    let id = UUID()
    let expectedLabel: String
    let predictedLabel: String
    let confidence: Double
    let isCorrect: Bool
    let thumbnailData: Data?
}

struct Chapter3KNNRescueTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let minigame: Chapter3KNNRescueMiniGame
    let onComplete: (String) -> Void

    @StateObject private var photoKNN = Chapter3PhotoKNNClassifier()
    @StateObject private var drawKNN = KNNClassifier()

    @State private var mode: Chapter3KNNRescueMode = .photo
    @State private var selectedTrainingLabel: String
    @State private var statusMessage = "Capture a few object photos to rebuild the KNN anchors."
    @State private var testPromptLabel: String?
    @State private var testRounds: [Chapter3KNNRescueTestRound] = []
    @State private var correctTestCount = 0
    @State private var didSubmitCompletion = false

    @State private var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var captureIntent: Chapter3KNNCaptureIntent?
    @State private var showImagePicker = false

    // Draw fallback states
    @State private var fallbackStrokes: [[CGPoint]] = []
    @State private var fallbackCurrentStroke: [CGPoint] = []
    @State private var fallbackCanvasSize: CGSize = .zero
    @State private var fallbackPrediction: (label: String, confidence: Double)?
    @State private var fallbackPrompt = "1"
    @State private var fallbackStatus = "If the camera test fails, draw the number shown here."
    @State private var didLoadFallbackTemplates = false
    
    // Chat-style messages
    @State private var chatMessages: [TrainingChatMessage] = []
    @State private var lastErrorCode: String?

    init(minigame: Chapter3KNNRescueMiniGame, onComplete: @escaping (String) -> Void) {
        self.minigame = minigame
        self.onComplete = onComplete
        _selectedTrainingLabel = State(initialValue: minigame.trainingLabels.first ?? "Object")
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var photoLibraryAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }

    private var trainedLabels: [String] {
        photoKNN.trainedLabels
    }

    private var isPhotoTestReady: Bool {
        photoKNN.isTrained && photoKNN.trainingSamples.count >= minigame.minTrainingSamples
    }

    private var photoRescuePassed: Bool {
        correctTestCount >= minigame.requiredCorrectTests
    }

    private var photoRescueFailed: Bool {
        !photoRescuePassed && testRounds.count >= minigame.maxTestRounds
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = AdaptiveLayout(size: geo.size, horizontalSizeClass: horizontalSizeClass)

                ScrollView {
                    VStack(alignment: .leading, spacing: layout.spacing) {
                        rescueOverviewCard(layout: layout)

                        if mode == .photo {
                            photoTrainingSection(layout: layout)
                            photoTestingSection(layout: layout)

                            Button("Can't take a photo? Draw instead") {
                                activateDrawFallback(reason: "Switched manually from photo mode.")
                            }
                            .font(.system(size: layout.fontSize, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                        } else {
                            drawFallbackSection(layout: layout)
                        }
                    }
                    .padding(layout.padding)
                }
                .navigationTitle(minigame.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if mode == .drawFallback {
                            Button("Photo Mode") {
                                mode = .photo
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            captureIntent = nil
        }) {
            StoryDeviceImagePicker(sourceType: pickerSourceType) { image in
                handlePickedImage(image)
                showImagePicker = false
            } onCancel: {
                showImagePicker = false
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if selectedTrainingLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedTrainingLabel = minigame.trainingLabels.first ?? "Object"
            }
        }
    }

    @ViewBuilder
    private func rescueOverviewCard(layout: AdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(minigame.promptLabel)
                .font(.system(size: layout.fontSize, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Label("Train \(minigame.minTrainingSamples)+ photos", systemImage: "photo.stack")
                Label("Pass \(minigame.requiredCorrectTests)/\(minigame.maxTestRounds)", systemImage: "checkmark.seal")
            }
            .font(.system(size: layout.fontSize - 3, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(mode == .photo ? statusMessage : fallbackStatus)
                .font(.system(size: layout.fontSize - 2))
                .foregroundColor(.secondary)

            Text(minigame.summaryNote)
                .font(.system(size: layout.fontSize - 3))
                .foregroundColor(.secondary.opacity(0.9))
        }
        .padding(layout.padding)
        .background(Color(.systemGray6))
        .cornerRadius(layout.cornerRadius)
    }

    @ViewBuilder
    private func photoTrainingSection(layout: AdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            Text("1. Train With Real Photos")
                .font(.system(size: layout.titleSize - 2, weight: .bold))

            Text("Pick a label, then take or upload 3-4 total photos from real life (example: pen, hand, water bottle).")
                .font(.system(size: layout.fontSize - 2))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(minigame.trainingLabels, id: \.self) { label in
                        Button(action: { selectedTrainingLabel = label }) {
                            let count = photoKNN.trainingSamples.filter { $0.label == label }.count
                            HStack(spacing: 6) {
                                Text(label)
                                Text("\(count)")
                                    .font(.system(size: layout.fontSize - 4))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(5)
                            }
                            .font(.system(size: layout.fontSize - 2, weight: .semibold))
                            .foregroundColor(selectedTrainingLabel == label ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTrainingLabel == label ? Color.blue : Color(.systemGray5))
                            .cornerRadius(layout.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: layout.spacing) {
                PrimaryButton(
                    title: "Take Photo (\(selectedTrainingLabel))",
                    action: { presentPicker(source: .camera, intent: .training(label: selectedTrainingLabel)) },
                    layout: layout,
                    disabled: !cameraAvailable
                )
                SecondaryButton(
                    title: "Upload Image",
                    action: { presentPicker(source: .photoLibrary, intent: .training(label: selectedTrainingLabel)) },
                    layout: layout
                )
                .disabled(!photoLibraryAvailable)
            }

            if !cameraAvailable {
                Text("Camera is unavailable on this device. Use Upload Image or switch to drawing mode.")
                    .font(.system(size: layout.fontSize - 3))
                    .foregroundColor(.secondary)
            }

            if photoKNN.trainingSamples.isEmpty {
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color(.systemGray6))
                    .frame(height: 96)
                    .overlay(
                        Text("No training photos yet")
                            .font(.system(size: layout.fontSize - 1, weight: .medium))
                            .foregroundColor(.secondary)
                    )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(photoKNN.trainingSamples) { sample in
                        VStack(spacing: 6) {
                            if let data = sample.thumbnailData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 74)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 74)
                            }

                            Text(sample.label)
                                .font(.system(size: layout.fontSize - 4, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(layout.padding)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .cornerRadius(layout.cornerRadius)
    }

    @ViewBuilder
    private func photoTestingSection(layout: AdaptiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            Text("2. Test The KNN Rescue")
                .font(.system(size: layout.titleSize - 2, weight: .bold))

            HStack(spacing: 8) {
                Label("Correct: \(correctTestCount)/\(minigame.requiredCorrectTests)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(correctTestCount > 0 ? .green : .secondary)
                Label("Rounds: \(testRounds.count)/\(minigame.maxTestRounds)", systemImage: "timer")
                    .foregroundColor(.secondary)
            }
            .font(.system(size: layout.fontSize - 3, weight: .medium))

            if !isPhotoTestReady {
                Text("Need at least \(minigame.minTrainingSamples) training photos and 2 different labels before testing.")
                    .font(.system(size: layout.fontSize - 2))
                    .foregroundColor(.secondary)
            } else if photoRescuePassed {
                Text("Photo rescue passed. You can close this mini-game and continue the story.")
                    .font(.system(size: layout.fontSize - 2, weight: .semibold))
                    .foregroundColor(.green)
            } else {
                let currentPrompt = testPromptLabel ?? nextTestPromptSuggestion()
                Text("Show the camera or upload a photo of: \(currentPrompt)")
                    .font(.system(size: layout.fontSize, weight: .semibold))

                HStack(spacing: layout.spacing) {
                    PrimaryButton(
                        title: "Take Test Photo",
                        action: { presentPicker(source: .camera, intent: .testing(expectedLabel: currentPrompt)) },
                        layout: layout,
                        disabled: !cameraAvailable || photoRescueFailed
                    )
                    SecondaryButton(
                        title: "Upload Test Image",
                        action: { presentPicker(source: .photoLibrary, intent: .testing(expectedLabel: currentPrompt)) },
                        layout: layout
                    )
                    .disabled(!photoLibraryAvailable || photoRescueFailed)
                }

                if photoRescueFailed {
                    Text("Photo test failed. Switching to drawing fallback.")
                        .font(.system(size: layout.fontSize - 2, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }

            if !testRounds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(testRounds) { round in
                        HStack(spacing: 10) {
                            if let data = round.thumbnailData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Expected: \(round.expectedLabel)")
                                    .font(.system(size: layout.fontSize - 3, weight: .semibold))
                                Text("Predicted: \(round.predictedLabel) • \(Int((round.confidence * 100).rounded()))%")
                                    .font(.system(size: layout.fontSize - 4))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: round.isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundColor(round.isCorrect ? .green : .red)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(layout.padding)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .cornerRadius(layout.cornerRadius)
    }

    @ViewBuilder
    private func drawFallbackSection(layout: AdaptiveLayout) -> some View {
        VStack(spacing: 0) {
            // Chat-style messages area
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 12) {
                        // Initial AI message
                        if chatMessages.isEmpty {
                            aiMessageBubble(
                                text: "Hi! I'm your Training assistant. Please draw the number \(fallbackPrompt) in the canvas below.",
                                errorCode: nil,
                                layout: layout
                            )
                        }
                        
                        // Chat history
                        ForEach(chatMessages) { message in
                            if message.isUser {
                                userMessageBubble(text: message.text, layout: layout)
                            } else {
                                aiMessageBubble(
                                    text: message.text,
                                    errorCode: message.errorCode,
                                    layout: layout
                                )
                            }
                        }
                        
                        // Current status as AI message if not in chat history
                        if !chatMessages.isEmpty {
                            aiMessageBubble(
                                text: fallbackStatus,
                                errorCode: lastErrorCode,
                                layout: layout
                            )
                        }
                    }
                    .padding(.horizontal, layout.padding)
                    .padding(.vertical, 8)
                    .onChange(of: chatMessages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(chatMessages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Divider between chat and input
            Divider()
            
            // Input area with canvas
            VStack(spacing: layout.spacing) {
                // Current number to draw indicator
                HStack {
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: layout.fontSize))
                    Text("Draw: \(fallbackPrompt)")
                        .font(.system(size: layout.fontSize, weight: .semibold))
                    Spacer()
                    if let result = fallbackPrediction {
                        HStack(spacing: 4) {
                            Image(systemName: result.label == fallbackPrompt ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.label == fallbackPrompt ? .green : .red)
                            Text("\(Int((result.confidence * 100).rounded()))%")
                                .font(.system(size: layout.fontSize - 2, weight: .medium))
                        }
                    }
                }
                .foregroundColor(.primary)
                
                // Drawing canvas
                DrawingCanvas(
                    strokes: $fallbackStrokes,
                    currentStroke: $fallbackCurrentStroke,
                    canvasSize: $fallbackCanvasSize,
                    layout: layout,
                    accent: .orange
                )
                .frame(height: min(layout.canvasHeight, 200))
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Action buttons
                HStack(spacing: layout.spacing) {
                    Button(action: {
                        fallbackStrokes.removeAll()
                        fallbackPrediction = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Clear")
                        }
                        .font(.system(size: layout.fontSize, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(20)
                    }
                    
                    Button(action: runChatPrediction) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                            Text("Send")
                        }
                        .font(.system(size: layout.fontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(fallbackStrokes.isEmpty ? Color.orange.opacity(0.5) : Color.orange)
                        .cornerRadius(20)
                    }
                    .disabled(fallbackStrokes.isEmpty)
                }
            }
            .padding(layout.padding)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .background(Color(.systemBackground))
        .cornerRadius(layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            loadFallbackDigitTemplatesIfNeeded()
            if fallbackPrompt.isEmpty {
                fallbackPrompt = randomFallbackDigit()
            }
        }
    }
    
    // MARK: - Chat UI Components
    
    private func userMessageBubble(text: String, layout: AdaptiveLayout) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Training")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                
                Text(text)
                    .font(.system(size: layout.fontSize))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
            }
        }
    }
    
    private func aiMessageBubble(text: String, errorCode: String?, layout: AdaptiveLayout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text("AI Assistant")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.leading, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: layout.fontSize))
                        .foregroundColor(.primary)
                    
                    if let code = errorCode {
                        Text("[Error Code: \(code)]")
                            .font(.system(size: layout.fontSize - 3, design: .monospaced))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
            }
            Spacer()
        }
    }
    
    private func runChatPrediction() {
        guard !fallbackStrokes.isEmpty, fallbackCanvasSize != .zero else {
            fallbackStatus = "Draw a number first."
            return
        }
        
        // Add user message
        let userMessage = "I drew a number \(fallbackPrompt)"
        chatMessages.append(TrainingChatMessage(text: userMessage, isUser: true))
        
        // Run prediction
        let sample = DrawingSample.fromStrokes(fallbackStrokes, label: "test", canvasSize: fallbackCanvasSize)
        let result = drawKNN.classify(sample)
        fallbackPrediction = result
        
        // Generate error code if wrong
        var errorCode: String? = nil
        if result.label != fallbackPrompt {
            errorCode = "ERR_\(result.label)_EXP_\(fallbackPrompt)_\(Int(result.confidence * 100))"
            lastErrorCode = errorCode
        } else {
            lastErrorCode = nil
        }
        
        // Add AI response
        var aiResponse = ""
        if result.label == fallbackPrompt {
            aiResponse = "✓ Correct! I recognized that as \(result.label) with \(Int((result.confidence * 100).rounded()))% confidence."
        } else {
            aiResponse = "That looked like \(result.label) (\(Int((result.confidence * 100).rounded()))% confidence). Try drawing \(fallbackPrompt) again with clearer strokes."
        }
        
        chatMessages.append(TrainingChatMessage(text: aiResponse, isUser: false, errorCode: errorCode))
        
        // Check for completion
        if result.label == fallbackPrompt {
            let summary = "Photo rescue failed at \(correctTestCount)/\(max(testRounds.count, 1)), but drawing fallback succeeded by correctly drawing number \(fallbackPrompt)."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completeRescue(summary)
            }
        } else {
            fallbackStrokes.removeAll()
        }
    }

    private func presentPicker(source: UIImagePickerController.SourceType, intent: Chapter3KNNCaptureIntent) {
        switch source {
        case .camera:
            guard cameraAvailable else {
                statusMessage = "Camera not available on this device."
                return
            }
        case .photoLibrary:
            guard photoLibraryAvailable else {
                statusMessage = "Photo library is unavailable."
                return
            }
        default:
            break
        }

        captureIntent = intent
        pickerSourceType = source
        showImagePicker = true
    }

    private func handlePickedImage(_ image: UIImage) {
        guard let intent = captureIntent else { return }

        switch intent {
        case .training(let label):
            if photoKNN.addSample(image: image, label: label) {
                let count = photoKNN.trainingSamples.filter { $0.label == label }.count
                statusMessage = "Added \(label) sample (\(count) for \(label), \(photoKNN.trainingSamples.count) total)."
                if testPromptLabel == nil, isPhotoTestReady {
                    testPromptLabel = nextTestPromptSuggestion()
                }
            } else {
                statusMessage = "Could not read that image. Try another photo."
            }

        case .testing(let expectedLabel):
            guard let result = photoKNN.classify(image: image) else {
                statusMessage = "Need more training photos before testing."
                return
            }

            let isCorrect = result.label.caseInsensitiveCompare(expectedLabel) == .orderedSame
            if isCorrect {
                correctTestCount += 1
            }

            testRounds.append(
                Chapter3KNNRescueTestRound(
                    expectedLabel: expectedLabel,
                    predictedLabel: result.label,
                    confidence: result.confidence,
                    isCorrect: isCorrect,
                    thumbnailData: Chapter3PhotoFeatureExtractor.thumbnailData(from: image)
                )
            )

            if correctTestCount >= minigame.requiredCorrectTests {
                let summary = "KNN rescue complete: \(correctTestCount)/\(testRounds.count) test photos correct after training with \(photoKNN.trainingSamples.count) anchor photos."
                completeRescue(summary)
                return
            }

            if testRounds.count >= minigame.maxTestRounds {
                activateDrawFallback(reason: "Photo rescue scored \(correctTestCount)/\(testRounds.count). Use drawing fallback to stabilize the transfer.")
                return
            }

            testPromptLabel = nextTestPromptSuggestion()
            statusMessage = isCorrect
                ? "Correct! Keep going. \(correctTestCount)/\(minigame.requiredCorrectTests) needed."
                : "Mismatch. Try another test photo. \(correctTestCount)/\(minigame.requiredCorrectTests) correct so far."
        }
    }

    private func nextTestPromptSuggestion() -> String {
        let pool = trainedLabels.isEmpty ? minigame.trainingLabels : trainedLabels
        if let selected = pool.randomElement() {
            return selected
        }
        return minigame.trainingLabels.first ?? "Object"
    }

    private func activateDrawFallback(reason: String) {
        mode = .drawFallback
        fallbackStatus = reason
        if fallbackPrompt.isEmpty {
            fallbackPrompt = randomFallbackDigit()
        }
        loadFallbackDigitTemplatesIfNeeded()
    }

    private func loadFallbackDigitTemplatesIfNeeded() {
        guard !didLoadFallbackTemplates else { return }
        didLoadFallbackTemplates = true

        let canvas = CGSize(width: 100, height: 100)
        let templates: [(String, [[CGPoint]])] = [
            ("1", [[CGPoint(x: 47, y: 18), CGPoint(x: 53, y: 18), CGPoint(x: 53, y: 82)]]),
            ("1", [[CGPoint(x: 42, y: 28), CGPoint(x: 50, y: 18), CGPoint(x: 50, y: 84)]]),
            ("1", [[CGPoint(x: 38, y: 80), CGPoint(x: 62, y: 80)]]),

            ("2", [[CGPoint(x: 26, y: 28), CGPoint(x: 42, y: 18), CGPoint(x: 62, y: 20), CGPoint(x: 70, y: 34), CGPoint(x: 30, y: 74), CGPoint(x: 70, y: 74)]]),
            ("2", [[CGPoint(x: 28, y: 24), CGPoint(x: 48, y: 16), CGPoint(x: 66, y: 26), CGPoint(x: 62, y: 40), CGPoint(x: 32, y: 62), CGPoint(x: 28, y: 80), CGPoint(x: 72, y: 80)]]),

            ("3", [[CGPoint(x: 28, y: 24), CGPoint(x: 54, y: 18), CGPoint(x: 70, y: 30), CGPoint(x: 52, y: 48), CGPoint(x: 72, y: 66), CGPoint(x: 54, y: 82), CGPoint(x: 28, y: 76)]]),
            ("3", [[CGPoint(x: 26, y: 20), CGPoint(x: 58, y: 20), CGPoint(x: 70, y: 34), CGPoint(x: 48, y: 50), CGPoint(x: 70, y: 66), CGPoint(x: 58, y: 82), CGPoint(x: 26, y: 82)]])
        ]

        // Build samples from stroke templates
        for (label, stroke) in templates {
            let sample = DrawingSample.fromStrokes(stroke, label: label, canvasSize: canvas)
            drawKNN.addSample(sample)
        }
        drawKNN.k = 3
        drawKNN.train()
        fallbackPrompt = randomFallbackDigit()
        fallbackStatus = "Draw the number \(fallbackPrompt). The fallback KNN is preloaded with number examples."
    }

    private func randomFallbackDigit() -> String {
        ["1", "2", "3"].randomElement() ?? "1"
    }

    private func completeRescue(_ summary: String) {
        guard !didSubmitCompletion else { return }
        didSubmitCompletion = true
        onComplete(summary)
        dismiss()
    }
}

struct StoryDeviceImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        #if targetEnvironment(macCatalyst)
        // On macOS, use document picker for file system access instead of Photos library
        if sourceType == .photoLibrary {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
            documentPicker.delegate = context.coordinator
            documentPicker.allowsMultipleSelection = false
            return documentPicker
        }
        #endif
        
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIDocumentPickerDelegate {
        private let parent: StoryDeviceImagePicker

        init(_ parent: StoryDeviceImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            } else {
                parent.onCancel()
            }
        }
        
        // MARK: - UIDocumentPickerDelegate for macOS file access
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onCancel()
                return
            }
            
            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                parent.onCancel()
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                parent.onImagePicked(image)
            } else {
                parent.onCancel()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}

// MARK: - Rounded Corner Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    ImageTrainingView()
}
