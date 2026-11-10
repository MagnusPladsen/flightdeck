import MonitorCore
import SwiftUI

/// One number in the resource strip or sidebar, with what is needed to draw it.
struct ResourceReading: Identifiable {
    let id: OverviewResource
    let title: String
    let value: String
    let detail: String
    /// 0...1 for the bar under the number, nil when there is nothing to fill.
    let fraction: Double?
    let color: Color
    var valueColor: Color?
    var history: [Double] = []
    var historyMaximum: Double?
    /// Shorter title for gauges that put the agent on its own line, such as "5h limit".
    var shortTitle: String?
    /// The agent a limit belongs to, shown under the short title.
    var agentName: String?
    var forecast: LimitForecast?
    /// Hover text: what uses the resource, or when a limit runs out.
    var tooltip: String?

    @MainActor
    static func all(store: MonitorStore, theme: Theme) -> [ResourceReading] {
        store.settings.overviewResources.map { reading($0, store: store, theme: theme) }
    }

    @MainActor
    private static func reading(_ resource: OverviewResource, store: MonitorStore, theme: Theme) -> ResourceReading {
        let snapshot = store.snapshot
        let title = resource.title(agent: resource.pinnedAgent ?? store.limitsAgent)
        switch resource {
        case .cpu:
            let cpu = snapshot?.cpu.total ?? 0
            let load = snapshot?.loadAverage.first.map { String(format: " · load %.2f", $0) } ?? ""
            return ResourceReading(id: resource, title: title, value: Formatters.percent(cpu), detail: "\(snapshot?.cpu.perCore.count ?? 0) cores\(load)", fraction: cpu, color: theme.foreground, history: store.cpuHistory, historyMaximum: 1,
                                   tooltip: ResourceTooltips.cpu(snapshot))
        case .memory:
            let memory = snapshot?.memory ?? .zero
            return ResourceReading(id: resource, title: title, value: Formatters.percent(memory.usedFraction), detail: "\(Formatters.bytes(memory.usedBytes)) of \(Formatters.bytes(memory.totalBytes))", fraction: memory.usedFraction, color: theme.foreground, valueColor: memory.pressure == .normal ? nil : memory.pressure.color(in: theme), history: store.memoryHistory, historyMaximum: 1,
                                   tooltip: ResourceTooltips.memory(snapshot))
        case .disk:
            let disk = snapshot?.disks.first { $0.mountPath == "/" } ?? snapshot?.disks.first
            let used = disk?.usedFraction ?? 0
            return ResourceReading(id: resource, title: title, value: Formatters.percent(used), detail: disk.map { "\(Formatters.bytes($0.availableBytes)) free" } ?? "—", fraction: used, color: UsageLevel.color(forFraction: used, in: theme), valueColor: used >= 0.6 ? UsageLevel.color(forFraction: used, in: theme) : nil,
                                   tooltip: ResourceTooltips.disks(snapshot))
        case .agentFiveHour, .agentWeek, .claudeFiveHour, .claudeWeek, .codexFiveHour, .codexWeek:
            return usageReading(resource, title: title, store: store, theme: theme)
        case .network:
            let network = snapshot?.network ?? .zero
            return ResourceReading(id: resource, title: title, value: Formatters.rate(network.bytesInPerSecond), detail: "up \(Formatters.rate(network.bytesOutPerSecond))", fraction: nil, color: theme.success, history: store.networkInHistory)
        case .battery:
            guard let battery = snapshot?.battery else {
                return ResourceReading(id: resource, title: title, value: "—", detail: "No battery", fraction: nil, color: theme.success)
            }
            return ResourceReading(id: resource, title: title, value: Formatters.percent(battery.percent), detail: battery.isCharging ? "charging" : (battery.isPluggedIn ? "plugged in" : "on battery"), fraction: battery.percent, color: battery.percent < 0.2 ? theme.error : theme.success)
        }
    }

    @MainActor
    private static func usageReading(_ resource: OverviewResource, title: String, store: MonitorStore, theme: Theme) -> ResourceReading {
        let agent = resource.pinnedAgent ?? store.limitsAgent
        let limit = resource.limitWindow ?? ("5h", "5h limit")
        guard let window = store.usage(for: agent)?.windows.first(where: { $0.label == limit.label }) else {
            let hint = agent == .claude && !store.settings.claudeLimitsEnabled ? "Enable in Settings" : "No data yet"
            return ResourceReading(id: resource, title: title, value: "—", detail: hint, fraction: nil, color: theme.success, shortTitle: limit.title, agentName: agent.displayName)
        }
        let color = UsageLevel.color(forPercent: window.usedPercent, in: theme)
        let forecast = store.limitForecast(for: agent, window: window)
        return ResourceReading(id: resource, title: title, value: "\(Int(window.usedPercent.rounded()))%", detail: Formatters.resetCountdown(window.resetsAt) ?? "", fraction: window.usedPercent / 100, color: color, valueColor: window.usedPercent >= 85 ? color : nil, shortTitle: limit.title, agentName: agent.displayName, forecast: forecast,
                               tooltip: ResourceTooltips.limit(agentName: agent.displayName, title: limit.title, window: window, forecast: forecast))
    }
}

extension View {
    /// Shows the reading's hover text anywhere over the cell.
    func resourceTooltip(_ reading: ResourceReading) -> some View {
        contentShape(Rectangle()).help(reading.tooltip ?? "")
    }
}
