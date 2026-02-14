import SwiftUI
import Combine

@MainActor
class MainMenuViewModel: ObservableObject {
    @Published var offsetX: CGFloat = 0
    @Published var offsetY: CGFloat = 0
    
    private var lastTouchTime = Date()
    private var timer: Timer?
    private var idleTime: Double = 0
    private var isUserInteracting = false
    
    // Smaller max offset to prevent showing image edge
    private let maxOffset: CGFloat = 25
    private let idleDelay: TimeInterval = 2.0
    
    func start() {
        stop()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func handleTouch(translation: CGSize) {
        isUserInteracting = true
        lastTouchTime = Date()
        idleTime = 0
        
        // Damping for smooth feel
        let damping: CGFloat = 0.25
        var newX = translation.width * damping
        var newY = translation.height * damping
        
        // Clamp to prevent showing edges
        newX = max(-maxOffset, min(maxOffset, newX))
        newY = max(-maxOffset, min(maxOffset, newY))
        
        offsetX = newX
        offsetY = newY
    }
    
    func touchEnded() {
        lastTouchTime = Date()
        isUserInteracting = false
    }
    
    private func update() {
        let timeSinceTouch = Date().timeIntervalSince(lastTouchTime)
        
        if timeSinceTouch >= idleDelay {
            // Smooth continuous floating movement
            idleTime += 0.016
            
            // Multiple sine waves for organic movement
            let wave1X = sin(idleTime * 0.8) * 15
            let wave2X = sin(idleTime * 0.3) * 8
            let wave1Y = cos(idleTime * 0.6) * 12
            let wave2Y = sin(idleTime * 0.4) * 6
            
            // Smooth transition to idle position
            let targetX = wave1X + wave2X
            let targetY = wave1Y + wave2Y
            
            // Gentle interpolation
            offsetX += (targetX - offsetX) * 0.05
            offsetY += (targetY - offsetY) * 0.05
        } else {
            // Return to center when user stops touching
            offsetX *= 0.98
            offsetY *= 0.98
        }
    }
}

struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()
    
    var body: some View {
        ZStack {
            // Background Image with larger scale to prevent edge visibility
            Image("cnxaqu")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.4) // Larger scale to hide edges
                .offset(x: viewModel.offsetX, y: viewModel.offsetY)
                .ignoresSafeArea()
            
            // Dark overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Menu Panel
            HStack {
                VStack(alignment: .leading, spacing: 20) {
                    // App Icon - bigger and more prominent
                    HStack {
                        Spacer()
                        Image("icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .shadow(color: .black.opacity(0.5), radius: 10)
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    // Menu Buttons
                    VStack(spacing: 12) {
                        MenuButton(title: "Play", icon: "play.fill")
                        MenuButton(title: "Load Game", icon: "square.and.arrow.down.fill")
                        MenuButton(title: "Gallery", icon: "photo.on.rectangle.angled")
                        MenuButton(title: "Settings", icon: "gearshape.fill")
                    }
                    
                    Spacer()
                    
                    // Status
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Ready to Play")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                }
                .padding(20)
                .frame(width: 280)
                .background(Color.black.opacity(0.4))
                .cornerRadius(20)
                .padding(20)
                
                Spacer()
            }
            
            // Version
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Ver 1.0")
                        .foregroundColor(.white.opacity(0.5))
                        .padding()
                }
            }
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    viewModel.handleTouch(translation: value.translation)
                }
                .onEnded { _ in
                    viewModel.touchEnded()
                }
        )
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 30)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

#Preview {
    MainMenuView()
        .preferredColorScheme(.dark)
}
