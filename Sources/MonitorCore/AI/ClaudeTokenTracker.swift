import Foundation

/// Sums Claude Code token usage from transcripts, reading only bytes appended since the last pass.
public final class ClaudeTokenTracker: @unchecked Sendable {
    struct UsageRecord {
        let id: String
        let timestamp: Date
        let tokens: TokenTotals
        let model: String?
        let workingDirectory: String?
    }

    private let projectsDirectory: String
    private let retention: TimeInterval
    private var offsets: [String: UInt64] = [:]
    private var records: [UsageRecord] = []
    private var seenIDs = Set<String>()
    private let lock = NSLock()

    public init(projectsDirectory: String = NSHomeDirectory() + "/.claude/projects", retention: TimeInterval = 24 * 60 * 60) {
        self.projectsDirectory = projectsDirectory
        self.retention = retention
    }

    /// Every assistant reply in the retention window, with the model and folder it ran in.
    public func records(now: Date = Date()) -> [TokenUsageRecord] {
        lock.lock()
        defer { lock.unlock() }
        ingestNewTranscriptLines(now: now)
        return records.map { TokenUsageRecord(tool: .claude, timestamp: $0.timestamp, model: $0.model, workingDirectory: $0.workingDirectory, tokens: $0.tokens) }
    }

    public func totals(now: Date = Date()) -> (today: TokenTotals, lastFiveHours: TokenTotals) {
        lock.lock()
        defer { lock.unlock() }
        ingestNewTranscriptLines(now: now)
        let startOfDay = Calendar.current.startOfDay(for: now)
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let today = records.filter { $0.timestamp >= startOfDay }.map(\.tokens).reduce(TokenTotals(), +)
        let window = records.filter { $0.timestamp >= fiveHoursAgo }.map(\.tokens).reduce(TokenTotals(), +)
        return (today, window)
    }

    private func ingestNewTranscriptLines(now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        for file in recentTranscripts(modifiedAfter: cutoff) {
            let (lines, nextOffset) = LogFiles.readNewLines(of: file.path, from: offsets[file.path] ?? 0)
            offsets[file.path] = nextOffset
            for line in lines where line.contains("\"output_tokens\"") {
                guard let record = Self.parseUsageRecord(line), record.timestamp >= cutoff, seenIDs.insert(record.id).inserted else { continue }
                records.append(record)
            }
        }
        records.removeAll { $0.timestamp < cutoff }
        seenIDs = Set(records.map(\.id))
    }

    private func recentTranscripts(modifiedAfter cutoff: Date) -> [LogFiles.Entry] {
        guard let enumerator = FileManager.default.enumerator(atPath: projectsDirectory) else { return [] }
        var entries: [LogFiles.Entry] = []
        while let relativePath = enumerator.nextObject() as? String {
            guard relativePath.hasSuffix(".jsonl"),
                  let entry = LogFiles.entry(at: projectsDirectory + "/" + relativePath),
                  entry.modified >= cutoff else { continue }
            entries.append(entry)
        }
        return entries
    }

    /// Streaming writes one line per content block with the same message id; dedupe on id + request.
    static func parseUsageRecord(_ line: Substring) -> UsageRecord? {
        guard let data = line.data(using: .utf8),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.type == "assistant",
              let message = entry.message, let usage = message.usage,
              let timestamp = parseTimestamp(entry.timestamp) else { return nil }

        let tokens = TokenTotals(
            input: usage.inputTokens ?? 0,
            output: usage.outputTokens ?? 0,
            cacheRead: usage.cacheReadInputTokens ?? 0,
            cacheWrite: usage.cacheCreationInputTokens ?? 0
        )
        let id = (message.id ?? UUID().uuidString) + ":" + (entry.requestId ?? "")
        return UsageRecord(id: id, timestamp: timestamp, tokens: tokens, model: message.model, workingDirectory: entry.cwd)
    }

    static func parseTimestamp(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private struct Entry: Decodable {
        struct Message: Decodable {
            let id: String?
            let model: String?
            let usage: Usage?
        }

        struct Usage: Decodable {
            let inputTokens: Int?
            let outputTokens: Int?
            let cacheReadInputTokens: Int?
            let cacheCreationInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
            }
        }

        let type: String
        let timestamp: String?
        let requestId: String?
        let cwd: String?
        let message: Message?
    }
}
