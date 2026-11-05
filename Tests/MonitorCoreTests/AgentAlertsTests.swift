import MonitorCore
import Testing

struct AgentAlertsTests {
    private func agent(_ pid: Int32, _ state: AgentState, tool: AgentTool = .claude, folder: String = "/code/app") -> AgentSession {
        AgentSession(tool: tool, pid: pid, workingDirectory: folder, project: nil, state: state, cpuPercent: 0, lastActivity: nil)
    }

    private let allStates = AgentAlerts.waitingStates
    private let allTools = Set(AgentTool.allCases)

    @Test func firstPollNeverAlerts() {
        let alerts = AgentAlerts.newlyWaiting(previous: nil, current: [agent(1, .needsApproval)], states: allStates, tools: allTools)
        #expect(alerts.isEmpty)
    }

    @Test func alertsOnlyWhenTheStateChanges() {
        let previous = [agent(1, .working), agent(2, .yourTurn, folder: "/code/other")]
        let current = [agent(1, .needsApproval), agent(2, .yourTurn, folder: "/code/other")]
        let alerts = AgentAlerts.newlyWaiting(previous: previous, current: current, states: allStates, tools: allTools)
        #expect(alerts.map(\.pid) == [1])
    }

    @Test func respectsChosenStatesAndTools() {
        let previous = [agent(1, .working), agent(2, .working, tool: .codex, folder: "/code/other")]
        let current = [agent(1, .yourTurn), agent(2, .needsApproval, tool: .codex, folder: "/code/other")]
        #expect(AgentAlerts.newlyWaiting(previous: previous, current: current, states: [.needsApproval], tools: allTools).map(\.pid) == [2])
        #expect(AgentAlerts.newlyWaiting(previous: previous, current: current, states: allStates, tools: [.claude]).map(\.pid) == [1])
    }

    @Test func alertsOncePerFolder() {
        let previous = [agent(1, .working), agent(2, .working)]
        let current = [agent(1, .yourTurn), agent(2, .yourTurn)]
        #expect(AgentAlerts.newlyWaiting(previous: previous, current: current, states: allStates, tools: allTools).count == 1)
    }

    @Test func reportsFoldersThatStoppedWaiting() {
        let previous = [agent(1, .needsApproval), agent(2, .yourTurn, folder: "/code/other")]
        let current = [agent(1, .working), agent(2, .yourTurn, folder: "/code/other")]
        #expect(AgentAlerts.stoppedWaiting(previous: previous, current: current) == ["/code/app"])
    }
}
