import Foundation
@testable import MonitorCore
import Testing

struct StatusReportTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func agent(_ pid: Int32, _ state: AgentState, folder: String = "/code/app", action: AgentAction? = nil) -> AgentSession {
        let project = DevProject(name: "app", rootPath: folder, branch: "main", isWorktree: false, worktreeName: nil)
        return AgentSession(tool: .claude, pid: pid, workingDirectory: folder, project: project, state: state, cpuPercent: 0, lastActivity: now.addingTimeInterval(-60), lastAction: action)
    }

    static let ports = [
        ListeningPort(port: 5173, pid: 1, processName: "node", isLocalOnly: true, framework: Framework(id: "vite", displayName: "Vite")),
        ListeningPort(port: 5000, pid: 2, processName: "ControlCenter", isLocalOnly: false),
    ]

    static let snapshot = SystemSnapshot(timestamp: now, hostName: "mac", uptime: 0, loadAverage: [], cpu: CPUUsage(total: 0.344, perCore: []),
                                         memory: MemoryUsage(totalBytes: 100, usedBytes: 61, wiredBytes: 0, compressedBytes: 0, swapUsedBytes: 0, pressure: .normal),
                                         disks: [], network: .zero, battery: nil, processes: [])

    static let usage = [ProviderUsage(tool: .claude, windows: [UsageWindow(label: "5h", usedPercent: 42.4, resetsAt: now.addingTimeInterval(3600))])]

    static func report(agents: [AgentSession], now: Date = now) -> StatusReport {
        StatusReport.collect(agents: agents, ports: ports, snapshot: snapshot, usage: usage, appVersion: "1.5.0", now: now)
    }

    @Test func countsWaitingStatesAsNeedsYou() {
        let counts = Self.report(agents: [Self.agent(1, .working), Self.agent(2, .working), Self.agent(3, .yourTurn), Self.agent(4, .needsApproval), Self.agent(5, .idle)]).counts
        #expect(counts == StatusCounts(working: 2, needsYou: 2, idle: 1, servers: 1))
    }

    @Test func listsOnlyDevServers() {
        #expect(Self.report(agents: []).servers == [StatusServer(port: 5173, project: nil, framework: "Vite")])
    }

    @Test func agentCarriesProjectBranchAndWaitingTime() {
        let waiting = Self.report(agents: [Self.agent(1, .yourTurn, action: AgentAction(verb: "Running", detail: "swift test"))]).agents[0]
        #expect(waiting.project == "app")
        #expect(waiting.branch == "main")
        #expect(waiting.state == "yourTurn")
        #expect(waiting.waitingSince == Self.now.addingTimeInterval(-60))
        #expect(waiting.lastAction == "Running swift test")
        #expect(Self.report(agents: [Self.agent(1, .working)]).agents[0].waitingSince == nil)
    }

    @Test func roundsSystemAndLimitPercentages() {
        let report = Self.report(agents: [])
        #expect(report.system == StatusSystem(cpuPercent: 34, memoryPercent: 61))
        #expect(report.limits == [StatusLimit(tool: "claude", window: "5h", usedPercent: 42, resetsAt: Self.now.addingTimeInterval(3600))])
    }

    @Test func sameContentIgnoresUpdatedAt() {
        let first = Self.report(agents: [Self.agent(1, .working)])
        #expect(first.hasSameContent(as: Self.report(agents: [Self.agent(1, .working)], now: Self.now.addingTimeInterval(5))))
        #expect(!first.hasSameContent(as: Self.report(agents: [Self.agent(1, .yourTurn)])))
    }

    @Test func jsonRoundTripsWithSchemaVersion() throws {
        let report = Self.report(agents: [Self.agent(1, .needsApproval)])
        let data = try StatusFile.encode(report)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == StatusReport.schemaVersion)
        #expect(json["updatedAt"] as? String == "2027-01-15T08:00:00Z")
        #expect(try StatusFile.decode(data) == report)
    }
}
