import Foundation

/// Reads per-turn token use from Codex rollouts, with the model and folder of each turn.
/// Only bytes appended since the last pass are read.
public final class CodexTokenTracker: @unchecked Sendable {
    /// What a rollout has said so far, carried across passes.
    struct RolloutState {
        var offset: UInt64 = 0
        var model: String?
        var workingDirectory: String?
        /// Codex repeats a token_count event when only the rate limits change; the running total tells them apart.
        var lastTotal: Int?
    }

    private let logs: CodexSessionLogs
    private let days: Int
    private var states: [String: RolloutState] = [:]
    private var records: [TokenUsageRecord] = []
    private let lock = NSLock()

    public init(logs: CodexSessionLogs = CodexSessionLogs(), days: Int = 7) {
        self.logs = logs
        self.days = days
    }

    public func records(now: Date = Date()) -> [TokenUsageRecord] {
        lock.lock()
        defer { lock.unlock() }
        let rollouts = logs.recentRollouts(days: days + 1, now: now)
        for rollout in rollouts { ingest(path: rollout.path) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: now)) ?? now
        records.removeAll { $0.timestamp < cutoff }
        let current = Set(rollouts.map(\.path))
        states = states.filter { current.contains($0.key) }
        return records
    }

    private func ingest(path: String) {
        var state = states[path] ?? RolloutState(workingDirectory: CodexSessionLogs.workingDirectory(ofRolloutAt: path))
        let (lines, nextOffset) = LogFiles.readNewLines(of: path, from: state.offset)
        state.offset = nextOffset
        records += Self.records(in: lines, state: &state)
        states[path] = state
    }

    static func records(in lines: [Substring], state: inout RolloutState) -> [TokenUsageRecord] {
        lines.compactMap { line in
            if line.contains("\"turn_context\"") {
                applyTurnContext(line, to: &state)
                return nil
            }
            guard line.contains("\"token_count\""), let turn = parseTurnUsage(line), turn.total != state.lastTotal else { return nil }
            state.lastTotal = turn.total
            return TokenUsageRecord(tool: .codex, timestamp: turn.timestamp, model: state.model, workingDirectory: state.workingDirectory, tokens: turn.tokens)
        }
    }

    private static func applyTurnContext(_ line: Substring, to state: inout RolloutState) {
        guard let payload = payload(of: line) else { return }
        state.model = payload["model"] as? String ?? state.model
        state.workingDirectory = payload["cwd"] as? String ?? state.workingDirectory
    }

    struct TurnUsage {
        var timestamp: Date
        var total: Int
        var tokens: TokenTotals
    }

    static func parseTurnUsage(_ line: Substring) -> TurnUsage? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = ClaudeTokenTracker.parseTimestamp(json["timestamp"] as? String),
              let info = (json["payload"] as? [String: Any])?["info"] as? [String: Any],
              let total = (info["total_token_usage"] as? [String: Any])?["total_tokens"] as? Int,
              let last = CodexUsageReader.parseTotals(info["last_token_usage"] as? [String: Any]) else { return nil }
        return TurnUsage(timestamp: timestamp, total: total, tokens: last)
    }

    private static func payload(of line: Substring) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["payload"] as? [String: Any]
    }
}
