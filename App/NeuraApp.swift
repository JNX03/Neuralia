import SwiftUI

@main
struct NeuraApp: App {
    @StateObject private var globalSettings = GlobalSettingsStore()
    
    var body: some Scene {
        WindowGroup {
            ForcedLandscape16x9Container {
                ContentView()
            }
            .environmentObject(globalSettings)
        }
    }
}

private struct ForcedLandscape16x9Container<Content: View>: View {
    private let content: Content
    private let aspectRatio: CGFloat = 16.0 / 9.0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let hostSize = geometry.size
            let hostIsLandscape = hostSize.width >= hostSize.height
            let canvasSize = fittedLandscapeCanvas(in: hostSize, hostIsLandscape: hostIsLandscape)
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                content
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .clipped()
                    .rotationEffect(hostIsLandscape ? .degrees(0) : .degrees(90))
                    .frame(width: hostSize.width, height: hostSize.height)
            }
        }
        .ignoresSafeArea()
    }
    
    private func fittedLandscapeCanvas(in hostSize: CGSize, hostIsLandscape: Bool) -> CGSize {
        if hostIsLandscape {
            let width = min(hostSize.width, hostSize.height * aspectRatio)
            return CGSize(width: width, height: width / aspectRatio)
        } else {
            // In portrait hosts, the rotated content's height becomes the host-visible width.
            let width = min(hostSize.height, hostSize.width * aspectRatio)
            return CGSize(width: width, height: width / aspectRatio)
        }
    }
}
