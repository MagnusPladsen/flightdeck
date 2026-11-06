import Foundation

/// Decides which agents deserve an alert: those that just started waiting on the user.
public enum AgentAlerts {
    public static let waitingStates: Set<AgentState> = [.needsApproval, .yourTurn, .possiblyStuck]

    /// Agents whose state moved into one of `states` since the previous poll, one per folder.
    /// With no previous poll nothing is new, so launching the app doesn't alert on old sessions.
    public static func newlyWaiting(previous: [AgentSession]?, current: [AgentSession], states: Set<AgentState>, tools: Set<AgentTool>) -> [AgentSession] {
        guard let previous else { return [] }
        let previousStates = Dictionary(previous.map { ($0.pid, $0.state) }, uniquingKeysWith: { first, _ in first })
        var alertedFolders: Set<String> = []
        return current.filter { agent in
            guard states.contains(agent.state), tools.contains(agent.tool), previousStates[agent.pid] != agent.state else { return false }
            return alertedFolders.insert(agent.workingDirectory).inserted
        }
    }

    /// Folders that had an agent waiting and no longer do, so their alerts can be withdrawn.
    public static func stoppedWaiting(previous: [AgentSession]?, current: [AgentSession]) -> Set<String> {
        let waitingBefore = Set((previous ?? []).filter { waitingStates.contains($0.state) }.map(\.workingDirectory))
        let waitingNow = Set(current.filter { waitingStates.contains($0.state) }.map(\.workingDirectory))
        return waitingBefore.subtracting(waitingNow)
    }
}
