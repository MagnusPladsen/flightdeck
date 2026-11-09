import MonitorCore
import Testing

struct KeepAwakeTests {
    private func agent(_ pid: Int32, _ state: AgentState) -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: "/a", project: nil, state: state, cpuPercent: 0, lastActivity: nil)
    }

    @Test func holdsWhileAnAgentWorksOrMayBeStuck() {
        #expect(KeepAwake.shouldHoldAssertion(isEnabled: true, agents: [agent(1, .idle), agent(2, .working)]))
        #expect(KeepAwake.shouldHoldAssertion(isEnabled: true, agents: [agent(1, .possiblyStuck)]))
    }

    @Test func releasesWhenNobodyWorksOrTheSettingIsOff() {
        #expect(!KeepAwake.shouldHoldAssertion(isEnabled: true, agents: [agent(1, .yourTurn), agent(2, .needsApproval), agent(3, .idle)]))
        #expect(!KeepAwake.shouldHoldAssertion(isEnabled: true, agents: []))
        #expect(!KeepAwake.shouldHoldAssertion(isEnabled: false, agents: [agent(1, .working)]))
    }

    @Test func statusTextCountsBusyAgents() {
        #expect(KeepAwake.busyCount(in: [agent(1, .working), agent(2, .possiblyStuck), agent(3, .yourTurn)]) == 2)
        #expect(KeepAwake.statusText(isEnabled: true, busyCount: 2) == "Keeping awake · 2 working")
        #expect(KeepAwake.statusText(isEnabled: true, busyCount: 0) == "Keep awake · idle")
        #expect(KeepAwake.statusText(isEnabled: false, busyCount: 3) == "Keep awake")
    }
}
