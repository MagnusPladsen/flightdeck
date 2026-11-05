import MonitorCore
import SwiftUI

struct MenuBarPanel: View {
    private static let listsMaxHeight: CGFloat = 480

    @Environment(MonitorStore.self) private var store
    @Environment(AppUpdater.self) private var updater
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var listsHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            SystemTilesGrid(showsNetworkAndDisk: store.settings.panelShowsNetworkAndDisk)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeading(title: "Needs you", count: agentsNeedingYou.count)
                        HairlineRows(items: Array(agentsNeedingYou.prefix(6)), emptyText: "Nobody is waiting on you") { AgentRow(agent: $0, isCompact: true) }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeading(title: "Dev servers", count: store.devServers.count)
                        HairlineRows(items: Array(store.devServers.prefix(6)), emptyText: "No dev servers running") { PortRow(port: $0, isCompact: true) }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeading(title: "AI agents", count: otherActiveAgents.count)
                        HairlineRows(items: Array(otherActiveAgents.prefix(6)), emptyText: "No other active agents") { AgentRow(agent: $0, isCompact: true) }
                    }
                    if !store.usage.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeading(title: "Usage")
                            HairlineRows(items: store.usage, emptyText: "") { ProviderUsageView(usage: $0) }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { listsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(listsHeight, Self.listsMaxHeight))
            Hairline()
            footer
        }
        .padding(18)
        .frame(width: 380)
        .background(theme.background)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(headline).font(.system(size: 22, weight: .heavy)).tracking(-0.4)
                    .foregroundStyle(needsYouCount > 0 ? theme.attention : theme.foreground)
                if let snapshot = store.snapshot {
                    Text("\(snapshot.hostName) · up \(Formatters.duration(snapshot.uptime)) · load \(String(format: "%.2f", snapshot.loadAverage.first ?? 0))").lineLimit(1)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.muted)
                }
            }
            Spacer()
            IconButton(systemImage: store.settings.alertsEnabled ? "bell.fill" : "bell.slash", help: store.settings.alertsEnabled ? "Alerts on. Click to turn off" : "Alerts off. Click to turn on") {
                store.setAlertsEnabled(!store.settings.alertsEnabled)
            }
            .foregroundStyle(store.settings.alertsEnabled ? theme.foreground : theme.muted)
            IconButton(systemImage: "arrow.clockwise", help: "Refresh now") { Task { await store.refreshAll() } }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Dashboard") { openDashboard() }.buttonStyle(PillButtonStyle(isProminent: true, size: 12))
            SettingsLink { Text("Settings") }.buttonStyle(PillButtonStyle(size: 12))
            Spacer()
            if updater.isAvailable {
                IconButton(systemImage: "arrow.down.circle", help: "Check for Updates…") { checkForUpdates() }
                    .foregroundStyle(theme.muted)
                    .disabled(!updater.canCheckForUpdates)
            }
            Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.muted)
        }
    }

    private var agentsNeedingYou: [AgentSession] {
        store.needsYouGroups.map(\.agent)
    }

    /// Active agents not already listed under "Needs you".
    private var otherActiveAgents: [AgentSession] {
        store.activeAgents.filter { !$0.state.needsYou }
    }

    private var needsYouCount: Int {
        agentsNeedingYou.count
    }

    private var headline: String {
        switch needsYouCount {
        case 0: "All clear."
        case 1: "1 agent needs you."
        default: "\(needsYouCount) agents need you."
        }
    }

    private func checkForUpdates() {
        dismiss()
        updater.checkForUpdates()
    }

    private func openDashboard() {
        dismiss()
        openWindow(id: DashboardView.windowID)
        DockPresence.dashboardDidOpen()
    }
}

/// CPU, memory, network and disk tiles, shared by the panel and the dashboard overview.
struct SystemTilesGrid: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var columns = 2
    var showsNetworkAndDisk = true

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            MetricTile(title: "CPU", value: Formatters.percent(snapshot?.cpu.total ?? 0), detail: cpuDetail, history: store.cpuHistory, color: UsageLevel.color(forFraction: snapshot?.cpu.total ?? 0, in: theme), maximum: 1)
            MetricTile(title: "Memory", value: Formatters.percent(snapshot?.memory.usedFraction ?? 0), detail: memoryDetail, history: store.memoryHistory, color: memoryColor, maximum: 1)
            if showsNetworkAndDisk { networkAndDisk }
        }
    }

    @ViewBuilder
    private var networkAndDisk: some View {
        MetricTile(title: "Network", value: "↓ \(Formatters.rate(snapshot?.network.bytesInPerSecond ?? 0))", detail: "↑ \(Formatters.rate(snapshot?.network.bytesOutPerSecond ?? 0))", history: store.networkInHistory, color: theme.info)
        MetricTile(title: "Disk", value: Formatters.percent(primaryDisk?.usedFraction ?? 0), detail: diskDetail, history: [], color: UsageLevel.color(forFraction: primaryDisk?.usedFraction ?? 0, in: theme), gaugeFraction: primaryDisk?.usedFraction ?? 0)
    }

    private var snapshot: SystemSnapshot? { store.snapshot }
    private var primaryDisk: DiskUsage? { snapshot?.disks.first { $0.mountPath == "/" } ?? snapshot?.disks.first }

    private var cpuDetail: String? {
        snapshot.map { "\($0.cpu.perCore.count) cores" }
    }

    private var memoryDetail: String? {
        snapshot.map { "\(Formatters.bytes($0.memory.usedBytes)) of \(Formatters.bytes($0.memory.totalBytes))" }
    }

    private var memoryColor: Color {
        (snapshot?.memory.pressure ?? .normal).color(in: theme)
    }

    private var diskDetail: String? {
        primaryDisk.map { "\(Formatters.bytes($0.availableBytes)) free" }
    }
}
