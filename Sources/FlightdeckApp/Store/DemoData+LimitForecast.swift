import Foundation
import MonitorCore

extension DemoData {
    private static let percentPerHour: [String: Double] = [
        "claude-5h": 30, "claude-Weekly": 0.5, "codex-5h": 6, "codex-Weekly": 0,
    ]

    static var usageHistory: UsageHistory {
        let now = Date()
        var history = UsageHistory()
        for provider in usage {
            for window in provider.windows { record(window, tool: provider.tool, into: &history, endingAt: now) }
        }
        return history
    }

    private static func record(_ window: UsageWindow, tool: AgentTool, into history: inout UsageHistory, endingAt now: Date) {
        let rate = percentPerHour["\(tool.rawValue)-\(window.label)"] ?? 0
        for minutesAgo in stride(from: 40, through: 0, by: -1) {
            var sample = window
            sample.usedPercent = window.usedPercent - rate * Double(minutesAgo) / 60
            history.record(sample, tool: tool, at: now.addingTimeInterval(-Double(minutesAgo) * 60))
        }
    }
}
