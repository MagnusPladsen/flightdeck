import Foundation
import Testing
@testable import MonitorCore

/// Trimmed `gh pr list --state open --json number,state,headRefName,url,isDraft,reviewDecision,statusCheckRollup` output.
private let openPullRequestsFixture = """
[{"headRefName":"feat/search","isDraft":false,"number":21,"reviewDecision":"APPROVED","state":"OPEN","url":"https://github.com/a/b/pull/21",
  "statusCheckRollup":[
    {"__typename":"CheckRun","completedAt":"2026-11-09T09:34:56Z","conclusion":"SUCCESS","name":"build","status":"COMPLETED","workflowName":"app"},
    {"__typename":"CheckRun","completedAt":"2026-11-09T09:09:28Z","conclusion":"SKIPPED","name":"deploy","status":"COMPLETED","workflowName":"app"},
    {"__typename":"StatusContext","context":"ci/circleci","state":"SUCCESS","targetUrl":"https://circleci.com/x"}]},
 {"headRefName":"fix/login","isDraft":true,"number":20,"reviewDecision":"CHANGES_REQUESTED","state":"OPEN","url":"https://github.com/a/b/pull/20",
  "statusCheckRollup":[
    {"__typename":"CheckRun","completedAt":"2026-11-08T18:06:37Z","conclusion":"FAILURE","name":"build","status":"COMPLETED","workflowName":"app"},
    {"__typename":"CheckRun","completedAt":null,"conclusion":"","name":"lint","status":"IN_PROGRESS","workflowName":"lint"}]},
 {"headRefName":"feat/export","isDraft":false,"number":19,"reviewDecision":"REVIEW_REQUIRED","state":"OPEN","url":"https://github.com/a/b/pull/19",
  "statusCheckRollup":[
    {"__typename":"CheckRun","completedAt":"2026-11-08T18:06:37Z","conclusion":"SUCCESS","name":"build","status":"COMPLETED","workflowName":"app"},
    {"__typename":"CheckRun","completedAt":null,"conclusion":"","name":"e2e","status":"QUEUED","workflowName":"e2e"}]},
 {"headRefName":"chore/deps","isDraft":false,"number":18,"reviewDecision":"","state":"OPEN","url":"https://github.com/a/b/pull/18","statusCheckRollup":[]},
 {"headRefName":"fix/status","isDraft":false,"number":17,"reviewDecision":"","state":"OPEN","url":"https://github.com/a/b/pull/17",
  "statusCheckRollup":[{"__typename":"StatusContext","context":"ci/jenkins","state":"ERROR","targetUrl":"https://jenkins/x"}]}]
"""

struct PullRequestChecksTests {
    let byBranch = GitOutputParser.pullRequestsByBranch(openPullRequestsFixture) ?? [:]

    @Test func readsChecksReviewAndDraft() {
        #expect(byBranch["feat/search"] == PullRequestInfo(number: 21, state: .open, url: "https://github.com/a/b/pull/21", checks: .passing, review: .approved))
        #expect(byBranch["fix/login"]?.isDraft == true)
        #expect(byBranch["fix/login"]?.review == .changesRequested)
        #expect(byBranch["feat/export"]?.review == .reviewRequired)
    }

    @Test func failureBeatsPendingAndPendingBeatsPassing() {
        #expect(byBranch["fix/login"]?.checks == .failing)
        #expect(byBranch["feat/export"]?.checks == .pending)
        #expect(byBranch["fix/status"]?.checks == .failing)
    }

    @Test func noChecksAndEmptyReviewDecisionAreNil() {
        #expect(byBranch["chore/deps"]?.checks == nil)
        #expect(byBranch["chore/deps"]?.review == nil)
    }

    @Test func historyWithoutCheckFieldsStillParses() {
        let history = GitOutputParser.pullRequestsByBranch(#"[{"number":4,"state":"MERGED","headRefName":"old","url":"u"}]"#)
        #expect(history?["old"] == PullRequestInfo(number: 4, state: .merged, url: "u"))
    }

    @Test func pendingStatusContextsAndUnfinishedRunsArePending() {
        #expect(CheckRollup.summarize([CheckRollupEntry(state: "PENDING")]) == .pending)
        #expect(CheckRollup.summarize([CheckRollupEntry(status: "WAITING", conclusion: "")]) == .pending)
        #expect(CheckRollup.summarize([CheckRollupEntry(status: "COMPLETED", conclusion: "NEUTRAL")]) == .passing)
        #expect(CheckRollup.summarize([CheckRollupEntry(status: "COMPLETED", conclusion: "TIMED_OUT")]) == .failing)
        #expect(CheckRollup.summarize([]) == nil)
    }
}

struct PullRequestRefreshPolicyTests {
    @Test func openPullRequestsRefreshFasterThanHistory() {
        #expect(PullRequestRefreshPolicy.openLifetime(hadOpenPullRequests: true) == 150)
        #expect(PullRequestRefreshPolicy.openLifetime(hadOpenPullRequests: false) == PullRequestRefreshPolicy.historyLifetime)
        let fetched = Date(timeIntervalSince1970: 0)
        #expect(PullRequestRefreshPolicy.isFresh(fetchedAt: fetched, lifetime: 150, now: fetched.addingTimeInterval(149)))
        #expect(!PullRequestRefreshPolicy.isFresh(fetchedAt: fetched, lifetime: 150, now: fetched.addingTimeInterval(150)))
    }

    @Test func openPullRequestsOverrideHistory() {
        let stale = PullRequestInfo(number: 5, state: .open, url: "u")
        let fresh = PullRequestInfo(number: 5, state: .open, url: "u", checks: .failing)
        let merged = PullRequestInfo(number: 2, state: .merged, url: "m")
        let combined = PullRequestRefreshPolicy.merge(history: ["a": stale, "b": merged], open: ["a": fresh])
        #expect(combined == ["a": fresh, "b": merged])
        #expect(PullRequestRefreshPolicy.merge(history: nil, open: ["a": fresh]) == ["a": fresh])
        #expect(PullRequestRefreshPolicy.merge(history: nil, open: nil) == nil)
    }
}
