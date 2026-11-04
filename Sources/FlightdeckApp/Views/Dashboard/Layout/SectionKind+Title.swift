import MonitorCore

extension SectionKind {
    @MainActor
    func title(in settings: AppSettings) -> String {
        switch self {
        case .needsYou: "Needs you"
        case .clock: "Clock"
        case .resources: "Resources"
        case .yourTurn: "Your turn"
        case .workingAgents: "Working"
        case .idleAgents: "Idle"
        case .projects: "Projects"
        case .devServers: "Dev servers"
        case .otherPorts: "Other listening ports"
        case .agentSessions: "Agent sessions"
        case .usageLimits: "Usage limits"
        case .processTable: "Process table"
        case .widget(let id): settings.customWidgets.first { $0.id == id }?.title ?? "Widget"
        }
    }
}
