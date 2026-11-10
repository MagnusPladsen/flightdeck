import MonitorCore
import SwiftUI

/// The apps using the most CPU and memory, each with its helper processes counted in. Collapsible.
struct ProcessBreakdown: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    /// Called with an app's name to filter the process table to it.
    var onSelect: (String) -> Void
    private static let rowLimit = 8

    var body: some View {
        @Bindable var settings = store.settings
        DisclosureGroup(isExpanded: $settings.showsProcessBreakdown) {
            HStack(alignment: .top, spacing: 32) {
                column(title: "CPU", consumers: consumers(by: .cpu), value: cpuText, fraction: cpuFraction)
                column(title: "Memory", consumers: consumers(by: .memory), value: { Formatters.bytes($0.memoryBytes) }, fraction: memoryFraction)
            }
            .padding(.top, 10)
        } label: {
            Text("What's using what").font(.system(size: 13, weight: .bold))
        }
        .padding(.bottom, 14)
    }

    private func column(title: String, consumers: [ResourceConsumer], value: @escaping (ResourceConsumer) -> String,
                        fraction: @escaping (ResourceConsumer) -> Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.muted).padding(.bottom, 4)
            HairlineRows(items: consumers, emptyText: "Nothing yet") { consumer in
                ConsumerRow(consumer: consumer, value: value(consumer), fraction: fraction(consumer)) { onSelect(consumer.name) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func consumers(by measure: ResourceBreakdown.Measure) -> [ResourceConsumer] {
        ResourceBreakdown.consumers(of: store.snapshot?.processes ?? [], by: measure, limit: Self.rowLimit)
    }

    /// Like the table: percent of one core, so a busy app can pass 100%.
    private func cpuText(_ consumer: ResourceConsumer) -> String { String(format: "%.1f%%", consumer.cpuPercent) }

    /// Bars are relative to the top app in the column, so the ranking is easy to read.
    private func cpuFraction(_ consumer: ResourceConsumer) -> Double {
        consumer.cpuPercent / max(consumers(by: .cpu).first?.cpuPercent ?? 1, 0.1)
    }

    private func memoryFraction(_ consumer: ResourceConsumer) -> Double {
        Double(consumer.memoryBytes) / Double(max(consumers(by: .memory).first?.memoryBytes ?? 1, 1))
    }
}

private struct ConsumerRow: View {
    @Environment(\.theme) private var theme
    var consumer: ResourceConsumer
    var value: String
    var fraction: Double
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Text(consumer.name).lineLimit(1).truncationMode(.middle)
                if consumer.processCount > 1 {
                    Text("\(consumer.processCount)").font(.caption2.monospacedDigit()).foregroundStyle(theme.muted)
                }
                Spacer(minLength: 8)
                ThinBar(fraction: fraction, color: theme.info, height: 3).frame(width: 90)
                Text(value).font(.callout.monospacedDigit()).frame(width: 72, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        let top = consumer.processes.prefix(5).map { "\($0.name) — \(String(format: "%.1f%%", $0.cpuPercent)) CPU, \(Formatters.bytes($0.memoryBytes))" }
        let more = consumer.processCount > 5 ? ["and \(consumer.processCount - 5) more"] : []
        return (top + more + ["", "Click to show these in the table"]).joined(separator: "\n")
    }
}
