import Foundation

/// Turns raw cumulative counters into rates by diffing against the previous sample.
public final class SystemCollector: @unchecked Sendable {
    private let metrics: SystemMetricsReader
    private let processes: ProcessInspector
    private let lock = NSLock()

    private var previousCPUTicks: [CPUTicks] = []
    private var previousNetwork: (counters: NetworkCounters, time: Date)?
    private var previousProcessTimes: [Int32: UInt64] = [:]
    private var previousProcessSampleTime: Date?

    public init(metrics: SystemMetricsReader = PlatformServices.makeSystemMetricsReader(),
                processes: ProcessInspector = PlatformServices.makeProcessInspector()) {
        self.metrics = metrics
        self.processes = processes
    }

    /// Processes are returned sorted by CPU, then memory.
    public func collect() -> SystemSnapshot {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        let rawProcesses = processes.listProcesses()
        return SystemSnapshot(
            timestamp: now,
            hostName: metrics.hostName(),
            uptime: metrics.uptime(),
            loadAverage: metrics.loadAverage(),
            cpu: sampleCPU(),
            memory: metrics.memory(),
            disks: metrics.disks(),
            network: sampleNetwork(at: now),
            battery: metrics.battery(),
            processes: sampleProcesses(rawProcesses, at: now)
        )
    }

    private func sampleCPU() -> CPUUsage {
        let current = metrics.cpuTicksPerCore()
        defer { previousCPUTicks = current }
        guard previousCPUTicks.count == current.count else { return CPUUsage(total: 0, perCore: current.map { _ in 0 }) }

        let perCore = zip(previousCPUTicks, current).map { previous, now in
            Self.busyFraction(previous: previous, current: now)
        }
        let total = Self.busyFraction(
            previous: CPUTicks(busy: previousCPUTicks.map(\.busy).reduce(0, +), total: previousCPUTicks.map(\.total).reduce(0, +)),
            current: CPUTicks(busy: current.map(\.busy).reduce(0, +), total: current.map(\.total).reduce(0, +))
        )
        return CPUUsage(total: total, perCore: perCore)
    }

    static func busyFraction(previous: CPUTicks, current: CPUTicks) -> Double {
        guard current.total > previous.total, current.busy >= previous.busy else { return 0 }
        return min(1, Double(current.busy - previous.busy) / Double(current.total - previous.total))
    }

    private func sampleNetwork(at now: Date) -> NetworkThroughput {
        let current = metrics.networkCounters()
        defer { previousNetwork = (current, now) }
        guard let previous = previousNetwork else { return .zero }
        let elapsed = now.timeIntervalSince(previous.time)
        guard elapsed > 0, current.bytesIn >= previous.counters.bytesIn, current.bytesOut >= previous.counters.bytesOut else { return .zero }
        return NetworkThroughput(
            bytesInPerSecond: Double(current.bytesIn - previous.counters.bytesIn) / elapsed,
            bytesOutPerSecond: Double(current.bytesOut - previous.counters.bytesOut) / elapsed
        )
    }

    private func sampleProcesses(_ rawProcesses: [RawProcess], at now: Date) -> [ProcessSample] {
        let elapsedNanoseconds = previousProcessSampleTime.map { now.timeIntervalSince($0) * 1_000_000_000 } ?? 0
        let samples = rawProcesses.map { process -> ProcessSample in
            var cpuPercent = 0.0
            if elapsedNanoseconds > 0, let previousTime = previousProcessTimes[process.pid], process.cpuTimeNanoseconds >= previousTime {
                cpuPercent = Double(process.cpuTimeNanoseconds - previousTime) / elapsedNanoseconds * 100
            }
            return ProcessSample(pid: process.pid, parentPID: process.parentPID, name: process.name, cpuPercent: cpuPercent, memoryBytes: process.memoryBytes)
        }
        previousProcessTimes = Dictionary(rawProcesses.map { ($0.pid, $0.cpuTimeNanoseconds) }, uniquingKeysWith: { first, _ in first })
        previousProcessSampleTime = now
        return samples.sorted { ($0.cpuPercent, $0.memoryBytes) > ($1.cpuPercent, $1.memoryBytes) }
    }
}
