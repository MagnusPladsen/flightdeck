import Foundation

/// Finds running coding-agent sessions, the folder each works in, and whether it needs you.
public final class AgentCollector: @unchecked Sendable {
    private let processes: ProcessInspector
    private let projects: ProjectResolver
    private let claudeLogs: ClaudeSessionLogs
    private let codexLogs: CodexSessionLogs
    static let busyCPUPercent = 5.0
    static let idleAfter: TimeInterval = 30 * 60
    /// Agents run each shell command in a fresh child shell, so one exists only while a command runs.
    static let shellNames: Set<String> = ["zsh", "bash", "sh", "fish", "dash"]
    /// Tools that run without a permission prompt; waiting on one means it is still working.
    static let toolsThatNeverAsk: Set<String> = ["Read", "Grep", "Glob", "LS", "Task", "Agent", "TodoWrite", "TaskOutput", "WebSearch", "ToolSearch", "Skill"]

    public init(processes: ProcessInspector = PlatformServices.makeProcessInspector(),
                projects: ProjectResolver,
                claudeLogs: ClaudeSessionLogs = ClaudeSessionLogs(),
                codexLogs: CodexSessionLogs = CodexSessionLogs()) {
        self.processes = processes
        self.projects = projects
        self.claudeLogs = claudeLogs
        self.codexLogs = codexLogs
    }

    public func collect(from samples: [ProcessSample]) -> [AgentSession] {
        let detected = samples.compactMap { sample -> (ProcessSample, AgentTool)? in
            AgentDetector.tool(forArguments: processes.arguments(of: sample.pid)).map { (sample, $0) }
        }
        let detectedPIDs = Dictionary(detected.map { ($0.0.pid, $0.1) }, uniquingKeysWith: { first, _ in first })
        let childrenByParent = Dictionary(grouping: samples, by: \.parentPID)
        let samplesByPID = Dictionary(samples.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })

        return detected.compactMap { sample, tool in
            // Agents spawn helper copies of themselves; only report the outermost one.
            if detectedPIDs[sample.parentPID] == tool { return nil }
            return session(for: sample, tool: tool, childrenByParent: childrenByParent, samplesByPID: samplesByPID)
        }
        .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    private func session(for sample: ProcessSample, tool: AgentTool, childrenByParent: [Int32: [ProcessSample]], samplesByPID: [Int32: ProcessSample]) -> AgentSession? {
        guard let directory = processes.workingDirectory(of: sample.pid) else { return nil }
        let activity = activity(for: tool, directory: directory)
        let isRunningCommand = Self.hasShellDescendant(of: sample.pid, in: childrenByParent)
        let now = Date()
        let stuckReason = Self.stuckReason(activity: activity, isRunningCommand: isRunningCommand, now: now)
        return AgentSession(
            tool: tool,
            pid: sample.pid,
            workingDirectory: directory,
            project: projects.project(containing: directory),
            state: stuckReason == nil ? Self.state(cpuPercent: sample.cpuPercent, activity: activity, isRunningCommand: isRunningCommand, now: now) : .possiblyStuck,
            cpuPercent: sample.cpuPercent,
            lastActivity: activity?.lastWrite,
            lastAction: activity?.lastAction,
            stuckReason: stuckReason,
            resources: ProcessTreeUsage.of(pid: sample.pid, childrenByParent: childrenByParent, samplesByPID: samplesByPID),
            startedAt: processes.startTime(of: sample.pid),
            lastMessage: activity?.lastMessage,
            plan: activity?.plan
        )
    }

    private func activity(for tool: AgentTool, directory: String) -> SessionActivity? {
        switch tool {
        case .claude: claudeLogs.latestActivity(forWorkingDirectory: directory)
        case .codex: codexLogs.latestActivity(forWorkingDirectory: directory)
        default: nil
        }
    }

    static func hasShellDescendant(of pid: Int32, in childrenByParent: [Int32: [ProcessSample]], depth: Int = 3) -> Bool {
        guard depth > 0 else { return false }
        return (childrenByParent[pid] ?? []).contains { child in
            shellNames.contains(child.name) || hasShellDescendant(of: child.pid, in: childrenByParent, depth: depth - 1)
        }
    }

    static func state(cpuPercent: Double, activity: SessionActivity?, isRunningCommand: Bool = false, now: Date) -> AgentState {
        if cpuPercent >= busyCPUPercent { return .working }
        guard let activity else { return .idle }
        let quietFor = now.timeIntervalSince(activity.lastWrite)
        if quietFor < 3 { return .working }
        if quietFor > idleAfter { return .idle }
        switch activity.lastTurn {
        case .waitingOnTool: return isMidTurn(activity, isRunningCommand: isRunningCommand) ? .working : .needsApproval
        case .waitingOnModel: return .working
        case .finished, .unknown: return .yourTurn
        }
    }

    /// The agent, not the user, is expected to act: the model is thinking or a tool is running.
    static func isMidTurn(_ activity: SessionActivity, isRunningCommand: Bool) -> Bool {
        switch activity.lastTurn {
        case .waitingOnModel: true
        case .waitingOnTool: isRunningCommand || activity.pendingTool.map(toolsThatNeverAsk.contains) == true
        case .finished, .unknown: false
        }
    }

    /// Across 427 real transcripts no identical call ran more than twice in a row.
    static let stuckRepeatCount = 3
    /// Bash gives up after 10 minutes and subagents keep logging progress, so 15 silent minutes mid-turn is
    /// rare in real transcripts (a few pauses over thousands of turns) and long builds stay below it.
    static let stuckQuietAfter: TimeInterval = 15 * 60

    static func stuckReason(activity: SessionActivity?, isRunningCommand: Bool, now: Date) -> StuckReason? {
        guard let activity, isMidTurn(activity, isRunningCommand: isRunningCommand) else { return nil }
        let quietFor = now.timeIntervalSince(activity.lastWrite)
        if quietFor >= stuckQuietAfter { return .quiet(minutes: Int(quietFor / 60)) }
        guard let repeated = activity.repeatedToolCall, repeated.count >= stuckRepeatCount else { return nil }
        return .repeatingTool(name: repeated.name, times: repeated.count)
    }
}

public struct SessionActivity: Sendable, Equatable {
    public enum LastTurn: Sendable, Equatable {
        /// The agent asked to run a tool and nothing came back yet.
        case waitingOnTool
        /// A tool result or prompt was sent; the model is thinking.
        case waitingOnModel
        case finished
        case unknown
    }

    public var lastWrite: Date
    public var lastTurn: LastTurn
    public var lastAction: AgentAction?
    /// Name of the tool the agent called last, e.g. "Bash".
    public var pendingTool: String?
    /// The newest tool call and how many times in a row it was made with the same input.
    public var repeatedToolCall: RepeatedToolCall?
    public var lastMessage: String?
    /// The agent's task list, while it has one in progress.
    public var plan: AgentPlan?

    public init(lastWrite: Date, lastTurn: LastTurn, lastAction: AgentAction? = nil, pendingTool: String? = nil, repeatedToolCall: RepeatedToolCall? = nil,
                lastMessage: String? = nil, plan: AgentPlan? = nil) {
        self.lastWrite = lastWrite
        self.lastTurn = lastTurn
        self.lastAction = lastAction
        self.pendingTool = pendingTool
        self.repeatedToolCall = repeatedToolCall
        self.lastMessage = lastMessage
        self.plan = plan
    }
}

public struct RepeatedToolCall: Sendable, Equatable {
    public var name: String
    public var count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}
