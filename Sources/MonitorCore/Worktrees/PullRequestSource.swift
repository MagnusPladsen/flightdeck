import Foundation

/// Asks gh for a repository's pull requests on the cadence `PullRequestRefreshPolicy` sets.
/// Blocks on git and gh, so call it off the main thread.
final class PullRequestSource: @unchecked Sendable {
    private static let historyFields = "number,state,headRefName,url,isCrossRepository"
    private static let openFields = "number,state,headRefName,url,isCrossRepository,isDraft,reviewDecision,statusCheckRollup"

    private struct Cached {
        var fetchedAt: Date
        /// Nil when gh can't answer for the repository.
        var byBranch: [String: PullRequestInfo]?
    }

    private let git: String?
    private let gh: String?
    private let lock = NSLock()
    private var history: [String: Cached] = [:]
    private var open: [String: Cached] = [:]

    init(git: String?, gh: String?) {
        self.git = git
        self.gh = gh
    }

    func pullRequestsByBranch(in root: String, now: Date) -> [String: PullRequestInfo]? {
        let history = cachedHistory(in: root, now: now)
        return PullRequestRefreshPolicy.merge(history: history, open: cachedOpen(in: root, now: now))
    }

    private func cachedHistory(in root: String, now: Date) -> [String: PullRequestInfo]? {
        if let cached = withLock({ history[root] }), PullRequestRefreshPolicy.isFresh(fetchedAt: cached.fetchedAt, lifetime: PullRequestRefreshPolicy.historyLifetime, now: now) {
            return cached.byBranch
        }
        let fetched = fetch(in: root, arguments: ["--state", "all", "--limit", "200", "--json", Self.historyFields])
        withLock { history[root] = Cached(fetchedAt: now, byBranch: fetched) }
        return fetched
    }

    private func cachedOpen(in root: String, now: Date) -> [String: PullRequestInfo]? {
        if let cached = withLock({ open[root] }), PullRequestRefreshPolicy.isFresh(fetchedAt: cached.fetchedAt, lifetime: openLifetime(of: cached), now: now) {
            return cached.byBranch
        }
        let fetched = fetch(in: root, arguments: ["--state", "open", "--limit", "50", "--json", Self.openFields])
        withLock { open[root] = Cached(fetchedAt: now, byBranch: fetched) }
        return fetched
    }

    private func openLifetime(of cached: Cached) -> TimeInterval {
        PullRequestRefreshPolicy.openLifetime(hadOpenPullRequests: !(cached.byBranch?.isEmpty ?? true))
    }

    private func fetch(in root: String, arguments: [String]) -> [String: PullRequestInfo]? {
        guard let git, let gh else { return nil }
        let remote = CommandRunner.run(git, ["-C", root, "remote", "get-url", "origin"])
        guard remote.exitCode == 0, GitOutputParser.isGitHubRemote(remote.output) else { return nil }
        let result = CommandRunner.run(gh, ["pr", "list"] + arguments, timeout: 20, in: root)
        return result.exitCode == 0 ? GitOutputParser.pullRequestsByBranch(result.output) : nil
    }

    private func withLock<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
