import Foundation

/// One entry of `git worktree list --porcelain`.
public struct WorktreeListEntry: Sendable, Hashable {
    public var path: String
    public var head: String?
    /// Short branch name, nil when HEAD is detached.
    public var branch: String?
    public var isBare: Bool
    public var isLocked: Bool
    /// Git lists a worktree as prunable when its folder is gone.
    public var isPrunable: Bool

    public init(path: String, head: String? = nil, branch: String? = nil, isBare: Bool = false, isLocked: Bool = false, isPrunable: Bool = false) {
        self.path = path
        self.head = head
        self.branch = branch
        self.isBare = isBare
        self.isLocked = isLocked
        self.isPrunable = isPrunable
    }
}

/// What `git status --porcelain=v2 --branch` says about a checkout.
public struct GitStatusSummary: Sendable, Hashable {
    public var upstream: String?
    public var ahead: Int
    public var behind: Int
    /// Modified, staged, conflicted and untracked files. Ignored files don't count.
    public var changedFileCount: Int

    public var isDirty: Bool { changedFileCount > 0 }

    public init(upstream: String? = nil, ahead: Int = 0, behind: Int = 0, changedFileCount: Int = 0) {
        self.upstream = upstream
        self.ahead = ahead
        self.behind = behind
        self.changedFileCount = changedFileCount
    }
}

public enum PullRequestState: String, Sendable, Hashable, Decodable {
    case open = "OPEN", merged = "MERGED", closed = "CLOSED"
}

public struct PullRequestInfo: Sendable, Hashable {
    public var number: Int
    public var state: PullRequestState
    public var url: String

    public init(number: Int, state: PullRequestState, url: String) {
        self.number = number
        self.state = state
        self.url = url
    }
}

/// The pull request for a worktree's branch, as far as `gh` can tell.
public enum PullRequestLookup: Sendable, Hashable {
    /// `gh` is not installed, not signed in, or the remote is not on GitHub.
    case unavailable
    case none
    case found(PullRequestInfo)

    public var pullRequest: PullRequestInfo? {
        if case .found(let info) = self { return info }
        return nil
    }
}

/// A git worktree with what the overview shows about it.
public struct Worktree: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public var repositoryName: String
    /// Path of the repository's main worktree, where `git worktree remove` runs.
    public var repositoryRoot: String
    public var path: String
    public var branch: String?
    public var head: String?
    /// The repository's own checkout, which can never be removed.
    public var isMain: Bool
    public var isLocked: Bool
    public var status: GitStatusSummary
    public var lastCommitDate: Date?
    public var pullRequest: PullRequestLookup

    public init(repositoryName: String, repositoryRoot: String, path: String, branch: String?, head: String? = nil, isMain: Bool, isLocked: Bool = false,
                status: GitStatusSummary, lastCommitDate: Date?, pullRequest: PullRequestLookup) {
        self.repositoryName = repositoryName
        self.repositoryRoot = repositoryRoot
        self.path = path
        self.branch = branch
        self.head = head
        self.isMain = isMain
        self.isLocked = isLocked
        self.status = status
        self.lastCommitDate = lastCommitDate
        self.pullRequest = pullRequest
    }

    /// Folder name of the checkout, e.g. `jolly-joliot-236480`.
    public var folderName: String {
        (path as NSString).lastPathComponent
    }
}
