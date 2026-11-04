import Charts
import MonitorCore
import SwiftUI

/// Ring gauge with the current value, plus a sparkline of recent history.
struct GaugeCard: View {
    @Environment(\.theme) private var theme
    var title: String
    var systemImage: String
    var fraction: Double
    var color: Color
    var detail: String
    var history: [Double]

    var body: some View {
        DashboardCard(title: title, systemImage: systemImage) {
            HStack(spacing: 14) {
                RingGauge(fraction: fraction, color: color, lineWidth: 8) {
                    Text(Formatters.percent(fraction))
                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                }
                .frame(width: 78, height: 78)
                Text(detail)
                    .font(.system(size: 11))
                    .opacity(0.65)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
            }
            Group {
                if history.isEmpty {
                    ProgressBar(fraction: fraction, color: color)
                } else {
                    Sparkline(values: history, color: color, maximum: 1)
                }
            }
            .frame(height: 34, alignment: .bottom)
        }
    }
}

struct NetworkCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        DashboardCard(title: "Network", systemImage: "network") {
            VStack(alignment: .leading, spacing: 6) {
                throughput(systemImage: "arrow.down", value: store.snapshot?.network.bytesInPerSecond ?? 0, color: theme.info)
                throughput(systemImage: "arrow.up", value: store.snapshot?.network.bytesOutPerSecond ?? 0, color: theme.secondary)
            }
            .frame(height: 78)
            chart.frame(height: 34)
        }
    }

    private func throughput(systemImage: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.15), in: Circle())
            Text(Formatters.rate(value))
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var chart: some View {
        Chart {
            series(store.networkInHistory, name: "In", color: theme.info)
            series(store.networkOutHistory, name: "Out", color: theme.secondary)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...(MonitorStore.historyLength - 1))
    }

    @ChartContentBuilder
    private func series(_ values: [Double], name: String, color: Color) -> some ChartContent {
        ForEach(Array(values.enumerated()), id: \.offset) { offset, value in
            let index = Sparkline.rightAlignedIndex(offset, count: values.count)
            AreaMark(x: .value("Sample", index), y: .value("Bytes", value), series: .value("Direction", name))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Sample", index), y: .value("Bytes", value), series: .value("Direction", name))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone)
        }
    }
}

struct ResourceCardsRow: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let snapshot = store.snapshot
        let cpu = snapshot?.cpu.total ?? 0
        let memory = snapshot?.memory ?? .zero
        let disk = snapshot?.disks.first { $0.mountPath == "/" } ?? snapshot?.disks.first
        Grid(horizontalSpacing: 14) {
            GridRow {
                GaugeCard(title: "CPU", systemImage: "cpu", fraction: cpu, color: UsageLevel.color(forFraction: cpu, in: theme), detail: "\(snapshot?.cpu.perCore.count ?? 0) cores", history: store.cpuHistory)
                GaugeCard(title: "Memory", systemImage: "memorychip", fraction: memory.usedFraction, color: memory.pressure.color(in: theme), detail: "\(Formatters.bytes(memory.usedBytes)) of \(Formatters.bytes(memory.totalBytes))\nSwap \(Formatters.bytes(memory.swapUsedBytes))", history: store.memoryHistory)
                GaugeCard(title: "Disk", systemImage: "internaldrive", fraction: disk?.usedFraction ?? 0, color: UsageLevel.color(forFraction: disk?.usedFraction ?? 0, in: theme), detail: disk.map { "\(Formatters.bytes($0.availableBytes)) free\nof \(Formatters.bytes($0.totalBytes))" } ?? "—", history: [])
                NetworkCard()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
