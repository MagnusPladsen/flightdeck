import Foundation

public enum WorktreeRemovalResult: Sendable, Hashable {
    case removed
    /// The worktree had changes by the time it was removed, so it was left alone.
    case skippedDirty
    case failed
}

/// Lists the worktrees of the repositories Flightdeck has seen and removes stale ones.
/// Methods block on git and gh, so call them off the main thread.
public final class WorktreeCollector: @unchecked Sendable {
    public static let pullRequestCacheLifetime: TimeInterval = 600

    private let git: String?
    private let gh: String?
    private let lock = NSLock()
    /// Any folder inside a repository -> that repository's main worktree.
    private var repositoryRoots: [String: String] = [:]
    /// Pull requests by branch per repository; nil when gh can't answer for it.
    private var pullRequestCache: [String: (fetchedAt: Date, byBranch: [String: PullRequestInfo]?)] = [:]

    public init(git: String? = CommandRunner.locate("git"), gh: String? = CommandRunner.locate("gh")) {
        self.git = git
        self.gh = gh
    }

    /// Worktrees of every repository containing one of `folders`, main checkout first.
    public func collect(repositoriesContaining folders: [String], now: Date = Date()) -> [Worktree] {
        let roots = Set(folders.compactMap(repositoryRoot(containing:)))
        return roots.sorted().flatMap { worktrees(ofRepositoryAt: $0, now: now) }
    }

    public func repositoryRoot(containing folder: String) -> String? {
        if let cached = withLock({ repositoryRoots[folder] }) { return cached }
        guard let root = listEntries(in: folder).first?.path else { return nil }
        withLock { repositoryRoots[folder] = root }
        return root
    }

    /// Runs `git worktree remove` without `--force`, after checking once more that it is clean.
    public func remove(_ worktree: Worktree) -> WorktreeRemovalResult {
        guard let git, !worktree.isMain else { return .failed }
        let status = CommandRunner.run(git, ["-C", worktree.path, "status", "--porcelain=v2"])
        guard status.exitCode == 0 else { return .failed }
        guard !GitOutputParser.status(status.output).isDirty else { return .skippedDirty }
        let result = CommandRunner.run(git, ["-C", worktree.repositoryRoot, "worktree", "remove", worktree.path], timeout: 30)
        return result.exitCode == 0 ? .removed : .failed
    }

    private func worktrees(ofRepositoryAt root: String, now: Date) -> [Worktree] {
        let entries = listEntries(in: root).filter { !$0.isBare && !$0.isPrunable }
        let pullRequests = pullRequestsByBranch(in: root, now: now)
        let name = (root as NSString).lastPathComponent
        return entries.map { entry in
            Worktree(repositoryName: name, repositoryRoot: root, path: entry.path, branch: entry.branch, head: entry.head, isMain: entry.path == root,
                     isLocked: entry.isLocked, status: status(of: entry.path), lastCommitDate: lastCommitDate(of: entry.path),
                     pullRequest: lookup(entry.branch, in: pullRequests))
        }
    }

    private func lookup(_ branch: String?, in pullRequests: [String: PullRequestInfo]?) -> PullRequestLookup {
        guard let pullRequests else { return .unavailable }
        return branch.flatMap { pullRequests[$0] }.map(PullRequestLookup.found) ?? .none
    }

    private func listEntries(in folder: String) -> [WorktreeListEntry] {
        guard let git else { return [] }
        let result = CommandRunner.run(git, ["-C", folder, "worktree", "list", "--porcelain"])
        return result.exitCode == 0 ? GitOutputParser.worktreeList(result.output) : []
    }

    private func status(of path: String) -> GitStatusSummary {
        guard let git else { return GitStatusSummary() }
        return GitOutputParser.status(CommandRunner.run(git, ["-C", path, "status", "--porcelain=v2", "--branch"]).output)
    }

    private func lastCommitDate(of path: String) -> Date? {
        guard let git else { return nil }
        return GitOutputParser.commitDate(CommandRunner.run(git, ["-C", path, "log", "-1", "--format=%ct"]).output)
    }

    /// Asks gh at most once per `pullRequestCacheLifetime` per repository.
    private func pullRequestsByBranch(in root: String, now: Date) -> [String: PullRequestInfo]? {
        if let cached = withLock({ pullRequestCache[root] }), now.timeIntervalSince(cached.fetchedAt) < Self.pullRequestCacheLifetime {
            return cached.byBranch
        }
        let fetched = fetchPullRequests(in: root)
        withLock { pullRequestCache[root] = (now, fetched) }
        return fetched
    }

    private func fetchPullRequests(in root: String) -> [String: PullRequestInfo]? {
        guard let git, let gh else { return nil }
        let remote = CommandRunner.run(git, ["-C", root, "remote", "get-url", "origin"])
        guard remote.exitCode == 0, GitOutputParser.isGitHubRemote(remote.output) else { return nil }
        let arguments = ["pr", "list", "--state", "all", "--limit", "200", "--json", "number,state,headRefName,url"]
        let result = CommandRunner.run(gh, arguments, timeout: 20, in: root)
        return result.exitCode == 0 ? GitOutputParser.pullRequestsByBranch(result.output) : nil
    }

    private func withLock<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
