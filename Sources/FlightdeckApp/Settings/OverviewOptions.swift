import MonitorCore

/// Numbers the overview can show in its resource strip or sidebar.
enum OverviewResource: String, CaseIterable, Codable, Identifiable {
    case cpu, memory, disk, agentFiveHour, agentWeek, network, battery

    static let defaultSelection: [OverviewResource] = [.cpu, .memory, .disk, .agentFiveHour, .agentWeek]

    var id: String { rawValue }

    func title(defaultAgent: AgentTool) -> String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .agentFiveHour: "\(defaultAgent.displayName) 5h"
        case .agentWeek: "\(defaultAgent.displayName) week"
        case .network: "Network"
        case .battery: "Battery"
        }
    }
}

/// Lines an agent card can show under the project name.
enum AgentCardField: String, CaseIterable, Codable, Identifiable {
    case action, tool, folder, branch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .action: "What it is doing"
        case .tool: "Agent and status"
        case .folder: "Folder"
        case .branch: "Branch or worktree"
        }
    }
}

/// Status groups on the agent board.
enum AgentBoardColumn: String, CaseIterable, Identifiable {
    case yourTurn, working, idle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yourTurn: "Needs you"
        case .working: "Working"
        case .idle: "Idle"
        }
    }

    func contains(_ state: AgentState) -> Bool {
        switch self {
        case .yourTurn: state.needsYou
        case .working: state == .working
        case .idle: state == .idle
        }
    }
}
