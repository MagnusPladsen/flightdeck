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
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let gaugeFraction, history.isEmpty {
                ProgressBar(fraction: gaugeFraction, color: color)
                    .frame(height: 26, alignment: .bottom)
            } else {
                Sparkline(values: history, color: color, maximum: maximum)
                    .frame(height: 26)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.border.opacity(0.6)))
    }
}
