import Foundation
import MonitorCore

/// Display text for an agent session, shared by the hero, cards and search.
extension AgentSession {
    var displayName: String {
        project?.name ?? URL(fileURLWithPath: workingDirectory).lastPathComponent
    }

    var abbreviatedPath: String {
        (workingDirectory as NSString).abbreviatingWithTildeInPath
    }

    /// "⧉ worktree-name" for worktrees, "⎇ branch" for normal checkouts.
    var checkoutLabel: String? {
        guard let project else { return nil }
        if project.isWorktree { return "⧉ " + (project.worktreeName ?? project.branch ?? "worktree") }
        return project.branch.map { "⎇ " + $0 }
    }

    var isWorktree: Bool {
        project?.isWorktree == true
    }

    /// Falls back to the state when the agent's transcript can't be read (e.g. Codex).
    var actionLine: AgentAction {
        if let lastAction, !lastAction.detail.isEmpty { return lastAction }
        switch state {
        case .working: return AgentAction(verb: "Working", detail: "")
        case .needsApproval: return AgentAction(verb: "Waiting", detail: "for your approval")
        case .yourTurn: return AgentAction(verb: "Finished", detail: "waiting for your next prompt")
        case .possiblyStuck: return AgentAction(verb: "Stuck", detail: stuckReason?.summary ?? "")
        case .idle: return AgentAction(verb: "Idle", detail: "")
        }
    }

    /// CPU and memory of the agent and everything it started, e.g. "CPU 204% · 1.5 GB · 4 processes".
    var resourceText: String? {
        guard let resources else { return nil }
        let processes = resources.processCount == 1 ? "1 process" : "\(resources.processCount) processes"
        return "CPU \(Int(resources.cpuPercent.rounded()))% · \(Formatters.bytes(resources.memoryBytes)) · \(processes)"
    }

    func ageText(now: Date = Date()) -> String {
        guard let lastActivity else { return "—" }
        let elapsed = now.timeIntervalSince(lastActivity)
        return elapsed < 60 ? "now" : Formatters.duration(elapsed)
    }

    /// Several sessions in one folder read the same transcript, so they show as one card.
    static func grouped(_ sessions: [AgentSession]) -> [AgentGroup] {
        var groups: [AgentGroup] = []
        for session in sessions {
            if let index = groups.firstIndex(where: { $0.agent.tool == session.tool && $0.agent.workingDirectory == session.workingDirectory && $0.agent.state == session.state }) {
                groups[index].count += 1
            } else {
                groups.append(AgentGroup(agent: session, count: 1))
            }
        }
        return groups
    }

    var searchText: String {
        [displayName, workingDirectory, project?.branch ?? "", project?.worktreeName ?? "", tool.displayName, lastAction?.detail ?? ""]
            .joined(separator: " ")
            .lowercased()
    }
}

struct AgentGroup: Identifiable {
    var id: Int32 { agent.id }
    let agent: AgentSession
    var count: Int
}
