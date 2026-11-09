import Foundation

/// How often gh is asked about a repository's pull requests.
///
/// Every pull request (merged and closed included, for stale detection) is listed once per
/// `historyLifetime`. Open ones are listed again with their checks and review, which is where
/// CI changes: every `activeLifetime` while the repository has open pull requests, otherwise at
/// the history pace. Both calls are GraphQL queries of a few points each against gh's
/// 5,000 points an hour, so even ten busy repositories stay well under 1% of the budget.
public enum PullRequestRefreshPolicy {
    public static let historyLifetime: TimeInterval = 600
    public static let activeLifetime: TimeInterval = 150

    public static func openLifetime(hadOpenPullRequests: Bool) -> TimeInterval {
        hadOpenPullRequests ? activeLifetime : historyLifetime
    }

    public static func isFresh(fetchedAt: Date, lifetime: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) < lifetime
    }

    /// The history with the fresher open pull requests laid over it; nil when gh answered neither.
    public static func merge(history: [String: PullRequestInfo]?, open: [String: PullRequestInfo]?) -> [String: PullRequestInfo]? {
        guard history != nil || open != nil else { return nil }
        return (history ?? [:]).merging(open ?? [:]) { _, fresh in fresh }
    }
}
