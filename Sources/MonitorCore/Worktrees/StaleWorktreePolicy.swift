import Foundation

/// Decides which worktrees "Clean up" may remove: clean, no agent inside, the branch merged or
/// never opened as a pull request, and no commit for at least `minimumAgeDays`.
public struct StaleWorktreePolicy: Sendable, Hashable {
    public var minimumAgeDays: Int

    public init(minimumAgeDays: Int) {
        self.minimumAgeDays = minimumAgeDays
    }

    public func isStale(_ worktree: Worktree, hasAgent: Bool, now: Date = Date()) -> Bool {
        guard !worktree.isMain, !worktree.isLocked, !worktree.status.isDirty, !hasAgent else { return false }
        guard isFinishedOrUnshared(worktree.pullRequest), let lastCommit = worktree.lastCommitDate else { return false }
        return now.timeIntervalSince(lastCommit) >= TimeInterval(minimumAgeDays) * 86_400
    }

    private func isFinishedOrUnshared(_ lookup: PullRequestLookup) -> Bool {
        switch lookup {
        case .unavailable, .none: true
        case .found(let pullRequest): pullRequest.state == .merged
        }
    }
}

/// Finds the agents running inside a worktree's folder.
public enum WorktreeAgentMatcher {
    /// Each agent belongs to the deepest worktree containing its folder, so an agent in a
    /// nested `.claude/worktrees/x` is not also counted against the main checkout.
    public static func agents(in worktrees: [Worktree], from agents: [AgentSession]) -> [String: [AgentSession]] {
        var result: [String: [AgentSession]] = [:]
        for agent in agents {
            let owner = worktrees
                .filter { contains($0.path, agent.workingDirectory) }
                .max { $0.path.count < $1.path.count }
            if let owner { result[owner.path, default: []].append(agent) }
        }
        return result
    }

    static func contains(_ root: String, _ path: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
