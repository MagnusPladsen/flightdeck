import MonitorCore

extension SectionKind {
    @MainActor
    func title(in settings: AppSettings) -> String {
        switch self {
        case .needsYou: "Headline"
        case .clock: "Clock"
        case .resources: "Resources"
        case .nowPlaying: "Now playing"
        case .yourTurn: "Needs you"
        case .workingAgents: "Working"
        case .idleAgents: "Idle"
        case .projects: "Projects"
        case .devServers: "Dev servers"
        case .otherPorts: "Other listening ports"
        case .agentSessions: "Agent sessions"
        case .usageLimits: "Usage limits"
        case .worktrees: "Worktrees"
        case .spend: "Token spend"
        case .processTable: "Process table"
        case .widget(let id): settings.customWidgets.first { $0.id == id }?.title ?? "Widget"
        }
    }
}
