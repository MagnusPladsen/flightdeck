import AppKit
import MonitorCore

/// Opens a new Ghostty, iTerm2 or Terminal tab, or tmux window, running an agent, adding its worktree first when asked.
enum AgentLauncher {
    /// Returns what went wrong, or nil once the terminal opened.
    static func launch(_ plan: AgentLaunchPlan, choice: LaunchTerminalChoice, agentPIDs: [Int32]) async -> AgentLaunchError? {
        let outcome = await Task.detached { run(plan, choice: choice, agentPIDs: agentPIDs) }.value
        switch outcome {
        case .failure(let error): return error
        case .success(let tmuxClientPID):
            if let tmuxClientPID { _ = await AgentTerminalFocuser.focus(agentPID: tmuxClientPID) }
            return nil
        }
    }

    private static func run(_ plan: AgentLaunchPlan, choice: LaunchTerminalChoice, agentPIDs: [Int32]) -> Result<Int32?, AgentLaunchError> {
        if case .newWorktree(let branch, let path) = plan.target, case .failure(let error) = WorktreeCreator().create(branch: branch, at: path, in: plan.repositoryRoot) {
            return .failure(error)
        }
        return TerminalCommandLauncher.run(plan.command, in: plan.folder, choice: choice, agentPIDs: agentPIDs)
    }
}
