import Foundation

extension StatusReport {
    /// Builds the report from what the app collected; only dev servers are listed, not system ports.
    public static func collect(agents: [AgentSession], ports: [ListeningPort], snapshot: SystemSnapshot?, usage: [ProviderUsage], appVersion: String?, now: Date) -> StatusReport {
        let servers = ports.filter(\.isDevServer).map(StatusServer.init(port:))
        return StatusReport(
            appVersion: appVersion,
            updatedAt: now,
            counts: StatusCounts(agents: agents, servers: servers.count),
            agents: agents.map(StatusAgent.init(session:)),
            servers: servers,
            system: snapshot.map(StatusSystem.init(snapshot:)),
            limits: usage.flatMap { provider in provider.windows.map { StatusLimit(tool: provider.tool, window: $0) } }
        )
    }
}

extension StatusCounts {
    init(agents: [AgentSession], servers: Int) {
        self.init(
            working: agents.filter { $0.state == .working }.count,
            needsYou: agents.filter { AgentAlerts.waitingStates.contains($0.state) }.count,
            idle: agents.filter { $0.state == .idle }.count,
            servers: servers
        )
    }
}

extension StatusAgent {
    init(session: AgentSession) {
        let isWaiting = AgentAlerts.waitingStates.contains(session.state)
        tool = session.tool.rawValue
        folder = session.workingDirectory
        project = session.project?.name ?? URL(fileURLWithPath: session.workingDirectory).lastPathComponent
        branch = session.project?.branch
        state = session.state.rawValue
        waitingSince = isWaiting ? session.lastActivity : nil
        lastActivity = session.lastActivity
        lastAction = session.lastAction.map { [$0.verb, $0.detail].filter { !$0.isEmpty }.joined(separator: " ") }
    }
}

extension StatusServer {
    init(port: ListeningPort) {
        self.port = port.port
        project = port.containerName ?? port.project?.name
        framework = port.framework?.displayName
    }
}

extension StatusSystem {
    init(snapshot: SystemSnapshot) {
        cpuPercent = Int((snapshot.cpu.total * 100).rounded())
        memoryPercent = Int((snapshot.memory.usedFraction * 100).rounded())
    }
}

extension StatusLimit {
    init(tool: AgentTool, window: UsageWindow) {
        self.tool = tool.rawValue
        self.window = window.label
        usedPercent = Int(window.usedPercent.rounded())
        resetsAt = window.resetsAt
    }
}
