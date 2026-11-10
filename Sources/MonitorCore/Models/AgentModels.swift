import Foundation

public enum AgentTool: String, Sendable, CaseIterable {
    case claude, codex, gemini, cursor, opencode, aider

    public var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .gemini: "Gemini CLI"
        case .cursor: "Cursor Agent"
        case .opencode: "opencode"
        case .aider: "Aider"
        }
    }
}

public enum AgentState: String, Sendable {
    case working
    /// Paused on a tool call that is likely waiting for the user's approval.
    case needsApproval
    /// Finished its turn; waiting for the next prompt.
    case yourTurn
    /// Mid-turn but making no progress; `AgentSession.stuckReason` says why.
    case possiblyStuck
    case idle
}

/// Why an agent that looks busy may be stuck.
public enum StuckReason: Sendable, Hashable {
    case quiet(minutes: Int)
    case repeatingTool(name: String, times: Int)

    public var summary: String {
        switch self {
        case .quiet(let minutes): "No transcript writes for \(minutes) min"
        case .repeatingTool(let name, let times): "Same \(name) call \(times) times in a row"
        }
    }
}

/// The latest thing an agent did, e.g. verb "Running", detail "swift test".
public struct AgentAction: Sendable, Hashable {
    public var verb: String
    public var detail: String

    public init(verb: String, detail: String) {
        self.verb = verb
        self.detail = detail
    }
}

public struct AgentSession: Sendable, Identifiable, Hashable {
    public var id: Int32 { pid }
    public var tool: AgentTool
    public var pid: Int32
    public var workingDirectory: String
    public var project: DevProject?
    public var state: AgentState
    public var cpuPercent: Double
    public var lastActivity: Date?
    public var lastAction: AgentAction?
    public var stuckReason: StuckReason?
    /// CPU and memory of the agent together with the builds, tests and tools it started.
    public var resources: ProcessTreeUsage?
    public var startedAt: Date?
    /// The agent's last line to the user, or the question or tool call it is waiting on.
    public var lastMessage: String?
    /// The agent's task list and the step it is on, while it has one in progress.
    public var plan: AgentPlan?
    /// How full a Claude session's context is.
    public var context: ContextUsage?

    public init(tool: AgentTool, pid: Int32, workingDirectory: String, project: DevProject?, state: AgentState, cpuPercent: Double, lastActivity: Date?, lastAction: AgentAction? = nil,
                stuckReason: StuckReason? = nil, resources: ProcessTreeUsage? = nil, startedAt: Date? = nil, lastMessage: String? = nil, plan: AgentPlan? = nil,
                context: ContextUsage? = nil) {
        self.tool = tool
        self.pid = pid
        self.workingDirectory = workingDirectory
        self.project = project
        self.state = state
        self.cpuPercent = cpuPercent
        self.lastActivity = lastActivity
        self.lastAction = lastAction
        self.stuckReason = stuckReason
        self.resources = resources
        self.startedAt = startedAt
        self.lastMessage = lastMessage
        self.plan = plan
        self.context = context
    }
}

public struct UsageWindow: Sendable, Hashable, Identifiable {
    public var id: String { label }
    public var label: String
    /// 0...100
    public var usedPercent: Double
    public var resetsAt: Date?

    public init(label: String, usedPercent: Double, resetsAt: Date?) {
        self.label = label
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

public struct TokenTotals: Sendable, Hashable {
    public var input: Int
    public var output: Int
    public var cacheRead: Int
    public var cacheWrite: Int

    public init(input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }

    public var total: Int { input + output + cacheRead + cacheWrite }

    public static func + (lhs: TokenTotals, rhs: TokenTotals) -> TokenTotals {
        TokenTotals(input: lhs.input + rhs.input, output: lhs.output + rhs.output, cacheRead: lhs.cacheRead + rhs.cacheRead, cacheWrite: lhs.cacheWrite + rhs.cacheWrite)
    }
}

public struct ProviderUsage: Sendable, Hashable, Identifiable {
    public var id: AgentTool { tool }
    public var tool: AgentTool
    public var plan: String?
    public var windows: [UsageWindow]
    public var tokensToday: TokenTotals?
    public var tokensLastFiveHours: TokenTotals?
    public var updatedAt: Date?

    public init(tool: AgentTool, plan: String? = nil, windows: [UsageWindow] = [], tokensToday: TokenTotals? = nil, tokensLastFiveHours: TokenTotals? = nil, updatedAt: Date? = nil) {
        self.tool = tool
        self.plan = plan
        self.windows = windows
        self.tokensToday = tokensToday
        self.tokensLastFiveHours = tokensLastFiveHours
        self.updatedAt = updatedAt
    }
}
