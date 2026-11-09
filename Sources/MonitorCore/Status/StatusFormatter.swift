import Foundation

/// Turns a status report into the one-line text the `flightdeck status` command prints.
public enum StatusFormatter {
    /// "2 working · 1 needs you · 3 servers", leaving out what is zero.
    public static func summary(_ report: StatusReport) -> String {
        let counts = report.counts
        let parts = [
            counts.working > 0 ? "\(counts.working) working" : nil,
            counts.needsYou > 0 ? "\(counts.needsYou) needs you" : nil,
            counts.servers > 0 ? "\(counts.servers) \(counts.servers == 1 ? "server" : "servers")" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? "No active agents" : parts.joined(separator: " · ")
    }

    /// Replaces `{name}` placeholders, e.g. "{needsYou}/{working}" becomes "1/2". Unknown names stay as they are.
    public static func format(_ template: String, report: StatusReport) -> String {
        placeholders(for: report).reduce(template) { text, entry in
            text.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    public static let placeholderNames = ["working", "needsYou", "idle", "agents", "servers", "cpu", "memory", "summary"]

    static func placeholders(for report: StatusReport) -> [String: String] {
        let counts = report.counts
        return [
            "working": "\(counts.working)",
            "needsYou": "\(counts.needsYou)",
            "idle": "\(counts.idle)",
            "agents": "\(report.agents.count)",
            "servers": "\(counts.servers)",
            "cpu": report.system.map { "\($0.cpuPercent)" } ?? "",
            "memory": report.system.map { "\($0.memoryPercent)" } ?? "",
            "summary": summary(report),
        ]
    }
}
