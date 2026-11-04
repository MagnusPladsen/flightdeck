import SwiftUI

struct MetricTile: View {
    @Environment(\.theme) private var theme
    var title: String
    var value: String
    var detail: String?
    var history: [Double]
    var color: Color
    var maximum: Double?
    /// Shown as a bar instead of a sparkline when there is no history, e.g. disk usage.
    var gaugeFraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .light).monospacedDigit())
                .tracking(-0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            (Text(title) + Text(detail.map { " · " + $0 } ?? "").foregroundStyle(theme.foreground.opacity(0.35)))
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
            if let gaugeFraction, history.isEmpty {
                ProgressBar(fraction: gaugeFraction, color: color)
                    .frame(height: 26, alignment: .bottom)
            } else {
                Sparkline(values: history, color: color, maximum: maximum)
                    .frame(height: 26)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
