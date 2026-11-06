import Foundation

/// Codex writes its real rate-limit state into every `token_count` event, so its limits are exact.
public struct CodexUsageReader: Sendable {
    private let logs: CodexSessionLogs

    public init(logs: CodexSessionLogs = CodexSessionLogs()) {
        self.logs = logs
    }

    public func read(now: Date = Date()) -> ProviderUsage? {
        let rollouts = logs.recentRollouts(days: 7, now: now)
        guard let latest = rollouts.lazy.compactMap({ Self.latestTokenCount(inRolloutAt: $0.path) }).first else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: now)
        let tokensToday = rollouts
            .filter { $0.modified >= startOfDay }
            .compactMap { Self.latestTokenCount(inRolloutAt: $0.path)?.totals }
            .reduce(TokenTotals(), +)

        return ProviderUsage(
            tool: .codex,
            plan: latest.planType,
            windows: latest.windows,
            tokensToday: tokensToday,
            updatedAt: latest.timestamp
        )
    }

    struct TokenCountEvent {
        var timestamp: Date?
        var planType: String?
        var windows: [UsageWindow]
        /// Cumulative for the session the rollout belongs to.
        var totals: TokenTotals?
    }

    static func latestTokenCount(inRolloutAt path: String) -> TokenCountEvent? {
        let tail = LogFiles.readTail(of: path, maxBytes: 256 * 1024)
        for line in tail.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            if let event = parseTokenCount(line) { return event }
        }
        return nil
    }

    static func parseTokenCount(_ line: Substring) -> TokenCountEvent? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] as? [String: Any],
              let limits = payload["rate_limits"] as? [String: Any] else { return nil }

        let windows = ["primary", "secondary"].compactMap { key -> UsageWindow? in
            guard let window = limits[key] as? [String: Any], let used = window["used_percent"] as? Double else { return nil }
            let minutes = window["window_minutes"] as? Int
            let resetsAt = (window["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            return UsageWindow(label: windowLabel(minutes: minutes), usedPercent: used, resetsAt: resetsAt)
        }
        guard !windows.isEmpty else { return nil }

        return TokenCountEvent(
            timestamp: ClaudeTokenTracker.parseTimestamp(json["timestamp"] as? String),
            planType: limits["plan_type"] as? String,
            windows: windows,
            totals: parseTotals((payload["info"] as? [String: Any])?["total_token_usage"] as? [String: Any])
        )
    }

    static func windowLabel(minutes: Int?) -> String {
        guard let minutes else { return "Limit" }
        if minutes == 10080 { return "Weekly" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    static func parseTotals(_ usage: [String: Any]?) -> TokenTotals? {
        guard let usage else { return nil }
        let input = usage["input_tokens"] as? Int ?? 0
        let cached = usage["cached_input_tokens"] as? Int ?? 0
        return TokenTotals(input: max(0, input - cached), output: usage["output_tokens"] as? Int ?? 0, cacheRead: cached)
    }
}
