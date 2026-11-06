import Foundation

/// Picks the next agent waiting on the user, longest-waiting first, for the next-agent hotkey.
public enum NeedsYouCycle {
    /// Returns the waiting agent after `previousPID` in waiting order, wrapping around.
    /// Starts at the longest-waiting agent when `previousPID` is nil or no longer waiting.
    public static func next(after previousPID: Int32?, among agents: [AgentSession]) -> AgentSession? {
        let waiting = waitingInOrder(agents)
        guard let previousPID, let index = waiting.firstIndex(where: { $0.pid == previousPID }) else { return waiting.first }
        return waiting[(index + 1) % waiting.count]
    }

    /// Oldest activity first; pid breaks ties so the order stays put between presses.
    static func waitingInOrder(_ agents: [AgentSession]) -> [AgentSession] {
        agents
            .filter { AgentAlerts.waitingStates.contains($0.state) }
            .sorted { lhs, rhs in
                let left = lhs.lastActivity ?? .distantPast
                let right = rhs.lastActivity ?? .distantPast
                return left == right ? lhs.pid < rhs.pid : left < right
            }
    }
}
