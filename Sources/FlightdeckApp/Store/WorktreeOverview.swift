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
    /// Dependency and build folders per worktree path, e.g. `node_modules`, rescanned every few minutes.
    private(set) var cacheUsage: [String: BuildCacheUsage] = [:]
    static let cacheRescanInterval: TimeInterval = 10 * 60

    private let engine: MonitorEngine
    private let settings: AppSettings
    private var isDemo = false
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private var hasPendingRefresh = false
    @ObservationIgnored private var isScanningCaches = false
    @ObservationIgnored private var cacheScannedAt: [String: Date] = [:]

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

    /// Build-cache bytes that removing `worktrees` frees along with them.
    func cacheBytes(of worktrees: [Worktree]) -> UInt64 {
        worktrees.reduce(0) { $0 + (cacheUsage[$1.path]?.totalBytes ?? 0) }
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
        Task { await scanCaches() }
    }

    private func scanCaches(now: Date = Date()) async {
        guard !isScanningCaches else { return }
        let due = worktrees.map(\.path).filter { now.timeIntervalSince(cacheScannedAt[$0] ?? .distantPast) >= Self.cacheRescanInterval }
        guard !due.isEmpty else { return }
        isScanningCaches = true
        defer { isScanningCaches = false }
        for path in due { cacheScannedAt[path] = now }
        let results = await Task.detached { due.map { ($0, BuildCacheScanner.usage(in: $0)) } }.value
        let current = Set(worktrees.map(\.path))
        var usage = cacheUsage.filter { current.contains($0.key) }
        for (path, found) in results { usage[path] = found }
        if usage != cacheUsage { cacheUsage = usage }
    }

    /// Removes each worktree with `git worktree remove`; dirty ones are skipped, never forced.
    /// Removes the worktrees and returns the ones that were removed.
    @discardableResult
    func cleanUp(_ targets: [Worktree], projectFolders: [String]) async -> [Worktree] {
        isCleaningUp = true
        defer { isCleaningUp = false }
        let results = isDemo ? targets.map { _ in WorktreeRemovalResult.removed } : await remove(targets)
        cleanupSummary = Self.summary(of: results)
        let removed = zip(targets, results).filter { $0.1 == .removed }.map(\.0)
        if isDemo {
            let removedPaths = Set(targets.map(\.path))
            worktrees.removeAll { removedPaths.contains($0.path) }
        } else {
            await refresh(projectFolders: projectFolders)
        }
        return removed
    }

    func showDemo(_ worktrees: [Worktree], cacheUsage: [String: BuildCacheUsage]) {
        isDemo = true
        self.worktrees = worktrees
        self.cacheUsage = cacheUsage
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
