import AppKit
import MonitorCore

/// Runs a shell command in a folder in a new Ghostty, iTerm2 or Terminal tab, or a new tmux window.
enum TerminalCommandLauncher {
    /// Blocks while the terminal opens; call it off the main thread. On success, the pid of the tmux client to bring forward, if any.
    static func run(_ command: String, in folder: String, choice: LaunchTerminalChoice, agentPIDs: [Int32]) -> Result<Int32?, AgentLaunchError> {
        guard let terminal = choice.resolve(agentHosts: agentHosts(agentPIDs), available: availableTerminals()) else { return .failure(.noTerminal) }
        if terminal == .tmux { return openTmuxWindow(folder: folder, command: command) }
        return openTab(in: terminal, folder: folder, command: command) ? .success(nil) : .failure(.terminalFailed)
    }

    private static func openTab(in terminal: LaunchTerminal, folder: String, command: String) -> Bool {
        if let script = TerminalLaunchScript.appleScript(for: terminal, folder: folder, command: command) {
            if TerminalShell.runAppleScript(script) == TerminalLaunchScript.launchedResult { return true }
        }
        guard terminal == .ghostty else { return false }
        return CommandRunner.run("/usr/bin/open", TerminalLaunchScript.ghosttyOpenArguments(folder: folder, command: command)).exitCode == 0
    }

    /// Returns the pid of the client showing the new window's session, whose terminal is focused next.
    private static func openTmuxWindow(folder: String, command: String) -> Result<Int32?, AgentLaunchError> {
        let output = TerminalShell.tmux(TerminalLaunchScript.tmuxNewWindowArguments(folder: folder, name: (folder as NSString).lastPathComponent))
        guard let window = TerminalLaunchScript.tmuxNewWindow(fromOutput: output) else { return .failure(.terminalFailed) }
        TerminalLaunchScript.tmuxTypeArguments(pane: window.pane, command: command).forEach { _ = TerminalShell.tmux($0) }
        return .success(TmuxTargets.client(inSession: window.session, among: tmuxClients())?.pid)
    }

    private static func availableTerminals() -> Set<LaunchTerminal> {
        let installed = LaunchTerminal.allCases.filter { terminal in
            terminal.bundleID.map { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil } ?? !tmuxClients().isEmpty
        }
        return Set(installed)
    }

    private static func agentHosts(_ pids: [Int32]) -> [TerminalHost] {
        TerminalShell.terminals(ofPIDs: pids).map(\.host)
    }

    private static func tmuxClients() -> [TmuxTargets.Client] {
        TmuxTargets.parseClients(TerminalShell.tmux(TmuxTargets.clientFormat))
    }
}
