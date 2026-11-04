import MonitorCore
import SwiftUI

extension AgentState {
    func color(in theme: Theme) -> Color {
        switch self {
        case .working: theme.success
        case .needsApproval, .yourTurn: theme.warning
        case .idle: theme.foreground.opacity(0.4)
        }
    }

    /// Approval and your turn are the same status to the user: the agent is waiting on you.
    var needsYou: Bool {
        self == .needsApproval || self == .yourTurn
    }

    var label: String {
        switch self {
        case .working: "Working"
        case .needsApproval: "Needs approval"
        case .yourTurn: "Your turn"
        case .idle: "Idle"
        }
    }
}

extension AgentTool {
    var symbolName: String {
        switch self {
        case .claude: "sparkle"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .gemini: "diamond"
        case .cursor: "cursorarrow.rays"
        case .opencode: "terminal"
        case .aider: "wand.and.stars"
        }
    }
}

extension MemoryPressure {
    func color(in theme: Theme) -> Color {
        switch self {
        case .normal: theme.success
        case .warning: theme.warning
        case .critical: theme.error
        }
    }
}

enum UsageLevel {
    static func color(forPercent percent: Double, in theme: Theme) -> Color {
        switch percent {
        case ..<60: theme.success
        case ..<85: theme.warning
        default: theme.error
        }
    }

    static func color(forFraction fraction: Double, in theme: Theme) -> Color {
        color(forPercent: fraction * 100, in: theme)
    }
}
