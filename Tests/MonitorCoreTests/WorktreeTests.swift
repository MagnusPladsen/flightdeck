import Foundation
import Testing
@testable import MonitorCore

struct GitOutputParserTests {
    @Test func worktreeListParsesBranchesDetachedLockedAndPrunable() {
        let output = """
        worktree /Users/alex/git/shop
        HEAD 1111111111111111111111111111111111111111
        branch refs/heads/main

        worktree /Users/alex/git/shop/.claude/worktrees/jolly
        HEAD 2222222222222222222222222222222222222222
        branch refs/heads/claude/jolly

        worktree /Users/alex/git/shop-worktrees/hotfix
        HEAD 3333333333333333333333333333333333333333
        detached
        locked reason: on a USB drive

        worktree /Users/alex/git/shop-worktrees/gone
        HEAD 4444444444444444444444444444444444444444
        branch refs/heads/old
        prunable gitdir file points to non-existent location

        """
        let entries = GitOutputParser.worktreeList(output)
        #expect(entries.map(\.path) == ["/Users/alex/git/shop", "/Users/alex/git/shop/.claude/worktrees/jolly", "/Users/alex/git/shop-worktrees/hotfix", "/Users/alex/git/shop-worktrees/gone"])
        #expect(entries.map(\.branch) == ["main", "claude/jolly", nil, "old"])
        #expect(entries[2].isLocked && !entries[2].isPrunable)
        #expect(entries[3].isPrunable && !entries[3].isLocked)
        #expect(entries[0].head == "1111111111111111111111111111111111111111")
    }

    @Test func worktreeListMarksBareRepository() {
        let entries = GitOutputParser.worktreeList("worktree /srv/shop.git\nbare\n\nworktree /srv/shop-main\nHEAD abc\nbranch refs/heads/main\n")
        #expect(entries.map(\.isBare) == [true, false])
    }

    @Test func statusReadsUpstreamAheadBehindAndCountsChanges() {
        let output = """
        # branch.oid 1111111111111111111111111111111111111111
        # branch.head feature/search
        # branch.upstream origin/feature/search
        # branch.ab +3 -1
        1 .M N... 100644 100644 100644 aaa bbb Sources/App.swift
        2 R. N... 100644 100644 100644 aaa bbb R100 New.swift\tOld.swift
        u UU N... 100644 100644 100644 100644 aaa bbb ccc Conflict.swift
        ? notes.txt
        ! .build/
        """
        #expect(GitOutputParser.status(output) == GitStatusSummary(upstream: "origin/feature/search", ahead: 3, behind: 1, changedFileCount: 4))
    }

    @Test func statusOfCleanBranchWithoutUpstream() {
        let status = GitOutputParser.status("# branch.oid abc\n# branch.head scratch\n")
        #expect(status == GitStatusSummary())
        #expect(!status.isDirty)
    }

    @Test func commitDateFromUnixSeconds() {
        #expect(GitOutputParser.commitDate("1700000000\n") == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(GitOutputParser.commitDate("") == nil)
    }

    @Test func pullRequestsKeepNewestPerBranch() {
        let json = """
        [{"number":12,"state":"OPEN","headRefName":"feat/search","url":"https://github.com/a/b/pull/12"},
         {"number":9,"state":"MERGED","headRefName":"fix/login","url":"https://github.com/a/b/pull/9"},
         {"number":4,"state":"CLOSED","headRefName":"feat/search","url":"https://github.com/a/b/pull/4"}]
        """
        let byBranch = GitOutputParser.pullRequestsByBranch(json)
        #expect(byBranch?["feat/search"] == PullRequestInfo(number: 12, state: .open, url: "https://github.com/a/b/pull/12"))
        #expect(byBranch?["fix/login"]?.state == .merged)
        #expect(GitOutputParser.pullRequestsByBranch("not json") == nil)
    }

    @Test func gitHubRemotesInBothForms() {
        #expect(GitOutputParser.isGitHubRemote("git@github.com:MagnusPladsen/flightdeck.git\n"))
        #expect(GitOutputParser.isGitHubRemote("https://github.com/MagnusPladsen/flightdeck"))
        #expect(!GitOutputParser.isGitHubRemote("https://dev.azure.com/org/project/_git/repo"))
    }
}

