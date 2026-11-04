import MonitorCore
import SwiftUI

/// Resources as a row of large numbers above the agents.
struct ResourceStrip: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ResourceControls(moveTitle: "Send to sidebar", moveImage: "sidebar.right")
            VStack(spacing: 0) {
                Hairline()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .leading)], alignment: .leading, spacing: 0) {
                    ForEach(ResourceReading.all(store: store, theme: theme)) { StripCell(reading: $0) }
                }
                Hairline()
            }
        }
    }
}

private struct StripCell: View {
    @Environment(\.theme) private var theme
    var reading: ResourceReading

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reading.value)
                .font(.system(size: 38, weight: .light).monospacedDigit())
                .tracking(-1)
                .foregroundStyle(reading.valueColor ?? theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            (Text(reading.title) + Text(reading.detail.isEmpty ? "" : " · " + reading.detail).foregroundStyle(theme.foreground.opacity(0.35)))
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
            if let fraction = reading.fraction {
                ThinBar(fraction: fraction, color: reading.color, height: 2).frame(width: 110).padding(.top, 8)
            }
        }
        .padding(.vertical, 20)
    }
}

/// Resources as a column beside the board, with history where there is some.
struct ResourceSidebar: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var navigate: (DashboardPage) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.snapshot?.hostName ?? "This Mac").font(.system(size: 15, weight: .bold)).lineLimit(1)
                    Spacer()
                    if let uptime = store.snapshot?.uptime {
                        Text("Up \(Formatters.duration(uptime))").font(.system(size: 13)).foregroundStyle(theme.muted)
                    }
                }
                ResourceControls(moveTitle: "Move to top", moveImage: "rectangle.topthird.inset.filled")
                ForEach(ResourceReading.all(store: store, theme: theme)) { SidebarCell(reading: $0) }
                SeeAllLink(title: "See all processes →") { navigate(.processes) }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 28)
        }
        .background {
            ZStack {
                theme.foreground.opacity(0.02)
                RadialGradient(colors: [theme.attention.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 360)
            }
        }
        .overlay(alignment: .leading) { Rectangle().fill(theme.border).frame(width: 1) }
    }
}

private struct SidebarCell: View {
    @Environment(\.theme) private var theme
    var reading: ResourceReading
    /// About 20 seconds of samples; fewer reads as an empty chart.
    private static let minimumHistory = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(reading.title).font(.system(size: 13)).foregroundStyle(theme.muted)
                Spacer()
                Text(reading.value)
                    .font(.system(size: 26, weight: .light).monospacedDigit())
                    .foregroundStyle(reading.valueColor ?? theme.foreground)
                    .contentTransition(.numericText())
            }
            if reading.history.count >= Self.minimumHistory {
                Sparkline(values: reading.history, color: reading.color.opacity(0.85), maximum: reading.historyMaximum).frame(height: 34)
            } else if let fraction = reading.fraction {
                ThinBar(fraction: fraction, color: reading.color, height: 4)
            }
            if !reading.detail.isEmpty {
                Text(reading.detail).font(.system(size: 12)).foregroundStyle(theme.muted)
            }
        }
    }
}

/// Customize and move buttons shared by both resource placements.
private struct ResourceControls: View {
    @Environment(MonitorStore.self) private var store
    var moveTitle: String
    var moveImage: String
    @State private var isCustomizing = false

    var body: some View {
        HStack(spacing: 10) {
            Button("Customize") { isCustomizing = true }
                .buttonStyle(PillButtonStyle())
                .popover(isPresented: $isCustomizing, arrowEdge: .bottom) {
                    OptionChecklist(
                        title: "Show resources",
                        options: OverviewResource.allCases,
                        label: { $0.title(defaultAgent: store.settings.defaultAgent) },
                        isOn: { store.settings.overviewResources.contains($0) },
                        setOn: { resource, isOn in
                            store.settings.overviewResources = AppSettings.updating(store.settings.overviewResources, with: resource, shown: isOn)
                        }
                    )
                    .padding(16)
                    .frame(minWidth: 220, alignment: .leading)
                }
            Button { store.settings.resourcesInSidebar.toggle() } label: { Label(moveTitle, systemImage: moveImage) }
                .buttonStyle(PillButtonStyle())
        }
    }
}

private struct ThinBar: View {
    @Environment(\.theme) private var theme
    var fraction: Double
    var color: Color
    var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.border)
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .animation(.smooth, value: fraction)
    }
}
