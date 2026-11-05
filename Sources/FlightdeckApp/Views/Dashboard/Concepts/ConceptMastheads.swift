import MonitorCore
import SwiftUI

/// The strip a layout puts above the search field: a masthead, a status strip or a prompt.
struct LayoutMasthead: View {
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        switch layout {
        case .macOS: HostHeader()
        case .terminal: PromptLine()
        case .cockpit: CockpitStatusStrip()
        case .editorial: EditorialMasthead()
        case .neon: NeonTitle()
        case .mission: MissionStrip()
        default: EmptyView()
        }
    }
}

/// Key hints under the terminal layout, like a TUI's footer.
struct LayoutFooter: View {
    @Environment(\.dashboardLayout) private var layout
    @Environment(\.theme) private var theme

    var body: some View {
        if layout == .terminal {
            HStack(spacing: 18) {
                hint("⌘K", "ask claude")
                hint("⌘,", "settings")
                hint("click", "open")
                Spacer()
                Text("flightdeck").foregroundStyle(theme.muted)
            }
            .font(.system(size: 12, design: .monospaced))
            .padding(.vertical, 8)
            .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
        }
    }

    private func hint(_ key: String, _ action: String) -> Text {
        Text("[\(key)]").foregroundStyle(theme.primary) + Text(" \(action)").foregroundStyle(theme.muted)
    }
}

/// Facts about this Mac that every masthead draws from.
private struct HostFacts {
    var host: String
    var uptime: String
    var load: String
    var battery: String?

    @MainActor
    init(store: MonitorStore) {
        let snapshot = store.snapshot
        host = snapshot?.hostName ?? "This Mac"
        uptime = snapshot.map { Formatters.duration($0.uptime) } ?? "—"
        load = snapshot?.loadAverage.first.map { String(format: "%.2f", $0) } ?? "—"
        battery = snapshot?.battery.map { Formatters.percent($0.percent) }
    }
}

private struct HostHeader: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let facts = HostFacts(store: store)
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SYSTEM MONITOR").font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(theme.muted)
                Text(facts.host).font(.system(size: 30, weight: .bold)).tracking(-0.6)
            }
            Spacer()
            HStack(spacing: 8) {
                pill("Up \(facts.uptime)")
                pill("Load \(facts.load)")
                if let battery = facts.battery { pill("Battery \(battery)") }
            }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.foreground.opacity(0.8))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(theme.overlay, in: Capsule())
    }
}

private struct PromptLine: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let facts = HostFacts(store: store)
        HStack {
            Text("\(DemoData.isEnabled ? DemoData.userName.lowercased() : NSUserName())@\(facts.host)").foregroundStyle(theme.primary) + Text(" ~ ") + Text("flightdeck --watch").foregroundStyle(theme.foreground)
            Spacer()
            Text("up \(facts.uptime) · load \(facts.load)").foregroundStyle(theme.muted)
        }
        .font(.system(size: 13, design: .monospaced))
    }
}

private struct CockpitStatusStrip: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let facts = HostFacts(store: store)
        let waiting = store.needsYouGroups.count
        HStack(spacing: 18) {
            Text("FLIGHTDECK // \(facts.host.uppercased())").foregroundStyle(theme.primary)
            Text("UP \(facts.uptime.uppercased())")
            Text("LOAD \(facts.load)")
            Spacer()
            Text(waiting == 0 ? "● NOMINAL" : "▲ \(waiting) CAUTION").foregroundStyle(waiting == 0 ? theme.success : theme.error)
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .tracking(1.2)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .overlay(Rectangle().strokeBorder(theme.border))
    }
}

private struct EditorialMasthead: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text("The Flightdeck").font(.system(size: 52, weight: .regular, design: .serif)).italic()
                Spacer()
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.system(size: 12, weight: .semibold, design: .default)).tracking(1.4).textCase(.uppercase).foregroundStyle(theme.muted)
            }
            Rectangle().fill(theme.foreground).frame(height: 2)
        }
    }
}

private struct NeonTitle: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let facts = HostFacts(store: store)
        HStack(alignment: .center) {
            Text("SYS//MON").font(.system(size: 30, weight: .black, design: .monospaced)).tracking(3)
                .foregroundStyle(theme.primary).shadow(color: theme.primary.opacity(0.8), radius: 10)
            Spacer()
            ForEach([facts.host.uppercased(), "UP \(facts.uptime.uppercased())", "LOAD \(facts.load)"], id: \.self) { tag in
                Text(tag).font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .foregroundStyle(theme.accent)
                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.7)))
                    .shadow(color: theme.accent.opacity(0.5), radius: 6)
            }
        }
    }
}

private struct MissionStrip: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let waiting = store.needsYouGroups.count
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MISSION ELAPSED").foregroundStyle(theme.muted)
                Text("T+ \(missionClock)").font(.system(size: 18, weight: .light).monospacedDigit()).tracking(1)
            }
            Spacer()
            Text("● ALL SYSTEMS NOMINAL").foregroundStyle(theme.success)
            if waiting > 0 { Text("◆ \(waiting) CREW ACTION").foregroundStyle(theme.warning) }
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(1.6)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.border).frame(height: 1) }
    }

    /// Uptime as DD:HH:MM:SS.
    private var missionClock: String {
        let seconds = Int(store.snapshot?.uptime ?? 0)
        return String(format: "%02d:%02d:%02d:%02d", seconds / 86_400, seconds / 3_600 % 24, seconds / 60 % 60, seconds % 60)
    }
}
