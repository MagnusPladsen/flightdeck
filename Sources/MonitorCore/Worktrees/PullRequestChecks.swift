import Foundation

/// The combined result of a pull request's CI checks.
public enum CheckStatus: String, Sendable, Hashable {
    case passing, failing, pending
}

/// GitHub's review decision for a pull request.
public enum ReviewState: String, Sendable, Hashable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
}

/// One entry of `statusCheckRollup`: a `CheckRun` (status and conclusion) or a `StatusContext` (state).
struct CheckRollupEntry: Decodable {
    var status: String?
    var conclusion: String?
    var state: String?
}

/// Reduces a pull request's checks to one status: any failure fails it, then anything unfinished keeps it pending.
enum CheckRollup {
    private static let failingResults: Set<String> = ["FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"]
    private static let pendingStates: Set<String> = ["PENDING", "EXPECTED"]

    static func summarize(_ entries: [CheckRollupEntry]) -> CheckStatus? {
        guard !entries.isEmpty else { return nil }
        if entries.contains(where: isFailing) { return .failing }
        if entries.contains(where: isPending) { return .pending }
        return .passing
    }

    private static func isFailing(_ entry: CheckRollupEntry) -> Bool {
        [entry.conclusion, entry.state].contains { $0.map(failingResults.contains) ?? false }
    }

    private static func isPending(_ entry: CheckRollupEntry) -> Bool {
        if let state = entry.state { return pendingStates.contains(state) }
        return entry.status != "COMPLETED"
    }
}
