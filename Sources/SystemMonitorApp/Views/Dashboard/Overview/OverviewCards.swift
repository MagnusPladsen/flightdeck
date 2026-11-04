import MonitorCore
import SwiftUI

struct ServersCard: View {
    @Environment(MonitorStore.self) private var store
    static let tileLimit = 8

    var body: some View {
        DashboardCard(title: "Dev servers", systemImage: "server.rack") {
            CountPill(text: "\(store.devServers.count) running")
        } content: {
            if store.devServers.isEmpty {
                EmptyHint(text: "No dev servers running")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                    ForEach(store.devServers.prefix(Self.tileLimit)) { ServerTile(port: $0) }
                }
                if store.devServers.count > Self.tileLimit {
                    Text("+\(store.devServers.count - Self.tileLimit) more in Servers & Ports").font(.caption).opacity(0.5)
                }
            }
        }
    }
}

struct AgentsCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        DashboardCard(title: "AI agents", systemImage: "sparkles") {
            HStack(spacing: 6) {
                ForEach([AgentState.working, .needsApproval, .yourTurn], id: \.self) { state in
                    let count = store.agents.filter { $0.state == state }.count
                    if count > 0 { CountPill(text: "\(count) \(state.label.lowercased())", color: state.color(in: theme)) }
                }
            }
        } content: {
            if store.activeAgents.isEmpty {
                EmptyHint(text: "No active agents")
            } else {
                VStack(spacing: 2) {
                    ForEach(store.activeAgents.prefix(8)) { agent in
                        AgentRow(agent: agent, isCompact: true)
                        if agent.id != store.activeAgents.prefix(8).last?.id { Divider().overlay(theme.border.opacity(0.5)) }
                    }
                }
            }
        }
    }
}

struct UsageCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        DashboardCard(title: "AI usage", systemImage: "chart.bar.fill") {
            if store.usage.isEmpty {
                EmptyHint(text: "Loading usage…")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(store.usage) { provider(usage: $0) }
                }
            }
        }
    }

    private func provider(usage: ProviderUsage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: usage.tool.symbolName).foregroundStyle(theme.primary)
                Text(usage.tool.displayName).font(.system(size: 13, weight: .semibold))
                if let plan = usage.plan { CountPill(text: plan) }
                Spacer()
                if let tokens = usage.tokensToday {
                    Text("\(Formatters.tokens(tokens.total)) tokens today").font(.caption).opacity(0.6)
                }
            }
            if usage.windows.isEmpty {
                Text(usage.tool == .claude ? "Turn on limit percentages in Settings › AI" : "No limit data yet").font(.caption).opacity(0.5)
            } else {
                HStack(spacing: 18) {
                    ForEach(usage.windows) { limitRing($0) }
                }
            }
        }
    }

    private func limitRing(_ window: UsageWindow) -> some View {
        let color = UsageLevel.color(forPercent: window.usedPercent, in: theme)
        return HStack(spacing: 10) {
            RingGauge(fraction: window.usedPercent / 100, color: color, lineWidth: 6) {
                Text("\(Int(window.usedPercent.rounded()))%").font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(window.label).font(.system(size: 12, weight: .medium))
                Text(Formatters.resetCountdown(window.resetsAt) ?? "").font(.caption).opacity(0.55)
            }
        }
    }
}

struct TopProcessesCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        DashboardCard(title: "Top processes", systemImage: "flame") {
            VStack(spacing: 8) {
                ForEach(topProcesses) { process in
                    HStack(spacing: 10) {
                        Text(process.name).font(.system(size: 12, weight: .medium)).lineLimit(1).frame(width: 140, alignment: .leading)
                        ProgressBar(fraction: process.cpuPercent / maxCPU, color: UsageLevel.color(forPercent: min(process.cpuPercent, 100), in: theme))
                        Text(String(format: "%.0f%%", process.cpuPercent)).font(.system(size: 12).monospacedDigit()).frame(width: 44, alignment: .trailing)
                        Text(Formatters.bytes(process.memoryBytes)).font(.system(size: 11).monospacedDigit()).opacity(0.55).frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var topProcesses: [ProcessSample] {
        Array((store.snapshot?.processes ?? []).sorted { $0.cpuPercent > $1.cpuPercent }.prefix(7))
    }

    private var maxCPU: Double {
        max(topProcesses.first?.cpuPercent ?? 100, 100)
    }
}
