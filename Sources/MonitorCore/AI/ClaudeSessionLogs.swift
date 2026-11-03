import Foundation

/// Reads Claude Code transcripts in `~/.claude/projects/<encoded cwd>/<session>.jsonl`.
public struct ClaudeSessionLogs: Sendable {
    public let projectsDirectory: String

    public init(projectsDirectory: String = NSHomeDirectory() + "/.claude/projects") {
        self.projectsDirectory = projectsDirectory
    }

    /// Claude Code replaces every non-alphanumeric character of the cwd with "-".
    static func encodedDirectoryName(for workingDirectory: String) -> String {
        String(workingDirectory.map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }

    public func latestActivity(forWorkingDirectory workingDirectory: String) -> SessionActivity? {
        let directory = projectsDirectory + "/" + Self.encodedDirectoryName(for: workingDirectory)
        guard let newest = LogFiles.newestFile(in: directory, withExtension: "jsonl") else { return nil }
        let tail = LogFiles.readTail(of: newest.path, maxBytes: 64 * 1024)
        return SessionActivity(lastWrite: newest.modified, lastTurn: Self.lastTurn(inTranscriptTail: tail))
    }

    /// Looks at the last user/assistant message to tell who is expected to act next.
    static func lastTurn(inTranscriptTail tail: String) -> SessionActivity.LastTurn {
        for line in tail.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(TranscriptEntry.self, from: data) else { continue }
            switch entry.type {
            case "assistant":
                return entry.message?.stopReason == "tool_use" ? .waitingOnTool : .finished
            case "user":
                return .waitingOnModel
            default:
                continue
            }
        }
        return .unknown
    }

    private struct TranscriptEntry: Decodable {
        struct Message: Decodable {
            let stopReason: String?
            enum CodingKeys: String, CodingKey { case stopReason = "stop_reason" }
        }

        let type: String
        let message: Message?
    }
}

/// Reads Codex rollouts in `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`.
public final class CodexSessionLogs: @unchecked Sendable {
    public let sessionsDirectory: String
    private var workingDirectoryByRollout: [String: String] = [:]
    private let lock = NSLock()

    public init(sessionsDirectory: String = NSHomeDirectory() + "/.codex/sessions") {
        self.sessionsDirectory = sessionsDirectory
    }

    /// Rollout files from the last few days, newest first.
    public func recentRollouts(days: Int = 2, now: Date = Date()) -> [LogFiles.Entry] {
        let calendar = Calendar(identifier: .gregorian)
        return (0..<days).flatMap { offset -> [LogFiles.Entry] in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return [] }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let path = String(format: "%@/%04d/%02d/%02d", sessionsDirectory, parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            return LogFiles.files(in: path, withExtension: "jsonl")
        }
        .sorted { $0.modified > $1.modified }
    }

    public func latestActivity(forWorkingDirectory workingDirectory: String) -> SessionActivity? {
        let match = recentRollouts().first { cachedWorkingDirectory(ofRolloutAt: $0.path) == workingDirectory }
        return match.map { SessionActivity(lastWrite: $0.modified, lastTurn: .unknown) }
    }

    private func cachedWorkingDirectory(ofRolloutAt path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = workingDirectoryByRollout[path] { return cached }
        let directory = Self.workingDirectory(ofRolloutAt: path)
        workingDirectoryByRollout[path] = directory
        return directory
    }

    /// The first line is `session_meta`, whose payload starts with the session's cwd. That line can be
    /// hundreds of KB (it embeds instructions), so pull the field out of the head instead of decoding it.
    static func workingDirectory(ofRolloutAt path: String) -> String? {
        let head = LogFiles.readHead(of: path, maxBytes: 8 * 1024)
        guard head.contains("\"session_meta\""),
              let keyRange = head.range(of: "\"cwd\":\"") else { return nil }
        let rest = head[keyRange.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}
