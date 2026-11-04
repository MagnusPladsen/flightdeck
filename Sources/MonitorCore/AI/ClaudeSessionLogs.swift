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
        let block = Self.lastAssistantBlock(inTranscriptTail: tail)
        return SessionActivity(lastWrite: newest.modified, lastTurn: Self.lastTurn(inTranscriptTail: tail), lastAction: block.map(Self.action), pendingTool: block?.type == "tool_use" ? block?.name : nil)
    }

    /// Looks at the last user/assistant message to tell who is expected to act next.
    static func lastTurn(inTranscriptTail tail: String) -> SessionActivity.LastTurn {
        for line in tail.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(TranscriptEntry.self, from: data) else { continue }
            switch entry.type {
            case "assistant":
                guard entry.message?.stopReason == "tool_use" else { return .finished }
                // Text or thinking written before the tool call: the call itself is still being generated
                return entry.message?.hasToolCall == false ? .waitingOnModel : .waitingOnTool
            case "user":
                return .waitingOnModel
            default:
                continue
            }
        }
        return .unknown
    }

    /// Describes the newest assistant step: the tool it called, or the first line of what it said.
    static func lastAction(inTranscriptTail tail: String) -> AgentAction? {
        lastAssistantBlock(inTranscriptTail: tail).map(action)
    }

    private static func lastAssistantBlock(inTranscriptTail tail: String) -> AssistantEntry.Block? {
        for line in tail.split(separator: "\n").reversed() {
            guard line.contains(#""type":"assistant""#),
                  let data = line.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(AssistantEntry.self, from: data),
                  let block = entry.message.content.last(where: { $0.type == "tool_use" || $0.type == "text" }) else { continue }
            return block
        }
        return nil
    }

    private static func action(for block: AssistantEntry.Block) -> AgentAction {
        block.type == "tool_use" ? toolAction(name: block.name ?? "tool", input: block.input) : textAction(block.text ?? "")
    }

    static func toolAction(name: String, input: ToolInput?) -> AgentAction {
        let fileName = (input?.filePath ?? input?.path).map { ($0 as NSString).lastPathComponent }
        switch name {
        case "Bash": return AgentAction(verb: "Running", detail: firstLine(input?.command ?? ""))
        case "Edit", "MultiEdit", "NotebookEdit": return AgentAction(verb: "Editing", detail: fileName ?? "a file")
        case "Write": return AgentAction(verb: "Writing", detail: fileName ?? "a file")
        case "Read": return AgentAction(verb: "Reading", detail: fileName ?? "a file")
        case "Grep", "Glob": return AgentAction(verb: "Searching", detail: input?.pattern ?? "the project")
        case "WebFetch", "WebSearch": return AgentAction(verb: "Browsing", detail: input?.url ?? input?.query ?? "the web")
        case "Task", "Agent": return AgentAction(verb: "Delegating", detail: input?.description ?? "a subtask")
        default: return AgentAction(verb: "Using", detail: name)
        }
    }

    static func textAction(_ text: String) -> AgentAction {
        let line = firstLine(plainText(fromMarkdown: text))
        return AgentAction(verb: line.hasSuffix("?") ? "Asked" : "Said", detail: line)
    }

    /// Keeps link text, drops link targets, emphasis and code markers.
    static func plainText(fromMarkdown text: String) -> String {
        text.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`]{1,3}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
    }

    private static func firstLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.count > 140 ? String(line.prefix(139)) + "…" : line
    }

    struct ToolInput: Decodable {
        var command: String?
        var filePath: String?
        var path: String?
        var pattern: String?
        var url: String?
        var query: String?
        var description: String?

        enum CodingKeys: String, CodingKey {
            case command, path, pattern, url, query, description
            case filePath = "file_path"
        }

        /// Tool inputs vary per tool, so a field of an unexpected type is skipped rather than failing.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            func string(_ key: CodingKeys) -> String? { (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil }
            command = string(.command)
            filePath = string(.filePath)
            path = string(.path)
            pattern = string(.pattern)
            url = string(.url)
            query = string(.query)
            description = string(.description)
        }
    }

    private struct AssistantEntry: Decodable {
        struct Message: Decodable {
            let content: [Block]
        }

        struct Block: Decodable {
            let type: String
            let name: String?
            let text: String?
            let input: ToolInput?
        }

        let message: Message
    }

    private struct TranscriptEntry: Decodable {
        struct Message: Decodable {
            struct Block: Decodable { let type: String }

            let stopReason: String?
            /// Nil when the content is missing or plain text, as in user prompts.
            let hasToolCall: Bool?

            enum CodingKeys: String, CodingKey { case stopReason = "stop_reason", content }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                stopReason = try container.decodeIfPresent(String.self, forKey: .stopReason)
                let blocks = try? container.decodeIfPresent([Block].self, forKey: .content)
                hasToolCall = blocks.map { $0.contains { $0.type == "tool_use" } }
            }
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
