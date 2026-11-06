@testable import MonitorCore
import Testing

struct ProcessTreeUsageTests {
    private func sample(_ pid: Int32, parent: Int32, cpu: Double, megabytes: UInt64) -> ProcessSample {
        ProcessSample(pid: pid, parentPID: parent, name: "p\(pid)", cpuPercent: cpu, memoryBytes: megabytes * 1_048_576)
    }

    @Test func sumsTheAgentAndAllItsDescendants() {
        let samples = [
            sample(10, parent: 1, cpu: 4, megabytes: 300),
            sample(11, parent: 10, cpu: 0, megabytes: 5),
            sample(12, parent: 11, cpu: 180, megabytes: 900),
            sample(13, parent: 12, cpu: 20, megabytes: 100),
            sample(20, parent: 1, cpu: 99, megabytes: 999),
        ]
        let usage = ProcessTreeUsage.of(pid: 10, childrenByParent: Dictionary(grouping: samples, by: \.parentPID), samplesByPID: Dictionary(uniqueKeysWithValues: samples.map { ($0.pid, $0) }))
        #expect(usage == ProcessTreeUsage(cpuPercent: 204, memoryBytes: 1305 * 1_048_576, processCount: 4))
    }

    @Test func survivesAParentLoop() {
        let samples = [sample(10, parent: 11, cpu: 1, megabytes: 1), sample(11, parent: 10, cpu: 1, megabytes: 1)]
        let usage = ProcessTreeUsage.of(pid: 10, childrenByParent: Dictionary(grouping: samples, by: \.parentPID), samplesByPID: Dictionary(uniqueKeysWithValues: samples.map { ($0.pid, $0) }))
        #expect(usage.processCount == 2)
    }
}
