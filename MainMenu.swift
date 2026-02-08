import SwiftUI

struct MainMenuView: View {
    var body: some View {
        Stage16x9 { stage in
            ZStack {
                Color.black
                
                // background (optional)
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.blue.opacity(0.25),
                        Color.cyan.opacity(0.15),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.9)
                
                VStack(spacing: 18) {
                    Spacer()
                    
                    Text("MAIN MENU")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 12)
                    
                    VStack(spacing: 12) {
                        MenuButton(title: "Play") { }
                        MenuButton(title: "Load") { }
                        MenuButton(title: "Settings") { }
                    }
                    .padding(.horizontal, 26)
                    
                    Spacer()
                    
                    Text("Neuralia")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 16)
                }
            }
        }
    }
}

private struct MenuButton: View {
    let title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cyan.opacity(0.45), lineWidth: 1)
                        )
                )
                .shadow(radius: 10)
        }
        .buttonStyle(.plain)
    }
}
