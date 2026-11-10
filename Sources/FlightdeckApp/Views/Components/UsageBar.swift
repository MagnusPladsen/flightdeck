import MonitorCore
import SwiftUI

struct UsageBar: View {
    @Environment(\.theme) private var theme
    var window: UsageWindow
    var forecast: LimitForecast?
    var agentName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label)
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(UsageLevel.color(forPercent: window.usedPercent, in: theme))
            }
            .font(.caption)
            ProgressBar(fraction: window.usedPercent / 100, color: UsageLevel.color(forPercent: window.usedPercent, in: theme))
            let reset = Formatters.resetCountdown(window.resetsAt)
            if reset != nil || forecast != nil {
                HStack {
                    if let reset { Text(reset).foregroundStyle(.secondary) }
                    Spacer(minLength: 8)
                    if let forecast { ForecastText(forecast: forecast) }
                }
                .font(.caption2)
            }
        }
        .contentShape(Rectangle())
        .help(ResourceTooltips.limit(agentName: agentName, title: "\(window.label) limit", window: window, forecast: forecast))
    }
}

struct ProgressBar: View {
    @Environment(\.theme) private var theme
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.overlay)
                Capsule()
                    .fill(color.gradient)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
        .animation(.smooth, value: fraction)
    }
}

/// Usage windows and token counts for one provider.
struct ProviderUsageView: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var usage: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: usage.tool.symbolName)
                Text(usage.tool.displayName).fontWeight(.medium)
                if let plan = usage.plan {
                    Text(plan)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(theme.overlay, in: Capsule())
                }
                Spacer()
                if let tokens = usage.tokensToday {
                    Text("\(Formatters.tokens(tokens.total)) tokens today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            ForEach(usage.windows) { UsageBar(window: $0, forecast: store.limitForecast(for: usage.tool, window: $0), agentName: usage.tool.displayName) }
        }
    }
}
