import Foundation
import MonitorCore

/// The process lookups, AppleScript and tmux calls shared by `AgentTerminalFocuser` and `TerminalCommandLauncher`.
/// All of them block, so call them off the main thread.
enum TerminalShell {
    /// The first AppleScript call can wait on the macOS Automation permission prompt.
    private static let scriptTimeout: TimeInterval = 30

    /// The terminals the processes run in, skipping those that can't be found.
    static func terminals(ofPIDs pids: [Int32]) -> [AgentTerminal] {
        let table = ProcessTableRow.parse(psOutput: CommandRunner.run("/bin/ps", ProcessTableRow.psArguments).output)
        return pids.compactMap { AgentTerminalLocator.locate(pid: $0, in: table) }
    }

    /// The script's output, trimmed.
    static func runAppleScript(_ script: String) -> String {
        CommandRunner.run("/usr/bin/osascript", ["-e", script], timeout: scriptTimeout).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tmux(_ arguments: [String]) -> String {
        CommandRunner.run("/usr/bin/env", ["tmux"] + arguments).output
    }
}
