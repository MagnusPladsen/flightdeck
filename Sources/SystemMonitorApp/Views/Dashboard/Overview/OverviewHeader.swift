import MonitorCore
import SwiftUI

struct OverviewHeader: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    StatusDot(color: theme.success, isPulsing: true, size: 7)
                    Text("LIVE").font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(theme.success)
                }
                Text(store.snapshot?.hostName ?? "System Monitor")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(summary).font(.system(size: 13)).opacity(0.6)
            }
            Spacer()
            if let snapshot = store.snapshot {
                HStack(spacing: 8) {
                    InfoPill(systemImage: "clock", text: "Up \(Formatters.duration(snapshot.uptime))")
                    InfoPill(systemImage: "speedometer", text: snapshot.loadAverage.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: "  "))
                    if let battery = snapshot.battery {
                        InfoPill(systemImage: battery.isCharging ? "battery.100.bolt" : "battery.75", text: Formatters.percent(battery.percent))
                    }
                }
            }
        }
        .padding(22)
        .background(
            LinearGradient(colors: [theme.primary.opacity(0.22), theme.secondary.opacity(0.12), theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.border.opacity(0.7)))
    }

    private var summary: String {
        let servers = store.devServers.count
        let agents = store.activeAgents.count
        return "\(servers) dev server\(servers == 1 ? "" : "s") running · \(agents) active agent\(agents == 1 ? "" : "s")"
    }
}

private struct InfoPill: View {
    @Environment(\.theme) private var theme
    var systemImage: String
    var text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.background.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(theme.border.opacity(0.7)))
    }
}
