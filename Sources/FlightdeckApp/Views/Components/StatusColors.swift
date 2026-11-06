import MonitorCore
import SwiftUI

extension AgentState {
    func color(in theme: Theme) -> Color {
        switch self {
        case .working: theme.success
        case .needsApproval, .yourTurn, .possiblyStuck: theme.warning
        case .idle: theme.foreground.opacity(0.4)
        }
    }

    /// Approval, your turn and a stuck agent all mean the same to the user: the agent is waiting on you.
    var needsYou: Bool {
        self == .needsApproval || self == .yourTurn || self == .possiblyStuck
    }

    var label: String {
        switch self {
        case .working: "Working"
        case .needsApproval: "Needs approval"
        case .yourTurn: "Needs you"
        case .possiblyStuck: "Possibly stuck"
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
