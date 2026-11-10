import Foundation
import Testing
@testable import MonitorCore

struct CheckoutClashTests {
    private func agent(_ pid: Int32, in folder: String, state: AgentState = .working) -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: folder, project: nil, state: state, cpuPercent: 0, lastActivity: nil)
    }

    private func changes(in root: String, _ paths: [String]) -> AgentChanges {
        AgentChanges(baseline: ChangeBaseline(repositoryRoot: root, commit: "abc"), files: paths.map { FileChange(path: $0, added: 1, removed: 0) })
    }

    @Test func flagsAgentsInTheSameCheckout() {
        let clashes = CheckoutClashFinder.clashes(among: [agent(1, in: "/repo"), agent(2, in: "/repo/Sources")],
                                                  changes: [1: changes(in: "/repo", ["a.swift", "b.swift"]), 2: changes(in: "/repo", ["b.swift"])])
        #expect(clashes[1]?.otherPIDs == [2])
        #expect(clashes[1]?.sharedFiles == ["b.swift"])
        #expect(clashes[2]?.sharedFiles == ["b.swift"])
    }

    @Test func leavesSeparateWorktreesAlone() {
        let clashes = CheckoutClashFinder.clashes(among: [agent(1, in: "/repo"), agent(2, in: "/repo-worktrees/feature")],
                                                  changes: [1: changes(in: "/repo", ["a.swift"]), 2: changes(in: "/repo-worktrees/feature", ["a.swift"])])
        #expect(clashes.isEmpty)
    }

    @Test func ignoresIdleAgents() {
        let clashes = CheckoutClashFinder.clashes(among: [agent(1, in: "/repo"), agent(2, in: "/repo", state: .idle)], changes: [:])
        #expect(clashes.isEmpty)
    }
}
