import Foundation
import MonitorCore

/// What a hover over a resource shows: a title, ranked rows such as the apps using the CPU, and notes.
struct ResourceDetail: Equatable {
    struct Row: Identifiable, Equatable {
        var id: String { name }
        var name: String
        var processCount = 1
        var value: String
        /// 0...1, relative to the top row.
        var fraction: Double
    }

    var title: String
    var rows: [Row] = []
    var notes: [String] = []
    /// The note to colour as a warning, e.g. a limit that runs out before reset.
    var isWarning = false

    /// Plain text for places that only take a native tooltip.
    var text: String {
        let rowLines = rows.map { "\($0.name)\($0.processCount > 1 ? " (\($0.processCount))" : "") — \($0.value)" }
        return ([title] + rowLines + notes).joined(separator: "\n")
    }
}

/// Hover details for the resource readings: what uses the CPU or memory, and when an agent limit runs out.
enum ResourceTooltips {
    static let consumerLimit = 6

    static func cpu(_ snapshot: SystemSnapshot?) -> ResourceDetail? {
        guard let snapshot else { return nil }
        let cores = Double(max(snapshot.cpu.perCore.count, 1))
        let consumers = ResourceBreakdown.consumers(of: snapshot.processes, by: .cpu, limit: consumerLimit)
        let top = max(consumers.first?.cpuPercent ?? 1, 0.1)
        let rows = consumers.map { ResourceDetail.Row(name: $0.name, processCount: $0.processCount, value: share($0.cpuPercent / 100 / cores), fraction: $0.cpuPercent / top) }
        return rows.isEmpty ? nil : ResourceDetail(title: "Using the CPU", rows: rows, notes: ["Share of all \(Int(cores)) cores"])
    }

    static func memory(_ snapshot: SystemSnapshot?) -> ResourceDetail? {
        guard let snapshot else { return nil }
        let consumers = ResourceBreakdown.consumers(of: snapshot.processes, by: .memory, limit: consumerLimit)
        let top = Double(max(consumers.first?.memoryBytes ?? 1, 1))
        let rows = consumers.map { ResourceDetail.Row(name: $0.name, processCount: $0.processCount, value: Formatters.bytes($0.memoryBytes), fraction: Double($0.memoryBytes) / top) }
        return rows.isEmpty ? nil : ResourceDetail(title: "Using the memory", rows: rows, notes: ["Memory pressure: \(snapshot.memory.pressure.rawValue)"],
                                                   isWarning: snapshot.memory.pressure != .normal)
    }

    static func disks(_ snapshot: SystemSnapshot?) -> ResourceDetail? {
        guard let disks = snapshot?.disks, !disks.isEmpty else { return nil }
        let rows = disks.map { disk in
            ResourceDetail.Row(name: disk.name, value: "\(Formatters.bytes(disk.availableBytes)) free", fraction: disk.usedFraction)
        }
        return ResourceDetail(title: "Disks", rows: rows)
    }

    static func limit(agentName: String, title: String, window: UsageWindow, forecast: LimitForecast?, now: Date = Date()) -> ResourceDetail {
        let reset = Formatters.resetCountdown(window.resetsAt, now: now).map { ", \($0)" } ?? ""
        let used = "\(Int(window.usedPercent.rounded()))% used\(reset)."
        let heading = "\(agentName) \(title)".trimmingCharacters(in: .whitespaces)
        switch forecast {
        case .reachesLimit(let date)?:
            let early = window.resetsAt.map { ", \(Formatters.duration($0.timeIntervalSince(date))) before it resets" } ?? ""
            return ResourceDetail(title: heading, notes: [used, "At the current pace you hit the limit at \(date.formatted(date: .omitted, time: .shortened))\(early)."], isWarning: true)
        case .lastsUntilReset?:
            return ResourceDetail(title: heading, notes: [used, "At the current pace you won't hit the limit before it resets."])
        case nil:
            return ResourceDetail(title: heading, notes: [used, "Not enough recent use to forecast yet."])
        }
    }

    private static func share(_ fraction: Double) -> String {
        fraction < 0.1 ? String(format: "%.1f%%", fraction * 100) : Formatters.percent(fraction)
    }
}
