import Foundation

/// The task list an agent keeps while it works, e.g. Claude's to-dos, so a card can say which step it is on.
public struct AgentPlan: Sendable, Hashable {
    public enum Status: String, Sendable {
        case pending
        case inProgress = "in_progress"
        case completed
    }

    public struct Step: Sendable, Hashable {
        public var title: String
        public var status: Status

        public init(title: String, status: Status) {
            self.title = title
            self.status = status
        }
    }

    public var steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    /// The step being worked on and its 1-based number, while the plan is unfinished.
    public var current: (number: Int, step: Step)? {
        guard let index = steps.firstIndex(where: { $0.status == .inProgress }) ?? steps.firstIndex(where: { $0.status == .pending }) else { return nil }
        return (index + 1, steps[index])
    }

    public var completedCount: Int { steps.filter { $0.status == .completed }.count }
}

/// Replays the plan tools in a Claude Code transcript: the desktop app's `update_plan`, the CLI's
/// `TodoWrite`, and its `TaskCreate` / `TaskUpdate`.
public enum AgentPlanReader {
    static let planToolNames = ["mcp__ccd_turn__update_plan", "mcp__ccd_turn__wrap_up", "TodoWrite", "TaskCreate", "TaskUpdate"]

    /// The plan as of the end of the tail. `isComplete` is false when the tail starts partway through
    /// a plan (an update without the list it updates), so a wider tail is needed.
    public static func plan(inTranscriptTail tail: String) -> (plan: AgentPlan?, isComplete: Bool) {
        var replay = PlanReplay()
        apply(lines: tail, to: &replay)
        return (replay.plan, !replay.isMissingStart)
    }

    static func apply(lines text: String, to replay: inout PlanReplay) {
        for line in text.split(separator: "\n") where line.contains(#""type":"assistant""#) && planToolNames.contains(where: { line.contains($0) }) {
            for call in toolCalls(in: line) { replay.apply(name: call.name, input: call.input) }
        }
    }

    private static func toolCalls(in line: Substring) -> [(name: String, input: [String: Any])] {
        guard let entry = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let message = entry["message"] as? [String: Any], let content = message["content"] as? [[String: Any]] else { return [] }
        return content.compactMap { block in
            guard block["type"] as? String == "tool_use", let name = block["name"] as? String, planToolNames.contains(name) else { return nil }
            return (name, block["input"] as? [String: Any] ?? [:])
        }
    }
}

struct PlanReplay {
    var steps: [AgentPlan.Step]?
    var isMissingStart = false

    var plan: AgentPlan? {
        guard let steps, !steps.isEmpty, steps.contains(where: { $0.status != .completed }) else { return nil }
        return AgentPlan(steps: steps)
    }

    mutating func apply(name: String, input: [String: Any]) {
        switch name {
        case "mcp__ccd_turn__update_plan": applyUpdatePlan(input)
        case "mcp__ccd_turn__wrap_up": steps = steps?.map { AgentPlan.Step(title: $0.title, status: .completed) }
        case "TodoWrite": steps = (input["todos"] as? [[String: Any]])?.compactMap(Self.todo)
        case "TaskCreate": applyTaskCreate(input)
        case "TaskUpdate": applyTaskUpdate(input)
        default: break
        }
    }

    private mutating func applyUpdatePlan(_ input: [String: Any]) {
        if let items = input["items"] as? [[String: Any]] {
            steps = items.compactMap { item in
                guard let title = item["content"] as? String else { return nil }
                return AgentPlan.Step(title: title, status: Self.status(item["status"]))
            }
            return
        }
        guard steps != nil else { return isMissingStart = true }
        for number in input["done"] as? [Int] ?? [] { setStatus(.completed, at: number - 1) }
        if input["advance"] as? Bool == true { advance() }
        if let start = input["start"] as? Int { setStatus(.inProgress, at: start - 1) }
    }

    private mutating func advance() {
        guard var current = steps else { return }
        if let index = current.firstIndex(where: { $0.status == .inProgress }) { current[index].status = .completed }
        if let next = current.firstIndex(where: { $0.status == .pending }) { current[next].status = .inProgress }
        steps = current
    }

    private mutating func applyTaskCreate(_ input: [String: Any]) {
        guard let subject = input["subject"] as? String else { return }
        steps = (steps ?? []) + [AgentPlan.Step(title: subject, status: .pending)]
    }

    private mutating func applyTaskUpdate(_ input: [String: Any]) {
        guard let id = (input["taskId"] as? String).flatMap(Int.init) ?? input["taskId"] as? Int else { return }
        guard let current = steps, current.indices.contains(id - 1) else { return isMissingStart = true }
        if let status = input["status"] as? String { setStatus(status == "deleted" ? .completed : Self.status(status), at: id - 1) }
        if let subject = input["subject"] as? String { steps?[id - 1].title = subject }
    }

    private mutating func setStatus(_ status: AgentPlan.Status, at index: Int) {
        guard let current = steps, current.indices.contains(index) else { return }
        steps?[index].status = status
    }

    /// TodoWrite names the step in progress with its present-tense `activeForm`.
    private static func todo(_ item: [String: Any]) -> AgentPlan.Step? {
        guard let content = item["content"] as? String else { return nil }
        let status = status(item["status"])
        let title = status == .inProgress ? (item["activeForm"] as? String ?? content) : content
        return AgentPlan.Step(title: title, status: status)
    }

    private static func status(_ value: Any?) -> AgentPlan.Status {
        (value as? String).flatMap(AgentPlan.Status.init(rawValue:)) ?? .pending
    }
}
