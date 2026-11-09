import Foundation

/// Everything needed to start an agent: where, in which worktree, and the command to type.
public struct AgentLaunchPlan: Sendable, Hashable {
    public enum Target: Sendable, Hashable {
        case existing(path: String)
        /// A worktree to add first with `git worktree add`.
        case newWorktree(branch: String, path: String)
    }

    public var tool: AgentTool
    public var repositoryRoot: String
    public var target: Target
    /// The agent command without the folder, e.g. `claude 'fix the login test'`.
    public var command: String

    public var folder: String {
        switch target {
        case .existing(let path), .newWorktree(_, let path): path
        }
    }
}

public enum AgentLaunchError: Error, Equatable, Sendable {
    case unsupportedTool
    case invalidBranch(String)
    case branchCheckedOut(path: String)
    case folderTaken(path: String)
    case worktreeFailed(String)
    case noTerminal
    case terminalFailed

    public var message: String {
        switch self {
        case .unsupportedTool: "Flightdeck can only start Claude Code and Codex."
        case .invalidBranch(let reason): reason
        case .branchCheckedOut(let path): "That branch is already checked out in \((path as NSString).abbreviatingWithTildeInPath)."
        case .folderTaken(let path): "\((path as NSString).abbreviatingWithTildeInPath) already exists."
        case .worktreeFailed(let detail): "git worktree add failed: \(detail)"
        case .noTerminal: "No supported terminal found. Install Ghostty, iTerm2 or Terminal, or attach a tmux client."
        case .terminalFailed: "The terminal didn't open. Check that Flightdeck may control it in System Settings › Privacy & Security › Automation."
        }
    }
}

/// Turns what the user picked in "New agent" into a plan, catching mistakes before git runs.
public enum AgentLaunchPlanner {
    /// `newBranch` nil runs in `folder`; otherwise a new worktree for that branch goes where `location` says.
    public static func plan(tool: AgentTool, repositoryRoot: String, folder: String, newBranch: String?, prompt: String?,
                            worktrees: [Worktree], location: WorktreeLocation) -> Result<AgentLaunchPlan, AgentLaunchError> {
        guard let command = AgentLaunchCommand.command(for: tool, prompt: prompt) else { return .failure(.unsupportedTool) }
        let plan = AgentLaunchPlan(tool: tool, repositoryRoot: repositoryRoot, target: .existing(path: folder), command: command)
        guard let newBranch = newBranch?.trimmingCharacters(in: .whitespaces) else { return .success(plan) }
        return newWorktreeTarget(branch: newBranch, repositoryRoot: repositoryRoot, worktrees: worktrees, location: location).map { target in
            var planned = plan
            planned.target = target
            return planned
        }
    }

    static func newWorktreeTarget(branch: String, repositoryRoot: String, worktrees: [Worktree], location: WorktreeLocation) -> Result<AgentLaunchPlan.Target, AgentLaunchError> {
        if let problem = BranchNameValidator.problem(with: branch) { return .failure(.invalidBranch(problem)) }
        let siblings = worktrees.filter { $0.repositoryRoot == repositoryRoot }
        if let checkedOut = siblings.first(where: { $0.branch == branch }) { return .failure(.branchCheckedOut(path: checkedOut.path)) }
        let path = location.path(for: BranchNameValidator.folderName(for: branch), repositoryRoot: repositoryRoot, existingWorktrees: siblings.map(\.path))
        if siblings.contains(where: { $0.path == path }) { return .failure(.folderTaken(path: path)) }
        return .success(.newWorktree(branch: branch, path: path))
    }
}
