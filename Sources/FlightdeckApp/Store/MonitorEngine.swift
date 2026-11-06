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

    private func latestClaudeLimits() async -> ProviderUsage? {
        if claudeLimitsSchedule.isDue(at: Date()) {
            claudeLimitsSchedule.record(await claudeLimits.fetch(), at: Date())
        }
        return claudeLimitsSchedule.lastUsage
    }
}
