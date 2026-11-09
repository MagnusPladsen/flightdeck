import Foundation
import Testing
@testable import MonitorCore

struct AgentLastMessageTests {
    @Test func claudeFinishedTurnShowsTheLastLineOfItsReply() {
        let tail = """
        {"type":"user","message":{"content":"Fix the refresh bug"}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Token refresh is **fixed** and all 212 tests pass.\\n\\nWant me to open a PR?\\n"}]}}
        """
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: tail) == "Want me to open a PR?")
    }

    @Test func claudeSkipsCodeFencesAndBlankLines() {
        let tail = #"{"type":"assistant","message":{"content":[{"type":"text","text":"Run this:\n```\n```\n"}]}}"#
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: tail) == "Run this:")
    }

    @Test func claudePendingToolCallReadsAsARequest() {
        let bash = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"Migrating now."}]}}
        {"type":"assistant","message":{"stop_reason":"tool_use","content":[{"type":"tool_use","name":"Bash","input":{"command":"bun run db:migrate\\necho done"}}]}}
        """
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: bash) == "Wants to run bun run db:migrate")
        let edit = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/repo/Theme.swift"}}]}}"#
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: edit) == "Wants to edit Theme.swift")
        let plan = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ExitPlanMode","input":{"plan":"1. Do it"}}]}}"#
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: plan) == "Wants you to review its plan")
    }

    @Test func claudeQuestionToolShowsTheQuestion() {
        let tail = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"question":"Which database should I use?","header":"DB","options":[{"label":"Postgres"}]}]}}]}}"#
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: tail) == "Which database should I use?")
    }

    @Test func longMessagesAreShortened() {
        let text = String(repeating: "word ", count: 100)
        let tail = #"{"type":"assistant","message":{"content":[{"type":"text","text":"\#(text)"}]}}"#
        let message = ClaudeSessionLogs.lastMessage(inTranscriptTail: tail)
        #expect(message?.count == AgentLastMessage.maxLength)
        #expect(message?.hasSuffix("…") == true)
    }

    @Test func codexShowsTheNewestAgentMessage() {
        let tail = """
        {"timestamp":"2026-11-09T10:00:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"Looking at the guides."}}
        {"timestamp":"2026-11-09T10:01:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"ignored"}]}}
        {"timestamp":"2026-11-09T10:02:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"Moved 4 guides.\\n\\nShould they go under `/learn` or `/docs`?"}}
        {"timestamp":"2026-11-09T10:02:01.000Z","type":"event_msg","payload":{"type":"task_complete","last_agent_message":"x"}}
        """
        #expect(CodexSessionLogs.lastMessage(inRolloutTail: tail) == "Should they go under /learn or /docs?")
    }

    @Test func noAssistantTextMeansNoMessage() {
        #expect(ClaudeSessionLogs.lastMessage(inTranscriptTail: #"{"type":"user","message":{"content":"hi"}}"#) == nil)
        #expect(CodexSessionLogs.lastMessage(inRolloutTail: "") == nil)
    }
}
