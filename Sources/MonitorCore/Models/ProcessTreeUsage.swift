import Foundation

/// Resource use summed over a process and every process below it.
public struct ProcessTreeUsage: Sendable, Hashable {
    /// Percent of one core, so a busy tree can exceed 100.
    public var cpuPercent: Double
    public var memoryBytes: UInt64
    public var processCount: Int

    public init(cpuPercent: Double, memoryBytes: UInt64, processCount: Int) {
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.processCount = processCount
    }

    public static func of(pid: Int32, childrenByParent: [Int32: [ProcessSample]], samplesByPID: [Int32: ProcessSample]) -> ProcessTreeUsage {
        var usage = ProcessTreeUsage(cpuPercent: 0, memoryBytes: 0, processCount: 0)
        var visited: Set<Int32> = []
        var pending = [pid]
        while let next = pending.popLast() {
            guard visited.insert(next).inserted, let sample = samplesByPID[next] else { continue }
            usage.cpuPercent += sample.cpuPercent
            usage.memoryBytes += sample.memoryBytes
            usage.processCount += 1
            pending += (childrenByParent[next] ?? []).map(\.pid)
        }
        return usage
    }
}
