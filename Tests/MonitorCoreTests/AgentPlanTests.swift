import Foundation
import Testing
@testable import MonitorCore

private func call(_ name: String, _ input: String) -> String {
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t","name":"\#(name)","input":\#(input)}]}}"#
}

private let userLine = #"{"type":"user","message":{"role":"user","content":"hi"}}"#

struct AgentPlanTests {
    @Test func desktopPlanAdvancesStepByStep() {
        let tail = [
            call("mcp__ccd_turn__update_plan", #"{"items":[{"content":"Read code","status":"in_progress"},{"content":"Fix bug","status":"pending"},{"content":"Run tests","status":"pending"}],"scope":"first_task"}"#),
            userLine,
            call("mcp__ccd_turn__update_plan", #"{"advance":true}"#),
        ].joined(separator: "\n")
        let result = AgentPlanReader.plan(inTranscriptTail: tail)
        #expect(result.isComplete)
        #expect(result.plan?.current?.number == 2)
        #expect(result.plan?.current?.step.title == "Fix bug")
        #expect(result.plan?.completedCount == 1)
    }

    @Test func doneAndStartJumpAround() {
        let tail = [
            call("mcp__ccd_turn__update_plan", #"{"items":[{"content":"A","status":"in_progress"},{"content":"B","status":"pending"},{"content":"C","status":"pending"}]}"#),
            call("mcp__ccd_turn__update_plan", #"{"done":[1,2],"start":3}"#),
        ].joined(separator: "\n")
        #expect(AgentPlanReader.plan(inTranscriptTail: tail).plan?.current?.number == 3)
    }

    @Test func wrapUpFinishesThePlan() {
        let tail = [
            call("mcp__ccd_turn__update_plan", #"{"items":[{"content":"A","status":"in_progress"}]}"#),
            call("mcp__ccd_turn__wrap_up", #"{"recap":"Done."}"#),
        ].joined(separator: "\n")
        #expect(AgentPlanReader.plan(inTranscriptTail: tail).plan == nil)
    }

    @Test func todoWriteUsesTheActiveForm() {
        let tail = call("TodoWrite", #"{"todos":[{"content":"Add tests","status":"completed","activeForm":"Adding tests"},{"content":"Fix lint","status":"in_progress","activeForm":"Fixing lint"}]}"#)
        let plan = AgentPlanReader.plan(inTranscriptTail: tail).plan
        #expect(plan?.current?.number == 2)
        #expect(plan?.current?.step.title == "Fixing lint")
    }

    @Test func taskToolsBuildAList() {
        let tail = [
            call("TaskCreate", #"{"subject":"Write parser","description":"x","activeForm":"Writing parser"}"#),
            call("TaskCreate", #"{"subject":"Wire UI","description":"y"}"#),
            call("TaskUpdate", #"{"taskId":"1","status":"completed"}"#),
            call("TaskUpdate", #"{"taskId":"2","status":"in_progress"}"#),
        ].joined(separator: "\n")
        let plan = AgentPlanReader.plan(inTranscriptTail: tail).plan
        #expect(plan?.steps.count == 2)
        #expect(plan?.current?.step.title == "Wire UI")
    }

    @Test func anUpdateWithoutItsListAsksForMoreHistory() {
        let result = AgentPlanReader.plan(inTranscriptTail: call("mcp__ccd_turn__update_plan", #"{"advance":true}"#))
        #expect(!result.isComplete)
        #expect(result.plan == nil)
    }

    @Test func noPlanToolsMeansNoPlan() {
        let result = AgentPlanReader.plan(inTranscriptTail: userLine)
        #expect(result.isComplete)
        #expect(result.plan == nil)
    }
}

struct TranscriptTrackerTests {
    @Test func followsAPlanAcrossAppends() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("plan-\(UUID().uuidString).jsonl").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let start = call("mcp__ccd_turn__update_plan", #"{"items":[{"content":"A","status":"in_progress"},{"content":"B","status":"pending"}]}"#) + "\n"
        try start.write(toFile: path, atomically: true, encoding: .utf8)
        let tracker = TranscriptTracker()
        #expect(tracker.progress(ofTranscript: path)?.plan?.current?.step.title == "A")
        let handle = try #require(FileHandle(forWritingAtPath: path))
        handle.seekToEndOfFile()
        handle.write(Data((String(repeating: userLine + "\n", count: 2000) + call("mcp__ccd_turn__update_plan", #"{"advance":true}"#) + "\n").utf8))
        try handle.close()
        #expect(tracker.progress(ofTranscript: path)?.plan?.current?.step.title == "B")
    }
}
