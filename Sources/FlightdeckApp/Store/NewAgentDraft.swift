import Foundation
import MonitorCore

/// Where a "New agent" action was started from: a repository, a worktree in it, or neither.
struct NewAgentRequest: Identifiable {
    let id = UUID()
    var repositoryRoot: String?
    /// Nil starts with a new worktree.
    var folder: String?
}

/// What the "New agent" sheet has picked so far.
struct NewAgentDraft {
    var repositoryRoot: String
    /// Nil adds a new worktree for `branch`.
    var folder: String?
    var branch = ""
    var tool: AgentTool
    var prompt = ""

    init(request: NewAgentRequest, repositoryRoots: [String], defaultAgent: AgentTool) {
        repositoryRoot = request.repositoryRoot ?? repositoryRoots.first ?? ""
        folder = request.folder
        tool = AgentLaunchCommand.launchableTools.contains(defaultAgent) ? defaultAgent : .claude
    }

    var isNewWorktree: Bool { folder == nil }

    func plan(worktrees: [Worktree], location: WorktreeLocation) -> Result<AgentLaunchPlan, AgentLaunchError> {
        AgentLaunchPlanner.plan(tool: tool, repositoryRoot: repositoryRoot, folder: folder ?? repositoryRoot, newBranch: isNewWorktree ? branch : nil,
                                prompt: prompt, worktrees: worktrees, location: location)
    }
}
