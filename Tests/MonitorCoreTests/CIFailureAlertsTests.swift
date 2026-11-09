import Foundation
import Testing
@testable import MonitorCore

struct CIFailureAlertsTests {
    let path = "/r/shop/.claude/worktrees/search"
    let agent = AgentSession(tool: .claude, pid: 7, workingDirectory: "/r/shop/.claude/worktrees/search", project: nil, state: .working, cpuPercent: 10, lastActivity: nil)

    func worktree(_ lookup: PullRequestLookup) -> Worktree {
        Worktree(repositoryName: "shop", repositoryRoot: "/r/shop", path: path, branch: "feat/search", isMain: false,
                 status: GitStatusSummary(), lastCommitDate: nil, pullRequest: lookup)
    }

    func checks(_ status: CheckStatus?, state: PullRequestState = .open) -> PullRequestLookup {
        .found(PullRequestInfo(number: 3, state: state, url: "u", checks: status))
    }

    func alerts(from before: PullRequestLookup?, to after: PullRequestLookup, hasAgent: Bool = true) -> [CIFailureAlert] {
        CIFailureAlerts.newlyFailing(previous: before.map { [worktree($0)] }, current: [worktree(after)], agents: hasAgent ? [path: [agent]] : [:])
    }

    @Test func passingOrPendingTurningFailingAlerts() {
        #expect(alerts(from: checks(.passing), to: checks(.failing)).map(\.branch) == ["feat/search"])
        #expect(alerts(from: checks(.pending), to: checks(.failing)).first?.agent == agent)
        #expect(alerts(from: checks(nil), to: checks(.failing)).count == 1)
        #expect(alerts(from: PullRequestLookup.none, to: checks(.failing)).count == 1)
    }

    @Test func stillFailingOrUnknownBeforeDoesNotAlert() {
        #expect(alerts(from: checks(.failing), to: checks(.failing)).isEmpty)
        #expect(alerts(from: .unavailable, to: checks(.failing)).isEmpty)
        #expect(alerts(from: nil, to: checks(.failing)).isEmpty)
    }

    @Test func needsAnAgentAndAnOpenPullRequest() {
        #expect(alerts(from: checks(.passing), to: checks(.failing), hasAgent: false).isEmpty)
        #expect(alerts(from: checks(.passing), to: checks(.failing, state: .closed)).isEmpty)
        #expect(alerts(from: checks(.passing), to: checks(.pending)).isEmpty)
    }

    @Test func quietHoursHoldThenSummarizeOnlyStillFailing() {
        var batcher = CIFailureBatcher()
        let alert = alerts(from: checks(.passing), to: checks(.failing))
        #expect(batcher.deliver(alert, current: [worktree(checks(.failing))], isQuiet: true, handling: .summarize) == .none)
        #expect(batcher.held.count == 1)
        let delivery = batcher.deliver([], current: [worktree(checks(.failing))], isQuiet: false, handling: .summarize)
        #expect(delivery.summary.map(\.branch) == ["feat/search"])
        _ = batcher.deliver(alert, current: [], isQuiet: true, handling: .summarize)
        #expect(batcher.deliver([], current: [worktree(checks(.passing))], isQuiet: false, handling: .summarize) == .none)
    }

    @Test func dropDuringQuietDiscards() {
        var batcher = CIFailureBatcher()
        let alert = alerts(from: checks(.passing), to: checks(.failing))
        _ = batcher.deliver(alert, current: [], isQuiet: true, handling: .drop)
        #expect(batcher.held.isEmpty)
        #expect(batcher.deliver(alert, current: [], isQuiet: false, handling: .drop).individual == alert)
    }
}
