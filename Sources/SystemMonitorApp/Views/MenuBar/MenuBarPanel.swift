import MonitorCore
import SwiftUI

struct MenuBarPanel: View {
    private static let listsMaxHeight: CGFloat = 480

    @Environment(MonitorStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var listsHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            SystemTilesGrid()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionCard(title: "Dev servers", count: store.devServers.count) {
                        if store.devServers.isEmpty {
                            EmptyHint(text: "No dev servers running")
                        } else {
                            ForEach(store.devServers.prefix(6)) { PortRow(port: $0, isCompact: true) }
                        }
                    }
                    SectionCard(title: "AI agents", count: store.activeAgents.count) {
                        if store.activeAgents.isEmpty {
                            EmptyHint(text: "No active agents")
                        } else {
                            ForEach(store.activeAgents.prefix(6)) { AgentRow(agent: $0, isCompact: true) }
                        }
                    }
                    if !store.usage.isEmpty {
                        SectionCard(title: "Usage") {
                            ForEach(store.usage) { ProviderUsageView(usage: $0) }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { listsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(listsHeight, Self.listsMaxHeight))
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 380)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(store.snapshot?.hostName ?? "System Monitor").font(.headline)
                if let snapshot = store.snapshot {
                    Text("Up \(Formatters.duration(snapshot.uptime)) · load \(snapshot.loadAverage.prefix(3).map { String(format: "%.2f", $0) }.joined(separator: " "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            IconButton(systemImage: "arrow.clockwise", help: "Refresh now") { Task { await store.refreshAll() } }
        }
    }

    private var footer: some View {
        HStack {
            Button("Dashboard") { openDashboard() }
            SettingsLink { Text("Settings") }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
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

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            MetricTile(title: "CPU", value: Formatters.percent(snapshot?.cpu.total ?? 0), detail: cpuDetail, history: store.cpuHistory, color: UsageLevel.color(forFraction: snapshot?.cpu.total ?? 0, in: theme), maximum: 1)
            MetricTile(title: "Memory", value: Formatters.percent(snapshot?.memory.usedFraction ?? 0), detail: memoryDetail, history: store.memoryHistory, color: memoryColor, maximum: 1)
            MetricTile(title: "Network", value: "↓ \(Formatters.rate(snapshot?.network.bytesInPerSecond ?? 0))", detail: "↑ \(Formatters.rate(snapshot?.network.bytesOutPerSecond ?? 0))", history: store.networkInHistory, color: theme.info)
            MetricTile(title: "Disk", value: Formatters.percent(primaryDisk?.usedFraction ?? 0), detail: diskDetail, history: [], color: UsageLevel.color(forFraction: primaryDisk?.usedFraction ?? 0, in: theme), gaugeFraction: primaryDisk?.usedFraction ?? 0)
        }
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
