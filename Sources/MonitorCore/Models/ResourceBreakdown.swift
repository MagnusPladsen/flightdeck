import Foundation

/// An app and its helper processes, with what they use together, e.g. "Google Chrome" and its renderers.
public struct ResourceConsumer: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public var name: String
    /// Percent of one core summed over the processes, like Activity Monitor.
    public var cpuPercent: Double
    public var memoryBytes: UInt64
    public var processes: [ProcessSample]

    public var processCount: Int { processes.count }
}

extension ProcessSample: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(pid) }
}

/// Groups processes by the app they belong to and ranks what uses the most CPU or memory.
public enum ResourceBreakdown {
    public enum Measure: Sendable {
        case cpu, memory
    }

    public static func consumers(of processes: [ProcessSample], by measure: Measure, limit: Int) -> [ResourceConsumer] {
        let groups = Dictionary(grouping: processes) { appName(of: $0.name) }
        let consumers = groups.map { name, members in
            ResourceConsumer(name: name, cpuPercent: members.reduce(0) { $0 + $1.cpuPercent },
                             memoryBytes: members.reduce(0) { $0 + $1.memoryBytes }, processes: members.sorted { value($0, measure) > value($1, measure) })
        }
        return Array(consumers.filter { value($0, measure) > 0 }.sorted { value($0, measure) > value($1, measure) }.prefix(limit))
    }

    /// "Google Chrome Helper (Renderer)" and "Code Helper (GPU)" belong to "Google Chrome" and "Code".
    public static func appName(of processName: String) -> String {
        var name = processName
        if let paren = name.range(of: " (", options: .backwards), name.hasSuffix(")") { name = String(name[..<paren.lowerBound]) }
        if let helper = name.range(of: " Helper") { name = String(name[..<helper.lowerBound]) }
        return name.isEmpty ? processName : name
    }

    private static func value(_ process: ProcessSample, _ measure: Measure) -> Double {
        measure == .cpu ? process.cpuPercent : Double(process.memoryBytes)
    }

    private static func value(_ consumer: ResourceConsumer, _ measure: Measure) -> Double {
        measure == .cpu ? consumer.cpuPercent : Double(consumer.memoryBytes)
    }
}
