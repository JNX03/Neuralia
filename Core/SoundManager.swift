import SwiftUI
import AVFoundation

@MainActor
final class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    private var bgmPlayer: AVAudioPlayer?
    @Published var isMusicEnabled: Bool = true {
        didSet {
            if isMusicEnabled {
                playBGM()
            } else {
                stopBGM()
            }
        }
    }
    
    private init() {}
    
    func playBGM() {
        guard isMusicEnabled else { return }
        
        // Return if it's already playing
        if let player = bgmPlayer, player.isPlaying {
            return
        }
        
        let audioName = "chapter1" // Always use chapter1 lofi music
        
        guard let dataAsset = NSDataAsset(name: audioName) else {
            print("Failed to find audio asset: \(audioName)")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            bgmPlayer = try AVAudioPlayer(data: dataAsset.data)
            bgmPlayer?.numberOfLoops = -1 // Loop indefinitely
            bgmPlayer?.volume = 0.5
            bgmPlayer?.play()
        } catch {
            print("Failed to play bgm: \(error.localizedDescription)")
        }
    }
    
    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }
}
