import Foundation

/// Whether to keep the Mac from idle sleeping while agents are busy, and how to say so.
public enum KeepAwake {
    public static let busyStates: Set<AgentState> = [.working, .possiblyStuck]

    public static func busyCount(in agents: [AgentSession]) -> Int {
        agents.filter { busyStates.contains($0.state) }.count
    }

    public static func shouldHoldAssertion(isEnabled: Bool, agents: [AgentSession]) -> Bool {
        isEnabled && busyCount(in: agents) > 0
    }

    /// "Keep awake" while off, "Keeping awake · 2 working" while holding, "Keep awake · idle" while waiting for work.
    public static func statusText(isEnabled: Bool, busyCount: Int) -> String {
        guard isEnabled else { return "Keep awake" }
        return busyCount > 0 ? "Keeping awake · \(busyCount) working" : "Keep awake · idle"
    }
}
