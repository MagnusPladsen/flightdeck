import AppKit
import MonitorCore
import SwiftUI

/// The menu bar item. Rendered to a template image because the menu bar only draws one image and one text.
struct MenuBarLabel: View {
    var store: MonitorStore

    var body: some View {
        Image(nsImage: renderedLabel)
    }

    private var renderedLabel: NSImage {
        let renderer = ImageRenderer(content: MenuBarLabelContent(items: items, statusSymbol: statusSymbol, style: store.settings.menuBarLabelStyle))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    private var statusSymbol: String? {
        if store.agents.contains(where: { $0.state == .needsApproval }) { return "exclamationmark.circle.fill" }
        return items.isEmpty ? "gauge.with.dots.needle.33percent" : nil
    }

    private var items: [MenuBarLabelContent.Item] {
        store.settings.menuBarMetrics.compactMap { metric in
            value(for: metric).map { MenuBarLabelContent.Item(metric: metric, value: $0) }
        }
    }

    private func value(for metric: MenuBarMetric) -> String? {
        switch metric {
        case .cpu: store.snapshot.map { Formatters.percent($0.cpu.total) }
        case .memory: store.snapshot.map { Formatters.percent($0.memory.usedFraction) }
        case .network: store.snapshot.map { Formatters.rate($0.network.bytesInPerSecond) }
        case .servers: "\(store.devServers.count)"
        case .agents: "\(store.activeAgents.count)"
        case .claudeLimit: fiveHourPercent(for: .claude)
        case .codexLimit: fiveHourPercent(for: .codex)
        }
    }

    private func fiveHourPercent(for tool: AgentTool) -> String? {
        store.usage(for: tool)?.windows.first.map { "\(Int($0.usedPercent.rounded()))%" }
    }
}

private struct MenuBarLabelContent: View {
    struct Item: Identifiable {
        var metric: MenuBarMetric
        var value: String
        var id: MenuBarMetric { metric }
    }

    var items: [Item]
    var statusSymbol: String?
    var style: MenuBarLabelStyle

    var body: some View {
        HStack(spacing: 8) {
            if let statusSymbol { Image(systemName: statusSymbol) }
            ForEach(items) { item in
                HStack(spacing: 3) {
                    switch style {
                    case .icons: Image(systemName: item.metric.symbolName).font(.system(size: 11, weight: .semibold))
                    case .text: Text(item.metric.shortTitle).font(.system(size: 10, weight: .semibold)).opacity(0.7)
                    }
                    Text(item.value)
                }
            }
        }
        .font(.system(size: 12, weight: .medium).monospacedDigit())
        .foregroundStyle(.black)
        .frame(height: 18)
    }
}
