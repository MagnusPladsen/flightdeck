import Foundation
import MonitorCore

/// Hover text for the resource readings: what uses the CPU or memory, and when an agent limit runs out.
enum ResourceTooltips {
    static let consumerLimit = 6

    static func cpu(_ snapshot: SystemSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let cores = Double(max(snapshot.cpu.perCore.count, 1))
        let lines = ResourceBreakdown.consumers(of: snapshot.processes, by: .cpu, limit: consumerLimit).map { consumer in
            "\(consumer.name)\(countSuffix(consumer)) — \(share(consumer.cpuPercent / 100 / cores))"
        }
        return lines.isEmpty ? nil : (["Using the CPU"] + lines).joined(separator: "\n")
    }

    static func memory(_ snapshot: SystemSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let lines = ResourceBreakdown.consumers(of: snapshot.processes, by: .memory, limit: consumerLimit).map { consumer in
            "\(consumer.name)\(countSuffix(consumer)) — \(Formatters.bytes(consumer.memoryBytes))"
        }
        let pressure = "Memory pressure: \(snapshot.memory.pressure.rawValue)"
        return lines.isEmpty ? nil : (["Using the memory"] + lines + ["", pressure]).joined(separator: "\n")
    }

    static func disks(_ snapshot: SystemSnapshot?) -> String? {
        guard let disks = snapshot?.disks, !disks.isEmpty else { return nil }
        return disks.map { "\($0.name) — \(Formatters.bytes($0.availableBytes)) free of \(Formatters.bytes($0.totalBytes))" }.joined(separator: "\n")
    }

    static func limit(agentName: String, title: String, window: UsageWindow, forecast: LimitForecast?, now: Date = Date()) -> String {
        let reset = Formatters.resetCountdown(window.resetsAt, now: now).map { ", \($0)" } ?? ""
        let used = "\(agentName) \(title): \(Int(window.usedPercent.rounded()))% used\(reset)."
        switch forecast {
        case .reachesLimit(let date)?:
            let early = window.resetsAt.map { " — \(Formatters.duration($0.timeIntervalSince(date))) before it resets" } ?? ""
            return "\(used)\nAt the current pace you hit the limit at \(date.formatted(date: .omitted, time: .shortened))\(early)."
        case .lastsUntilReset?:
            return "\(used)\nAt the current pace you won't hit the limit before it resets."
        case nil:
            return "\(used)\nNot enough recent use to forecast yet."
        }
    }

    private static func countSuffix(_ consumer: ResourceConsumer) -> String {
        consumer.processCount > 1 ? " (\(consumer.processCount))" : ""
    }

    private static func share(_ fraction: Double) -> String {
        fraction < 0.1 ? String(format: "%.1f%%", fraction * 100) : Formatters.percent(fraction)
    }
}
