import Foundation

/// Two or more active agents working in the same checkout, where their edits and builds can collide.
public struct CheckoutClash: Sendable, Hashable {
    public var checkout: String
    /// The other agents in the checkout.
    public var otherPIDs: [Int32]
    /// Files this agent and another one both changed, relative to the checkout.
    public var sharedFiles: [String]

    public init(checkout: String, otherPIDs: [Int32], sharedFiles: [String]) {
        self.checkout = checkout
        self.otherPIDs = otherPIDs
        self.sharedFiles = sharedFiles
    }
}

public enum CheckoutClashFinder {
    /// Agents that are not idle and share a checkout with another such agent, keyed by pid.
    /// The checkout is the repository root the agent's changes are measured in, or its folder outside git.
    public static func clashes(among agents: [AgentSession], changes: [Int32: AgentChanges]) -> [Int32: CheckoutClash] {
        let active = agents.filter { $0.state != .idle }
        let byCheckout = Dictionary(grouping: active) { changes[$0.pid]?.baseline.repositoryRoot ?? $0.workingDirectory }
        var clashes: [Int32: CheckoutClash] = [:]
        for (checkout, group) in byCheckout where group.count > 1 {
            for agent in group {
                let others = group.filter { $0.pid != agent.pid }
                clashes[agent.pid] = CheckoutClash(checkout: checkout, otherPIDs: others.map(\.pid).sorted(),
                                                   sharedFiles: sharedFiles(of: agent, with: others, changes: changes))
            }
        }
        return clashes
    }

    private static func sharedFiles(of agent: AgentSession, with others: [AgentSession], changes: [Int32: AgentChanges]) -> [String] {
        let mine = Set(changes[agent.pid]?.files.map(\.path) ?? [])
        let theirs = Set(others.flatMap { changes[$0.pid]?.files.map(\.path) ?? [] })
        return mine.intersection(theirs).sorted()
    }
}
