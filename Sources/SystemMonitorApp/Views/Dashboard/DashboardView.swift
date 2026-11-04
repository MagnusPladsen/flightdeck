import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview, ports, agents, processes, widgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .ports: "Servers & Ports"
        case .agents: "AI Agents"
        case .processes: "Processes"
        case .widgets: "Widgets"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .ports: "network"
        case .agents: "sparkles"
        case .processes: "cpu"
        case .widgets: "square.grid.2x2"
        }
    }
}

struct DashboardView: View {
    static let windowID = "dashboard"

    @Environment(MonitorStore.self) private var store
    @State private var selection: DashboardSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .badge(badgeCount(for: section))
            }
            .themedScrollBackground(useSurface: true)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detail(for: selection ?? .overview)
                .navigationTitle((selection ?? .overview).title)
                .toolbar {
                    Button { Task { await store.refreshAll() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                }
        }
    }

    @ViewBuilder
    private func detail(for section: DashboardSection) -> some View {
        switch section {
        case .overview: OverviewSection { selection = $0 }
        case .ports: PortsSection()
        case .agents: AgentsSection()
        case .processes: ProcessesSection()
        case .widgets: WidgetsSection()
        }
    }

    private func badgeCount(for section: DashboardSection) -> Int {
        switch section {
        case .ports: store.devServers.count
        case .agents: store.activeAgents.count
        default: 0
        }
    }
}
