import MonitorCore
import SwiftUI

/// Which apps download and upload the most right now. Off the dashboard until added from the hidden sections.
struct NetworkByAppSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let monitor = store.networkUsage
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Network by app", count: monitor.hasReading ? monitor.consumers.count : nil) {
                Text("↓ download  ↑ upload").font(.caption).foregroundStyle(theme.muted)
            }
            if monitor.hasReading {
                HairlineRows(items: monitor.consumers, emptyText: "No app is using the network") { NetworkConsumerRow(consumer: $0, top: topRate) }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Measuring for a few seconds…").foregroundStyle(theme.muted)
                }
                .font(.callout)
                .padding(.vertical, 10)
            }
        }
        .onAppear { monitor.viewerAppeared() }
        .onDisappear { monitor.viewerDisappeared() }
    }

    private var topRate: Double { max(store.networkUsage.consumers.first?.totalPerSecond ?? 1, 1) }
}

private struct NetworkConsumerRow: View {
    @Environment(\.theme) private var theme
    var consumer: NetworkConsumer
    var top: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(consumer.name).lineLimit(1).truncationMode(.middle)
            if consumer.processCount > 1 {
                Text("\(consumer.processCount)").font(.caption2.monospacedDigit()).foregroundStyle(theme.muted)
            }
            Spacer(minLength: 8)
            ThinBar(fraction: consumer.totalPerSecond / top, color: theme.info, height: 3).frame(width: 90)
            Text("↓ \(Formatters.rate(consumer.bytesInPerSecond))").frame(width: 92, alignment: .trailing)
            Text("↑ \(Formatters.rate(consumer.bytesOutPerSecond))").foregroundStyle(theme.muted).frame(width: 92, alignment: .trailing)
        }
        .font(.system(size: 13).monospacedDigit())
        .padding(.vertical, 6)
    }
}
