import SwiftUI

struct RingGauge<Center: View>: View {
    @Environment(\.theme) private var theme
    var fraction: Double
    var color: Color
    var lineWidth: CGFloat = 9
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle().stroke(theme.overlay, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0.001), 1))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.55), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(fraction, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.45), radius: 6)
            center
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.6), value: fraction)
    }
}
