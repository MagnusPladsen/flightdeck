import Foundation

/// Bytes a process has sent and received since it started, as `nettop` reports them.
public struct NetworkCounter: Sendable, Equatable {
    public var pid: Int32
    public var name: String
    public var bytesIn: UInt64
    public var bytesOut: UInt64
}

/// An app and its helpers, with how fast they download and upload.
public struct NetworkConsumer: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public var name: String
    public var bytesInPerSecond: Double
    public var bytesOutPerSecond: Double
    public var processCount: Int

    public init(name: String, bytesInPerSecond: Double, bytesOutPerSecond: Double, processCount: Int) {
        self.name = name
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.processCount = processCount
    }

    public var totalPerSecond: Double { bytesInPerSecond + bytesOutPerSecond }
}

public enum NetworkBreakdown {
    /// `nettop -P -L 1 -x -J bytes_in,bytes_out` prints a header, then `name.pid,in,out,` per process.
    public static func parseNettop(_ output: String) -> [NetworkCounter] {
        output.split(separator: "\n").dropFirst().compactMap { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 3, let dot = fields[0].lastIndex(of: "."), let pid = Int32(fields[0][fields[0].index(after: dot)...]),
                  let bytesIn = UInt64(fields[1]), let bytesOut = UInt64(fields[2]) else { return nil }
            return NetworkCounter(pid: pid, name: String(fields[0][..<dot]), bytesIn: bytesIn, bytesOut: bytesOut)
        }
    }

    /// Rates between two readings, grouped by app and ranked by total traffic. Processes new since the
    /// first reading are left out, as their counters cover their whole life. `names` gives full process
    /// names by pid, as `nettop` cuts them short.
    public static func consumers(previous: [NetworkCounter], current: [NetworkCounter], seconds: TimeInterval,
                                 names: [Int32: String] = [:], limit: Int) -> [NetworkConsumer] {
        guard seconds > 0 else { return [] }
        let before = Dictionary(previous.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        let rates = current.compactMap { counter -> (app: String, down: Double, up: Double)? in
            guard let old = before[counter.pid] else { return nil }
            let down = Double(counter.bytesIn &- min(old.bytesIn, counter.bytesIn)) / seconds
            let up = Double(counter.bytesOut &- min(old.bytesOut, counter.bytesOut)) / seconds
            return (ResourceBreakdown.appName(of: names[counter.pid] ?? counter.name), down, up)
        }
        let grouped = Dictionary(grouping: rates, by: \.app).map { app, members in
            NetworkConsumer(name: app, bytesInPerSecond: members.reduce(0) { $0 + $1.down }, bytesOutPerSecond: members.reduce(0) { $0 + $1.up }, processCount: members.count)
        }
        return Array(grouped.filter { $0.totalPerSecond > 0 }.sorted { $0.totalPerSecond > $1.totalPerSecond }.prefix(limit))
    }
}
