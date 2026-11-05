import MonitorCore

/// Numbers the overview can show in its resource strip or sidebar.
enum OverviewResource: String, CaseIterable, Codable, Identifiable {
    case cpu, memory, disk, agentFiveHour, agentWeek, claudeFiveHour, claudeWeek, codexFiveHour, codexWeek, network, battery

    static let defaultSelection: [OverviewResource] = [.cpu, .memory, .agentFiveHour, .agentWeek]

    var id: String { rawValue }

    /// The usage window a limit resource shows, nil for system resources.
    var limitWindow: (label: String, title: String)? {
        switch self {
        case .agentFiveHour, .claudeFiveHour, .codexFiveHour: ("5h", "5h limit")
        case .agentWeek, .claudeWeek, .codexWeek: ("Weekly", "Week limit")
        default: nil
        }
    }

    /// The agent a limit resource is pinned to; nil follows the default agent.
    var pinnedAgent: AgentTool? {
        switch self {
        case .claudeFiveHour, .claudeWeek: .claude
        case .codexFiveHour, .codexWeek: .codex
        default: nil
        }
    }

    func title(agent: AgentTool) -> String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .agentFiveHour, .claudeFiveHour, .codexFiveHour: "\(agent.displayName) 5h"
        case .agentWeek, .claudeWeek, .codexWeek: "\(agent.displayName) week"
        case .network: "Network"
        case .battery: "Battery"
        }
    }

    /// Name in the Customize list, where the default-agent limits must read apart from the pinned ones.
    var customizeTitle: String {
        switch self {
        case .agentFiveHour: "5h limit · default agent"
        case .agentWeek: "Week limit · default agent"
        default: title(agent: pinnedAgent ?? .claude)
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
