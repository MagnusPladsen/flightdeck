import Foundation
import MonitorCore

/// Owns the collectors. All methods block, so the store calls them off the main thread.
final class MonitorEngine: @unchecked Sendable {
    private let system = SystemCollector()
    private let projects = ProjectResolver()
    private lazy var ports = PortCollector(projects: projects)
    private lazy var agents = AgentCollector(projects: projects)
    private let claudeTokens = ClaudeTokenTracker()
    private let codexUsage = CodexUsageReader()
    private let claudeLimits = ClaudeLimitsClient()
    private var claudeLimitsSchedule = ClaudeLimitsSchedule()
    private let worktrees = WorktreeCollector()

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

    private func latestClaudeLimits() async -> ProviderUsage? {
        if claudeLimitsSchedule.isDue(at: Date()) {
            claudeLimitsSchedule.record(await claudeLimits.fetch(), at: Date())
        }
        return claudeLimitsSchedule.lastUsage
    }
}
