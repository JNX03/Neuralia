import SwiftUI

// MARK: - Credits View
struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Available images for the memory frame (excluding char and icon)
    private let memoryImages = ["507room", "cnxaqu", "cnxgate", "lantassc", "redbus"]
    @State private var currentImageIndex = 0
    @State private var imageOpacity: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                // Background with blur
                backgroundLayer()
                
                // Main content
                contentLayer(layout: layout)
                
                // Back button
                backButton(layout: layout)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Start image cycling timer
            startImageCycle()
        }
        .onDisappear {
            // Stop timer when view disappears
            stopImageCycle()
        }
    }
    
    // MARK: - Timer Management
    @State private var timer: Timer? = nil
    
    private func startImageCycle() {
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            Task { @MainActor in
                cycleImage()
            }
        }
    }
    
    private func stopImageCycle() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Background Layer
    private func backgroundLayer() -> some View {
        ZStack {
            Image("schooltopview")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Blur and dark overlay using pure SwiftUI
            Color.black.opacity(0.4)
                .ignoresSafeArea()
        }
        .background(
            // Apply blur effect
            Image("schooltopview")
                .resizable()
                .scaledToFill()
                .blur(radius: 20)
                .ignoresSafeArea()
                .opacity(0.8)
        )
    }
    
    // MARK: - Content Layer
    private func contentLayer(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.sectionSpacing * 2) {
            // Left side - Logo and Credits
            leftPanel(layout: layout)
            
            // Right side - Memory Frame
            rightPanel(layout: layout)
        }
        .padding(layout.padding * 2)
    }
    
    // MARK: - Left Panel (Logo + Credits)
    private func leftPanel(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.sectionSpacing * 1.5) {
            // Game Logo
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(width: layout.menuIconSize * 0.8, height: layout.menuIconSize * 0.8)
                .shadow(color: .black.opacity(0.5), radius: layout.scaled(15))
            
            // Credits Content
            VStack(spacing: layout.elementSpacing * 2) {
                // Main credit
                Text("Made with ❤️ by Jnx03")
                    .font(.system(size: layout.headlineFontSize, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("(Chawabhon Netisingha)")
                    .font(.system(size: layout.bodyFontSize, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("In WWDC SSC 2026")
                    .font(.system(size: layout.bodyFontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                
                // Separator
                Text("──────────────")
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, layout.elementSpacing)
                
                // Credits list
                VStack(alignment: .center, spacing: layout.elementSpacing) {
                    Text("Art : Chawabhon Netisingha")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Music : Chawabhon Netisingha")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Story : Chawabhon Netisingha")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Programming : Chawabhon Netisingha")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Separator
                Text("──────────────")
                    .font(.system(size: layout.bodyFontSize))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, layout.elementSpacing)
                
                // Tools credit
                Text("Made with MacBook and iPad")
                    .font(.system(size: layout.bodyFontSize, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.top, layout.sectionSpacing)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Right Panel (Memory Frame)
    private func rightPanel(layout: ResponsiveLayout) -> some View {
        VStack {
            Spacer()
            
            // Memory Frame
            ZStack {
                // Frame background
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: layout.scaled(300), height: layout.scaled(380))
                    .shadow(color: .black.opacity(0.4), radius: layout.scaled(20), x: 0, y: layout.scaled(10))
                
                // Inner frame (white border like a photo frame)
                RoundedRectangle(cornerRadius: layout.cornerRadius * 0.7)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: layout.scaled(280), height: layout.scaled(360))
                
                // Image container
                RoundedRectangle(cornerRadius: layout.cornerRadius * 0.5)
                    .fill(Color.black.opacity(0.1))
                    .frame(width: layout.scaled(260), height: layout.scaled(340))
                    .overlay(
                        Group {
                            if currentImageIndex < memoryImages.count {
                                Image(memoryImages[currentImageIndex])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: layout.scaled(260), height: layout.scaled(340))
                                    .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius * 0.5))
                                    .opacity(imageOpacity)
                            }
                        }
                    )
                
                // Photo corner decorations (like a polaroid/memory effect)
                VStack {
                    HStack {
                        Image(systemName: "pin.fill")
                            .font(.system(size: layout.scaled(24)))
                            .foregroundColor(.red.opacity(0.8))
                            .rotationEffect(.degrees(-45))
                            .offset(x: -layout.scaled(10), y: -layout.scaled(130))
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: layout.scaled(280), height: layout.scaled(360))
            }
            
            // Image indicator dots
            HStack(spacing: layout.elementSpacing) {
                ForEach(0..<memoryImages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.4))
                        .frame(width: layout.scaled(8), height: layout.scaled(8))
                        .scaleEffect(index == currentImageIndex ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentImageIndex)
                }
            }
            .padding(.top, layout.elementSpacing * 2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Back Button
    private func backButton(layout: ResponsiveLayout) -> some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: layout.elementSpacing) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: layout.bodyFontSize, weight: .semibold))
                        Text("Back")
                            .font(.system(size: layout.bodyFontSize, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, layout.padding)
                    .padding(.vertical, layout.scaled(10))
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(layout.padding)
            
            Spacer()
        }
    }
    
    // MARK: - Cycle Image
    private func cycleImage() {
        withAnimation(.easeInOut(duration: 0.5)) {
            imageOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentImageIndex = (currentImageIndex + 1) % memoryImages.count
            withAnimation(.easeInOut(duration: 0.5)) {
                imageOpacity = 1
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CreditsView()
        .preferredColorScheme(.dark)
}
