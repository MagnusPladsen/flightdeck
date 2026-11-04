import SwiftUI

struct StatusDot: View {
    var color: Color
    var isPulsing = false
    var size: CGFloat = 8

    @State private var isGlowing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background {
                if isPulsing {
                    Circle()
                        .fill(color.opacity(0.35))
                        .scaleEffect(isGlowing ? 2.2 : 1)
                        .opacity(isGlowing ? 0 : 1)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: isGlowing)
                        .onAppear { isGlowing = true }
                }
            }
    }
}