struct StaleWorktreePolicyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let policy = StaleWorktreePolicy(minimumAgeDays: 14)

    func worktree(daysOld: Double = 30, changedFiles: Int = 0, pullRequest: PullRequestLookup = .none, isMain: Bool = false, isLocked: Bool = false) -> Worktree {
        Worktree(repositoryName: "shop", repositoryRoot: "/r/shop", path: isMain ? "/r/shop" : "/r/shop/.claude/worktrees/x", branch: "x", isMain: isMain, isLocked: isLocked,
                 status: GitStatusSummary(changedFileCount: changedFiles), lastCommitDate: now.addingTimeInterval(-daysOld * 86_400), pullRequest: pullRequest)
    }

    @Test func oldCleanWorktreeWithoutPullRequestIsStale() {
        #expect(policy.isStale(worktree(), hasAgent: false, now: now))
        #expect(policy.isStale(worktree(pullRequest: .unavailable), hasAgent: false, now: now))
    }

    @Test func mergedPullRequestIsStaleButOpenAndClosedAreNot() {
        let merged = PullRequestInfo(number: 1, state: .merged, url: "")
        #expect(policy.isStale(worktree(pullRequest: .found(merged)), hasAgent: false, now: now))
        for state in [PullRequestState.open, .closed] {
            #expect(!policy.isStale(worktree(pullRequest: .found(PullRequestInfo(number: 1, state: state, url: ""))), hasAgent: false, now: now))
        }
    }

    @Test func dirtyRecentMainLockedOrBusyWorktreesAreNeverStale() {
        #expect(!policy.isStale(worktree(changedFiles: 1), hasAgent: false, now: now))
        #expect(!policy.isStale(worktree(daysOld: 13), hasAgent: false, now: now))
        #expect(!policy.isStale(worktree(isMain: true), hasAgent: false, now: now))
        #expect(!policy.isStale(worktree(isLocked: true), hasAgent: false, now: now))
        #expect(!policy.isStale(worktree(), hasAgent: true, now: now))
    }
}

struct WorktreeAgentMatcherTests {
    func worktree(_ path: String, isMain: Bool = false) -> Worktree {
        Worktree(repositoryName: "shop", repositoryRoot: "/r/shop", path: path, branch: nil, isMain: isMain, status: GitStatusSummary(), lastCommitDate: nil, pullRequest: .none)
    }

    func agent(_ pid: Int32, in folder: String) -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: folder, project: nil, state: .working, cpuPercent: 0, lastActivity: nil)
    }

    @Test func agentBelongsToDeepestWorktree() {
        let worktrees = [worktree("/r/shop", isMain: true), worktree("/r/shop/.claude/worktrees/jolly"), worktree("/r/shop-search")]
        let agents = [agent(1, in: "/r/shop/apps/web"), agent(2, in: "/r/shop/.claude/worktrees/jolly"), agent(3, in: "/r/shop-search/src"), agent(4, in: "/r/other")]
        let matched = WorktreeAgentMatcher.agents(in: worktrees, from: agents).mapValues { $0.map(\.pid) }
        #expect(matched == ["/r/shop": [1], "/r/shop/.claude/worktrees/jolly": [2], "/r/shop-search": [3]])
    }
}

/// Runs real git in a throwaway repository under the temp folder.
struct WorktreeCollectorTests {
    let root: String
    let git = CommandRunner.locate("git")

    init() throws {
        let base = NSTemporaryDirectory() + "worktrees-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: base + "/shop", withIntermediateDirectories: true)
        // Git reports real paths, and the temp folder sits behind the /var -> /private/var link.
        root = try #require(realpath(base, nil).map { String(cString: $0) }) + "/shop"
        try run("init", "-q", "-b", "main")
        try "hello".write(toFile: root + "/README.md", atomically: true, encoding: .utf8)
        try run("add", "README.md")
        try run("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "First")
        try run("worktree", "add", "-q", "-b", "clean-branch", root + "-clean")
        try run("worktree", "add", "-q", "-b", "dirty-branch", root + "-dirty")
        try "draft".write(toFile: root + "-dirty/draft.txt", atomically: true, encoding: .utf8)
    }

    private func run(_ arguments: String...) throws {
        let result = CommandRunner.run(try #require(git), ["-C", root] + arguments)
        try #require(result.exitCode == 0)
    }

    @Test func collectsEveryWorktreeFromAnyFolderInside() throws {
        let collector = WorktreeCollector(git: git, gh: nil)
        let worktrees = collector.collect(repositoriesContaining: [root + "-clean", root])
        #expect(worktrees.map(\.path) == [root, root + "-clean", root + "-dirty"])
        #expect(worktrees.map(\.branch) == ["main", "clean-branch", "dirty-branch"])
        #expect(worktrees.map(\.isMain) == [true, false, false])
        #expect(worktrees.map(\.status.isDirty) == [false, false, true])
        #expect(worktrees.allSatisfy { $0.pullRequest == .unavailable && $0.lastCommitDate != nil })
    }

    @Test func removesCleanWorktreeButNeverDirtyOrMain() throws {
        let collector = WorktreeCollector(git: git, gh: nil)
        let worktrees = collector.collect(repositoriesContaining: [root])
        #expect(collector.remove(try #require(worktrees.first { $0.path == root + "-dirty" })) == .skippedDirty)
        #expect(collector.remove(try #require(worktrees.first { $0.isMain })) == .failed)
        #expect(collector.remove(try #require(worktrees.first { $0.path == root + "-clean" })) == .removed)
        #expect(!FileManager.default.fileExists(atPath: root + "-clean"))
        #expect(FileManager.default.fileExists(atPath: root + "-dirty/draft.txt"))
    }
}
