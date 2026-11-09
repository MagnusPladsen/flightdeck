import Foundation

/// An open pull request whose checks just started failing on a branch an agent works in.
public struct CIFailureAlert: Sendable, Hashable {
    public var worktree: Worktree
    public var pullRequest: PullRequestInfo
    public var agent: AgentSession

    public init(worktree: Worktree, pullRequest: PullRequestInfo, agent: AgentSession) {
        self.worktree = worktree
        self.pullRequest = pullRequest
        self.agent = agent
    }

    public var branch: String { worktree.branch ?? worktree.folderName }
}

/// Decides which worktrees deserve a "CI failing" alert.
public enum CIFailureAlerts {
    /// Worktrees whose open pull request fails now but didn't on the previous refresh.
    /// With no previous refresh, or when gh couldn't answer before, nothing counts as new,
    /// so starting the app or gh coming back doesn't alert on old failures.
    public static func newlyFailing(previous: [Worktree]?, current: [Worktree], agents: [String: [AgentSession]]) -> [CIFailureAlert] {
        guard let previous else { return [] }
        let before = Dictionary(previous.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        return current.compactMap { worktree in
            guard let pullRequest = failingOpenPullRequest(worktree), let agent = agents[worktree.path]?.first,
                  let earlier = before[worktree.path], wasPassingOrUnknown(earlier) else { return nil }
            return CIFailureAlert(worktree: worktree, pullRequest: pullRequest, agent: agent)
        }
    }

    public static func failingOpenPullRequest(_ worktree: Worktree) -> PullRequestInfo? {
        guard let pullRequest = worktree.pullRequest.pullRequest, pullRequest.state == .open, pullRequest.checks == .failing else { return nil }
        return pullRequest
    }

    private static func wasPassingOrUnknown(_ worktree: Worktree) -> Bool {
        switch worktree.pullRequest {
        case .unavailable: false
        case .none: true
        case .found(let pullRequest): pullRequest.checks != .failing
        }
    }
}

/// CI alerts to post on one refresh: each on its own, and those held through a quiet period, as one summary.
public struct CIFailureDelivery: Sendable, Hashable {
    public var individual: [CIFailureAlert]
    public var summary: [CIFailureAlert]

    public static let none = CIFailureDelivery(individual: [], summary: [])
}

/// Holds CI alerts back while it's quiet, like `AlertBatcher` does for agents, and releases
/// those whose branch still fails once it isn't.
public struct CIFailureBatcher: Sendable {
    public private(set) var held: [CIFailureAlert] = []

    public init() {}

    public mutating func deliver(_ newAlerts: [CIFailureAlert], current: [Worktree], isQuiet: Bool, handling: QuietAlertHandling) -> CIFailureDelivery {
        if isQuiet {
            handling == .summarize ? hold(newAlerts) : discard()
            return .none
        }
        let summary = flush(stillFailing: current)
        let summarized = Set(summary.map(\.worktree.path))
        return CIFailureDelivery(individual: newAlerts.filter { !summarized.contains($0.worktree.path) }, summary: summary)
    }

    public mutating func discard() {
        held = []
    }

    private mutating func hold(_ alerts: [CIFailureAlert]) {
        let paths = Set(alerts.map(\.worktree.path))
        held = held.filter { !paths.contains($0.worktree.path) } + alerts
    }

    private mutating func flush(stillFailing current: [Worktree]) -> [CIFailureAlert] {
        let failingPaths = Set(current.filter { CIFailureAlerts.failingOpenPullRequest($0) != nil }.map(\.path))
        defer { held = [] }
        return held.filter { failingPaths.contains($0.worktree.path) }
    }
}
