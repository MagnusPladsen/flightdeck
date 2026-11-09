import Foundation
import MonitorCore

/// Owns the collectors. All methods block, so the store calls them off the main thread.
final class MonitorEngine: @unchecked Sendable {
    static let spendDays = 7
    private let system = SystemCollector()
    private let projects = ProjectResolver()
    private lazy var ports = PortCollector(projects: projects)
    private lazy var agents = AgentCollector(projects: projects)
    private let claudeTokens = ClaudeTokenTracker()
    private let codexUsage = CodexUsageReader()
    private let claudeLimits = ClaudeLimitsClient()
    private var claudeLimitsSchedule = ClaudeLimitsSchedule()
    private var isFetchingClaudeLimits = false
    private let claudeLimitsLock = NSLock()
    private let worktrees = WorktreeCollector()
    /// Created on first use so nothing reads a week of logs unless spend tracking is on.
    private lazy var spendClaudeTokens = ClaudeTokenTracker(retention: Double(Self.spendDays + 1) * 24 * 60 * 60)
    private lazy var spendCodexTokens = CodexTokenTracker(days: Self.spendDays)

    func collectSystem() -> SystemSnapshot {
        system.collect()
    }

    func collectPorts() -> [ListeningPort] {
        ports.collect()
    }

    func collectAgents(from processes: [ProcessSample]) -> [AgentSession] {
        agents.collect(from: processes)
    }

    func collectWorktrees(repositoriesContaining folders: [String]) -> [Worktree] {
        worktrees.collect(repositoriesContaining: folders)
    }

    func repositoryRoot(containing folder: String) -> String? {
        worktrees.repositoryRoot(containing: folder)
    }

    func removeWorktree(_ worktree: Worktree) -> WorktreeRemovalResult {
        worktrees.remove(worktree)
    }

    func refreshProjectCache() {
        projects.clearCache()
    }

    func collectUsage(includeClaudeLimits: Bool) async -> [ProviderUsage] {
        let tokens = claudeTokens.totals()
        var claude = includeClaudeLimits ? await latestClaudeLimits() ?? ProviderUsage(tool: .claude) : ProviderUsage(tool: .claude)
        claude.tokensToday = tokens.today
        claude.tokensLastFiveHours = tokens.lastFiveHours
        claude.updatedAt = claude.updatedAt ?? Date()
        return [claude] + [codexUsage.read()].compactMap { $0 }
    }

    func collectSpend() -> SpendReport {
        let records = spendClaudeTokens.records() + spendCodexTokens.records()
        return SpendReport.make(records: records, days: Self.spendDays) { [projects] folder in
            guard let folder else { return "Unknown folder" }
            return projects.project(containing: folder)?.name ?? (folder as NSString).lastPathComponent
        }
    }

    /// Overlapping usage polls share one request; the others get the last answer.
    private func latestClaudeLimits() async -> ProviderUsage? {
        guard claimClaudeLimitsFetch() else { return claudeLimitsLock.withLock { claudeLimitsSchedule.lastUsage } }
        let result = await claudeLimits.fetch()
        return claudeLimitsLock.withLock {
            claudeLimitsSchedule.record(result, at: Date())
            isFetchingClaudeLimits = false
            return claudeLimitsSchedule.lastUsage
        }
    }

    private func claimClaudeLimitsFetch() -> Bool {
        claudeLimitsLock.withLock {
            guard !isFetchingClaudeLimits, claudeLimitsSchedule.isDue(at: Date()) else { return false }
            isFetchingClaudeLimits = true
            return true
        }
    }
}
