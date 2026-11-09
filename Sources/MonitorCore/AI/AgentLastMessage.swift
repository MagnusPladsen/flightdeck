import Foundation

/// What an agent last said to the user, or what it is asking for, shortened for a card.
enum AgentLastMessage {
    static let maxLength = 280

    /// The last line of prose in `text`, skipping blank lines, code fences and table rules.
    static func lastLine(of text: String) -> String? {
        let lines = ClaudeSessionLogs.plainText(fromMarkdown: text).split(whereSeparator: \.isNewline)
        let line = lines.reversed().first { $0.contains { $0.isLetter || $0.isNumber } }
        return line.map { shortened(String($0).trimmingCharacters(in: .whitespaces)) }
    }

    static func shortened(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text
    }

    /// "Wants to run swift test", "Wants to edit Theme.swift", or the question Claude is asking.
    static func request(toolName: String, input: ClaudeSessionLogs.ToolInput?, question: String?) -> String {
        if let question { return shortened(question) }
        if toolName == "ExitPlanMode" { return "Wants you to review its plan" }
        let action = ClaudeSessionLogs.toolAction(name: toolName, input: input)
        let verb = requestVerbs[action.verb] ?? "use"
        return shortened("Wants to \(verb) \(action.detail)")
    }

    private static let requestVerbs = [
        "Running": "run", "Editing": "edit", "Writing": "write", "Reading": "read", "Searching": "search for",
        "Browsing": "open", "Delegating": "start", "Using": "use",
    ]
}

extension ClaudeSessionLogs {
    /// The newest assistant step: its pending tool call as a request, or the last line of what it said.
    static func lastMessage(inTranscriptTail tail: String) -> String? {
        for line in tail.split(separator: "\n").reversed() where line.contains(#""type":"assistant""#) {
            guard let entry = try? JSONDecoder().decode(MessageEntry.self, from: Data(line.utf8)),
                  let block = entry.message.content.last(where: { $0.type == "tool_use" || $0.type == "text" }) else { continue }
            if block.type == "tool_use" { return AgentLastMessage.request(toolName: block.name ?? "tool", input: block.input, question: block.question) }
            if let text = block.text.flatMap(AgentLastMessage.lastLine) { return text }
        }
        return nil
    }

    private struct MessageEntry: Decodable {
        struct Message: Decodable {
            let content: [Block]
        }

        struct Block: Decodable {
            let type: String
            let name: String?
            let text: String?
            let input: ToolInput?
            let question: String?

            enum CodingKeys: String, CodingKey { case type, name, text, input }
            enum InputKeys: String, CodingKey { case questions }
            struct Question: Decodable { let question: String }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = try container.decode(String.self, forKey: .type)
                name = try? container.decodeIfPresent(String.self, forKey: .name)
                text = try? container.decodeIfPresent(String.self, forKey: .text)
                input = try? container.decodeIfPresent(ToolInput.self, forKey: .input)
                let questions = try? container.nestedContainer(keyedBy: InputKeys.self, forKey: .input).decodeIfPresent([Question].self, forKey: .questions)
                question = questions?.first?.question
            }
        }

        let message: Message
    }
}

extension CodexSessionLogs {
    static let messageTailBytes: UInt64 = 64 * 1024

    /// The text of the newest `agent_message` event in a rollout.
    static func lastMessage(inRolloutTail tail: String) -> String? {
        for line in tail.split(separator: "\n").reversed() where line.contains(#""agent_message""#) {
            guard let entry = try? JSONDecoder().decode(RolloutEvent.self, from: Data(line.utf8)),
                  entry.type == "event_msg", entry.payload.type == "agent_message",
                  let text = entry.payload.message.flatMap(AgentLastMessage.lastLine) else { continue }
            return text
        }
        return nil
    }

    private struct RolloutEvent: Decodable {
        struct Payload: Decodable {
            let type: String
            let message: String?
        }

        let type: String
        let payload: Payload
    }
}
