import Foundation
@testable import MonitorCore
import Testing

struct StuckAgentTests {
    private let now = Date()

    private func activity(quietFor seconds: TimeInterval, _ turn: SessionActivity.LastTurn, pendingTool: String? = nil, repeated: RepeatedToolCall? = nil) -> SessionActivity {
        SessionActivity(lastWrite: now.addingTimeInterval(-seconds), lastTurn: turn, pendingTool: pendingTool, repeatedToolCall: repeated)
    }

    private func toolCall(_ name: String, _ input: String) -> String {
        #"{"type":"assistant","message":{"stop_reason":"tool_use","content":[{"type":"tool_use","name":"\#(name)","input":\#(input)}]}}"#
    }

    private let toolResult = #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"error"}]}}"#
    private let prompt = #"{"type":"user","message":{"role":"user","content":"try again"}}"#

    @Test func quietMidTurnForFifteenMinutesIsPossiblyStuck() {
        let reason = AgentCollector.stuckReason(activity: activity(quietFor: 16 * 60, .waitingOnModel), isRunningCommand: false, now: now)
        #expect(reason == .quiet(minutes: 16))
    }

    @Test func quietCommandPastBashTimeoutIsPossiblyStuck() {
        let running = activity(quietFor: 20 * 60, .waitingOnTool, pendingTool: "Bash")
        #expect(AgentCollector.stuckReason(activity: running, isRunningCommand: true, now: now) == .quiet(minutes: 20))
    }

    @Test func longBuildsUnderFifteenMinutesAreNotStuck() {
        let building = activity(quietFor: 10 * 60, .waitingOnTool, pendingTool: "Bash")
        #expect(AgentCollector.stuckReason(activity: building, isRunningCommand: true, now: now) == nil)
    }

    @Test func waitingOnTheUserIsNeverStuck() {
        let approval = activity(quietFor: 20 * 60, .waitingOnTool, pendingTool: "Bash")
        #expect(AgentCollector.stuckReason(activity: approval, isRunningCommand: false, now: now) == nil)
        #expect(AgentCollector.stuckReason(activity: activity(quietFor: 20 * 60, .finished), isRunningCommand: false, now: now) == nil)
        #expect(AgentCollector.stuckReason(activity: nil, isRunningCommand: false, now: now) == nil)
    }

    @Test func repeatingTheSameCallThreeTimesIsPossiblyStuck() {
        let looping = activity(quietFor: 5, .waitingOnModel, repeated: RepeatedToolCall(name: "Bash", count: 3))
        #expect(AgentCollector.stuckReason(activity: looping, isRunningCommand: false, now: now) == .repeatingTool(name: "Bash", times: 3))
        let retriedOnce = activity(quietFor: 5, .waitingOnModel, repeated: RepeatedToolCall(name: "Bash", count: 2))
        #expect(AgentCollector.stuckReason(activity: retriedOnce, isRunningCommand: false, now: now) == nil)
    }

    @Test func countsIdenticalCallsAtTheEndOfTheTail() {
        let call = toolCall("Bash", #"{"command":"swift test","description":"Run"}"#)
        let reordered = toolCall("Bash", #"{"description":"Run","command":"swift test"}"#)
        let tail = [call, toolResult, reordered, toolResult, call].joined(separator: "\n")
        #expect(ClaudeSessionLogs.repeatedToolCall(inTranscriptTail: tail) == RepeatedToolCall(name: "Bash", count: 3))
    }

    @Test func differentInputOrAPromptBreaksTheRun() {
        let first = toolCall("Bash", #"{"command":"swift build"}"#)
        let second = toolCall("Bash", #"{"command":"swift test"}"#)
        let changedInput = [first, toolResult, first, toolResult, second].joined(separator: "\n")
        #expect(ClaudeSessionLogs.repeatedToolCall(inTranscriptTail: changedInput) == RepeatedToolCall(name: "Bash", count: 1))
        let afterPrompt = [second, toolResult, second, prompt, second].joined(separator: "\n")
        #expect(ClaudeSessionLogs.repeatedToolCall(inTranscriptTail: afterPrompt) == RepeatedToolCall(name: "Bash", count: 1))
    }

    @Test func interruptedTurnIsTheUsersTurn() {
        let interrupted = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#
        let steered = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"},{"type":"text","text":"use bun instead"}]}}"#
        #expect(ClaudeSessionLogs.lastTurn(inTranscriptTail: interrupted) == .finished)
        #expect(ClaudeSessionLogs.lastTurn(inTranscriptTail: steered) == .waitingOnModel)
    }

    @Test func stuckReasonsReadAsSentences() {
        #expect(StuckReason.quiet(minutes: 17).summary == "No transcript writes for 17 min")
        #expect(StuckReason.repeatingTool(name: "Bash", times: 4).summary == "Same Bash call 4 times in a row")
    }

    @Test func possiblyStuckCountsAsWaiting() {
        #expect(AgentAlerts.waitingStates.contains(.possiblyStuck))
    }
}
