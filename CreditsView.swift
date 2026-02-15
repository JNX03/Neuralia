import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let memoryImages = ["507room", "cnxaqu", "cnxgate", "lantassc", "redbus"]
    @State private var currentImageIndex = 0
    @State private var imageOpacity: Double = 1.0
    @State private var timer: Timer? = nil
    
    // Simple animation states
    @State private var showContent = false
    @State private var photoFrameOffset: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            let layout = ResponsiveLayout(
                width: geometry.size.width,
                height: geometry.size.height,
                safeAreaInsets: geometry.safeAreaInsets
            )
            
            ZStack {
                // Clean background
                backgroundLayer()
                
                // Main content
                contentLayer(layout: layout)
                
                // Back button
                backButton(layout: layout)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
                photoFrameOffset = 0
            }
            startImageCycle()
        }
        .onDisappear {
            stopImageCycle()
        }
    }
    
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
    
    private func backgroundLayer() -> some View {
        ZStack {
            Image("schooltopview")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Subtle dark overlay
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            // Soft blur overlay
            Image("schooltopview")
                .resizable()
                .scaledToFill()
                .blur(radius: 40)
                .opacity(0.15)
                .ignoresSafeArea()
        }
    }
    
    private func contentLayer(layout: ResponsiveLayout) -> some View {
        HStack(spacing: layout.sectionSpacing * 4) {
            leftPanel(layout: layout)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            
            rightPanel(layout: layout)
                .offset(x: photoFrameOffset)
                .opacity(showContent ? 1 : 0)
        }
        .padding(.horizontal, layout.padding * 3)
    }
    
    private func leftPanel(layout: ResponsiveLayout) -> some View {
        VStack(spacing: layout.sectionSpacing * 2) {
            // Clean Logo
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(width: layout.menuIconSize, height: layout.menuIconSize)
                .shadow(color: .black.opacity(0.3), radius: 20)
            
            // Credits Card - Clean Glass Style
            VStack(spacing: layout.elementSpacing * 2) {
                // Title section
                VStack(spacing: 6) {
                    Text("Made with ❤️ by Jnx03")
                        .font(.system(size: layout.headlineFontSize, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Chawabhon Netisingha")
                        .font(.system(size: layout.bodyFontSize))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Badge
                    Text("WWDC SSC 2026")
                        .font(.system(size: layout.captionFontSize, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.15))
                        )
                        .padding(.top, 4)
                }
                
                // Simple line separator
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, layout.elementSpacing)
                
                // Credits list - clean and simple
                VStack(alignment: .leading, spacing: layout.elementSpacing * 1.5) {
                    CreditItem(icon: "paintbrush", text: "Art")
                    CreditItem(icon: "music.note", text: "Music")
                    CreditItem(icon: "book.closed", text: "Story")
                    CreditItem(icon: "chevron.left.forwardslash.chevron.right", text: "Code")
                }
                
                // Simple line separator
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, layout.elementSpacing)
                
                // Footer
                HStack(spacing: 8) {
                    Image(systemName: "macbook")
                    Text("Made with")
                        .font(.system(size: layout.captionFontSize))
                    Image(systemName: "ipad")
                }
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: layout.captionFontSize))
            }
            .padding(layout.padding * 2)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func rightPanel(layout: ResponsiveLayout) -> some View {
        VStack {
            Spacer()
            
            // Clean Photo Frame
            ZStack {
                // Shadow
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.2))
                    .frame(width: layout.scaled(280), height: layout.scaled(360))
                    .offset(x: 8, y: 8)
                    .blur(radius: 20)
                
                // Frame
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: layout.scaled(280), height: layout.scaled(360))
                
                // Photo
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: layout.scaled(250), height: layout.scaled(330))
                    .overlay(
                        Image(memoryImages[currentImageIndex])
                            .resizable()
                            .scaledToFill()
                            .opacity(imageOpacity)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Pin
                Image(systemName: "pin.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red.opacity(0.9))
                    .rotationEffect(.degrees(-35))
                    .offset(y: -layout.scaled(155))
                    .shadow(color: .black.opacity(0.2), radius: 2)
            }
            
            // Clean dots indicator
            HStack(spacing: 8) {
                ForEach(0..<memoryImages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentImageIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: index == currentImageIndex ? 20 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentImageIndex)
                }
            }
            .padding(.top, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func backButton(layout: ResponsiveLayout) -> some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(layout.padding)
            
            Spacer()
        }
    }
    
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

// Simple credit row
struct CreditItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
            
            Text(":")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
            
            Text("Chawabhon Netisingha")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    CreditsView()
        .preferredColorScheme(.dark)
}
