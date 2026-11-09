import AppKit
import MonitorCore

/// Brings an agent's own terminal to the front: the exact Ghostty, iTerm2 or Terminal tab, or tmux
/// pane, by matching the agent's tty; for any other host, the app the agent runs under.
enum AgentTerminalFocuser {
    /// Returns false when the agent's terminal couldn't be found, so the caller can fall back.
    static func focus(agentPID: Int32) async -> Bool {
        let outcome = await Task.detached { focusTerminal(ofPID: agentPID) }.value
        switch outcome {
        case .focused: return true
        case .notFound: return false
        case .activate(let bundlePath): return await activateApp(bundlePath: bundlePath)
        }
    }

    private enum Outcome {
        case focused
        case notFound
        case activate(bundlePath: String)
    }

    private static func focusTerminal(ofPID pid: Int32) -> Outcome {
        guard let terminal = TerminalShell.terminals(ofPIDs: [pid]).first else { return .notFound }
        if terminal.host == .tmux {
            guard let clientPID = selectTmuxPane(tty: terminal.tty) else { return .notFound }
            return focusTerminal(ofPID: clientPID)
        }
        if let tty = terminal.tty, runFocusScript(for: terminal.host, tty: tty) { return .focused }
        return terminal.appBundlePath.map { .activate(bundlePath: $0) } ?? .notFound
    }

    private static func runFocusScript(for host: TerminalHost, tty: String) -> Bool {
        guard let script = TerminalFocusScript.source(for: host, tty: tty) else { return false }
        return TerminalShell.runAppleScript(script) == TerminalFocusScript.foundResult
    }

    /// Shows the agent's pane in a tmux client and returns that client's pid, whose terminal is focused next.
    private static func selectTmuxPane(tty: String?) -> Int32? {
        guard let tty,
              let pane = TmuxTargets.pane(forTTY: tty, in: TmuxTargets.parsePanes(TerminalShell.tmux(TmuxTargets.paneFormat))),
              let client = TmuxTargets.client(showing: pane, among: TmuxTargets.parseClients(TerminalShell.tmux(TmuxTargets.clientFormat)))
        else { return nil }
        if client.sessionName != pane.sessionName { _ = TerminalShell.tmux(["switch-client", "-c", client.tty, "-t", pane.sessionName]) }
        _ = TerminalShell.tmux(["select-window", "-t", pane.windowID])
        _ = TerminalShell.tmux(["select-pane", "-t", pane.paneID])
        return client.pid
    }

    /// Only a running app with a user interface counts; a daemon living in the bundle can't be shown.
    @MainActor
    private static func activateApp(bundlePath: String) -> Bool {
        let bundleURL = URL(fileURLWithPath: bundlePath).standardizedFileURL
        let app = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL == bundleURL && $0.activationPolicy == .regular
        }
        return app?.activate() ?? false
    }
}
