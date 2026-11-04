import AppKit
import MonitorCore
import SwiftUI

/// The menu bar item. Rendered to an image because the menu bar only draws one image and one text.
struct MenuBarLabel: View {
    var store: MonitorStore

    var body: some View {
        Image(nsImage: renderedLabel)
    }

    // Not a template image, so the yellow dot keeps its colour; the drawing handler picks the
    // black or white rendering from the appearance of the menu bar it is drawn into.
    private var renderedLabel: NSImage {
        let lightBar = render(foreground: .black)
        let darkBar = render(foreground: .white)
        let image = NSImage(size: lightBar.size, flipped: false) { rect in
            let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            (isDark ? darkBar : lightBar).draw(in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }

    private func render(foreground: Color) -> NSImage {
        let content = MenuBarLabelContent(items: items, statusSymbol: statusSymbol, style: store.settings.menuBarLabelStyle, foreground: foreground)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage ?? NSImage()
    }

    private var statusSymbol: String? {
        if !store.settings.isShowingInMenuBar(.agentsNeedingYou), store.agents.contains(where: { $0.state == .needsApproval }) {
            return "exclamationmark.circle.fill"
        }
        return items.isEmpty ? "gauge.with.dots.needle.33percent" : nil
    }

    private var items: [MenuBarLabelContent.Item] {
        store.settings.menuBarMetrics.compactMap { metric in
            value(for: metric).map { MenuBarLabelContent.Item(metric: metric, value: $0, fraction: fraction(for: metric)) }
        }
    }

    private func value(for metric: MenuBarMetric) -> String? {
        switch metric {
        case .cpu: store.snapshot.map { Formatters.percent($0.cpu.total) }
        case .memory: store.snapshot.map { Formatters.percent($0.memory.usedFraction) }
        case .workingAgents: "\(store.agents.filter { $0.state == .working }.count)"
        case .agentsNeedingYou: needsYouCount > 0 ? "\(needsYouCount)" : nil
        case .network: store.snapshot.map { Formatters.rate($0.network.bytesInPerSecond) }
        case .servers: "\(store.devServers.count)"
        case .agents: "\(store.activeAgents.count)"
        case .claudeLimit: fiveHourPercent(for: .claude)
        case .codexLimit: fiveHourPercent(for: .codex)
        }
    }

    /// How full a metric is, for the bars label style; nil for counts and rates.
    private func fraction(for metric: MenuBarMetric) -> Double? {
        switch metric {
        case .cpu: store.snapshot?.cpu.total
        case .memory: store.snapshot?.memory.usedFraction
        case .claudeLimit: store.usage(for: .claude)?.windows.first.map { $0.usedPercent / 100 }
        case .codexLimit: store.usage(for: .codex)?.windows.first.map { $0.usedPercent / 100 }
        default: nil
        }
    }

    private var needsYouCount: Int {
        store.agents.filter(\.state.needsYou).count
    }

    private func fiveHourPercent(for tool: AgentTool) -> String? {
        store.usage(for: tool)?.windows.first.map { "\(Int($0.usedPercent.rounded()))%" }
    }
}

private struct MenuBarLabelContent: View {
    struct Item: Identifiable {
        var metric: MenuBarMetric
        var value: String
        var fraction: Double?
        var id: MenuBarMetric { metric }
    }

    var items: [Item]
    var statusSymbol: String?
    var style: MenuBarLabelStyle
    var foreground: Color

    var body: some View {
        HStack(spacing: 8) {
            if let statusSymbol { Image(systemName: statusSymbol) }
            if style == .bars {
                HStack(spacing: 2) { ForEach(barItems) { bar($0.fraction ?? 0) } }
                ForEach(items.filter { $0.fraction == nil }) { inline($0) }
            } else {
                ForEach(items) { inline($0) }
            }
        }
        .font(.system(size: 12, weight: .medium).monospacedDigit())
        .foregroundStyle(foreground)
        .frame(height: 18)
    }

    private func inline(_ item: Item) -> some View {
        HStack(spacing: 3) {
            glyph(for: item.metric)
            Text(item.value)
        }
    }

    private var barItems: [Item] { items.filter { $0.fraction != nil } }

    private func bar(_ fraction: Double) -> some View {
        ZStack(alignment: .bottom) {
            Capsule().opacity(0.25)
            Capsule().frame(height: 14 * min(max(fraction, 0), 1))
        }
        .frame(width: 3.5, height: 14)
    }

    @ViewBuilder
    private func glyph(for metric: MenuBarMetric) -> some View {
        switch (metric, style) {
        case (.workingAgents, _): RobotGlyph().frame(width: 11, height: 12)
        case (.agentsNeedingYou, _): Circle().fill(.yellow).frame(width: 7, height: 7)
        case (_, .icons): Image(systemName: metric.symbolName).font(.system(size: 11, weight: .semibold))
        case (_, .text), (_, .bars): Text(metric.shortTitle).font(.system(size: 10, weight: .semibold)).opacity(0.7)
        }
    }
}

/// A small robot head; SF Symbols has no robot before macOS 15.
private struct RobotGlyph: View {
    var body: some View {
        VStack(spacing: 0) {
            Circle().frame(width: 2.5, height: 2.5)
            Rectangle().frame(width: 1.2, height: 1.5)
            RoundedRectangle(cornerRadius: 2.5)
                .frame(width: 11, height: 8)
                .overlay {
                    HStack(spacing: 3) {
                        Circle().frame(width: 2.2, height: 2.2)
                        Circle().frame(width: 2.2, height: 2.2)
                    }
                    .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
