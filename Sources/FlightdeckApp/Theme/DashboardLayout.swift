import MonitorCore

/// How the dashboard is arranged. Each theme picks a layout as well as its colours.
enum DashboardLayout: String, CaseIterable, Identifiable {
    /// Needs-you headline, a resource strip, the agent board and projects by git checkout.
    case ignition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ignition: "Ignition"
        }
    }

    /// The layout as designed, before the user customises it.
    var defaultPages: PageLayouts {
        switch self {
        case .ignition:
            PageLayouts(pages: [
                .overview: [
                    SectionPlacement(kind: .needsYou, span: 8), SectionPlacement(kind: .clock),
                ] + [.resources, .yourTurn, .workingAgents, .idleAgents, .projects].map { SectionPlacement(kind: $0) },
                .ports: [SectionPlacement(kind: .devServers), SectionPlacement(kind: .otherPorts)],
                .agents: [SectionPlacement(kind: .agentSessions, span: 8), SectionPlacement(kind: .usageLimits, span: 4)],
                .processes: [SectionPlacement(kind: .processTable)],
            ])
        }
    }
}
