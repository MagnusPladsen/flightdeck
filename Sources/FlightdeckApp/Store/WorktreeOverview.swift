import Foundation
import MonitorCore
import Observation

/// The git worktrees of every repository Flightdeck has seen a server or agent in.
@MainActor
@Observable
final class WorktreeOverview {
    private(set) var worktrees: [Worktree] = []
    private(set) var hasLoaded = false
    private(set) var isCleaningUp = false
    /// What the last clean-up did, e.g. "Removed 3 worktrees".
    private(set) var cleanupSummary: String?

    private let engine: MonitorEngine
    private let settings: AppSettings
    private var isDemo = false
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var hasPendingRefresh = false

    init(engine: MonitorEngine, settings: AppSettings) {
        self.engine = engine
        self.settings = settings
    }

    var policy: StaleWorktreePolicy {
        StaleWorktreePolicy(minimumAgeDays: settings.staleWorktreeDays)
    }

    /// Each repository once, in the order its worktrees are listed.
    var repositoryRoots: [String] {
        worktrees.map(\.repositoryRoot).reduce(into: []) { roots, root in if !roots.contains(root) { roots.append(root) } }
    }

    func agentsByWorktree(_ agents: [AgentSession]) -> [String: [AgentSession]] {
        WorktreeAgentMatcher.agents(in: worktrees, from: agents)
    }

    func staleWorktrees(agents: [AgentSession]) -> [Worktree] {
        let busy = agentsByWorktree(agents)
        return worktrees.filter { policy.isStale($0, hasAgent: busy[$0.path] != nil) }
    }

    /// Adds the repositories containing `projectFolders` to the remembered ones and lists them all.
    /// A refresh asked for while one runs is run once more afterwards, so a clean-up or new worktree shows up.
    func refresh(projectFolders: [String]) async {
        guard !isDemo else { return }
        guard !isRefreshing else { return hasPendingRefresh = true }
        isRefreshing = true
        repeat {
            hasPendingRefresh = false
            await collect(projectFolders: projectFolders)
        } while hasPendingRefresh
        isRefreshing = false
    }

    private func collect(projectFolders: [String]) async {
        let engine = engine
        let remembered = settings.worktreeRepositoryFolders
        let (roots, worktrees) = await Task.detached {
            let roots = Self.existingFolders(remembered + projectFolders.compactMap(engine.repositoryRoot(containing:)))
            return (roots, engine.collectWorktrees(repositoriesContaining: roots))
        }.value
        if roots != remembered { settings.worktreeRepositoryFolders = roots }
        self.worktrees = worktrees
        hasLoaded = true
    }

    /// Removes each worktree with `git worktree remove`; dirty ones are skipped, never forced.
    func cleanUp(_ targets: [Worktree], projectFolders: [String]) async {
        isCleaningUp = true
        defer { isCleaningUp = false }
        let results = isDemo ? targets.map { _ in WorktreeRemovalResult.removed } : await remove(targets)
        cleanupSummary = Self.summary(of: results)
        if isDemo {
            let removed = Set(targets.map(\.path))
            worktrees.removeAll { removed.contains($0.path) }
        } else {
            await refresh(projectFolders: projectFolders)
        }
    }

    func showDemo(_ worktrees: [Worktree]) {
        isDemo = true
        self.worktrees = worktrees
        hasLoaded = true
    }

    private func remove(_ targets: [Worktree]) async -> [WorktreeRemovalResult] {
        let engine = engine
        return await Task.detached { targets.map(engine.removeWorktree) }.value
    }

    private static func summary(of results: [WorktreeRemovalResult]) -> String {
        let removed = results.filter { $0 == .removed }.count
        let skipped = results.count - removed
        let removedText = "Removed \(removed) worktree\(removed == 1 ? "" : "s")"
        return skipped == 0 ? removedText : "\(removedText), skipped \(skipped) that changed or failed"
    }

    nonisolated private static func existingFolders(_ folders: [String]) -> [String] {
        Set(folders).filter { FileManager.default.fileExists(atPath: $0) }.sorted()
    }
}
