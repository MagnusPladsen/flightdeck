import Testing
@testable import MonitorCore

struct ResourceBreakdownTests {
    private func process(_ pid: Int32, _ name: String, cpu: Double, megabytes: UInt64) -> ProcessSample {
        ProcessSample(pid: pid, parentPID: 1, name: name, cpuPercent: cpu, memoryBytes: megabytes << 20)
    }

    @Test func groupsHelpersUnderTheirApp() {
        #expect(ResourceBreakdown.appName(of: "Google Chrome Helper (Renderer)") == "Google Chrome")
        #expect(ResourceBreakdown.appName(of: "Code Helper (GPU)") == "Code")
        #expect(ResourceBreakdown.appName(of: "WindowServer") == "WindowServer")
    }

    @Test func ranksAppsByTheirSummedUse() {
        let processes = [
            process(1, "Google Chrome", cpu: 5, megabytes: 300),
            process(2, "Google Chrome Helper (Renderer)", cpu: 30, megabytes: 900),
            process(3, "node", cpu: 50, megabytes: 200),
            process(4, "idle", cpu: 0, megabytes: 10),
        ]
        let byCPU = ResourceBreakdown.consumers(of: processes, by: .cpu, limit: 5)
        #expect(byCPU.map(\.name) == ["node", "Google Chrome"])
        #expect(byCPU[1].processCount == 2)
        #expect(byCPU[1].cpuPercent == 35)
        let byMemory = ResourceBreakdown.consumers(of: processes, by: .memory, limit: 1)
        #expect(byMemory.map(\.name) == ["Google Chrome"])
        #expect(byMemory[0].memoryBytes == 1200 << 20)
    }
}
