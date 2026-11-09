import Foundation
import MonitorCore
import Observation

/// What each running agent changed in its repository since it started, refreshed at a gentle pace.
/// The baseline is looked up once per process, so later commits and branch switches don't move it.
@MainActor
@Observable
final class AgentChangesTracker {
    static let refreshInterval: TimeInterval = 30
    static let activityRefreshInterval: TimeInterval = 10

    private(set) var changesByPID: [Int32: AgentChanges] = [:]
    /// A nil baseline marks a folder outside git, so it is not asked again.
    @ObservationIgnored private var baselines: [Int32: ChangeBaseline?] = [:]
    @ObservationIgnored private var lastChecks: [Int32: (at: Date, activity: Date?)] = [:]
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var demoDiff: String?
    private let collector = AgentChangeCollector()

    func summary(for agent: AgentSession) -> ChangeSummary? {
        changesByPID[agent.pid].map(\.summary).flatMap { $0.isEmpty ? nil : $0 }
    }

    func refresh(agents: [AgentSession], now: Date = Date()) async {
        guard demoDiff == nil, !isRefreshing else { return }
        forgetAgents(notIn: agents)
        let due = agents.filter { isDue($0, now: now) }
        guard !due.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for agent in due { lastChecks[agent.pid] = (now, agent.lastActivity) }
        let known = baselines
        let collector = collector
        let results = await Task.detached { due.map { Self.measure($0, knownBaseline: known[$0.pid], collector: collector) } }.value
        for result in results {
            baselines[result.pid] = result.baseline
            if let changes = result.changes, changes != changesByPID[result.pid] { changesByPID[result.pid] = changes }
        }
    }

    /// The unified diff since the agent's baseline, as coloured lines.
    func diffLines(for agent: AgentSession) async -> [DiffLine] {
        if let demoDiff { return GitChangeParser.diffLines(demoDiff) }
        guard let baseline = changesByPID[agent.pid]?.baseline else { return [] }
        let collector = collector
        return await Task.detached { GitChangeParser.diffLines(collector.diff(since: baseline)) }.value
    }

    func showDemo(_ changes: [Int32: AgentChanges], diff: String) {
        demoDiff = diff
        changesByPID = changes
    }

    /// First sighting, then every 30 s, or after 10 s when the agent has written something new. Idle agents only once.
    private func isDue(_ agent: AgentSession, now: Date) -> Bool {
        guard let last = lastChecks[agent.pid] else { return true }
        if case .some(.none) = baselines[agent.pid] { return false }
        guard agent.state != .idle else { return false }
        let elapsed = now.timeIntervalSince(last.at)
        return elapsed >= Self.refreshInterval || (agent.lastActivity != last.activity && elapsed >= Self.activityRefreshInterval)
    }

    private func forgetAgents(notIn agents: [AgentSession]) {
        let running = Set(agents.map(\.pid))
        if changesByPID.keys.contains(where: { !running.contains($0) }) { changesByPID = changesByPID.filter { running.contains($0.key) } }
        baselines = baselines.filter { running.contains($0.key) }
        lastChecks = lastChecks.filter { running.contains($0.key) }
    }

    private struct Measurement: Sendable {
        let pid: Int32
        let baseline: ChangeBaseline?
        let changes: AgentChanges?
    }

    nonisolated private static func measure(_ agent: AgentSession, knownBaseline: ChangeBaseline??, collector: AgentChangeCollector) -> Measurement {
        let baseline = knownBaseline ?? collector.baseline(forFolder: agent.workingDirectory, startedAt: agent.startedAt)
        return Measurement(pid: agent.pid, baseline: baseline, changes: baseline.flatMap(collector.changes(since:)))
    }
}
