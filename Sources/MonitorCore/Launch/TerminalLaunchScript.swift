import Foundation

/// AppleScript and command arguments that open a new terminal tab or window running a command
/// in a folder. Each script returns "launched" so callers can tell it worked.
public enum TerminalLaunchScript {
    public static let launchedResult = "launched"

    public static func appleScript(for terminal: LaunchTerminal, folder: String, command: String) -> String? {
        switch terminal {
        case .ghostty: ghostty(folder: folder, command: command)
        case .iTerm: iTerm(typing: AgentLaunchCommand.inFolder(folder, run: command))
        case .terminalApp: terminalApp(typing: AgentLaunchCommand.inFolder(folder, run: command))
        case .tmux: nil
        }
    }

    /// Ghostty before 1.3 has no AppleScript: a new instance starts in the folder and types the command.
    public static func ghosttyOpenArguments(folder: String, command: String) -> [String] {
        ["-na", "Ghostty.app", "--args", "--working-directory=\(folder)", "--input=raw:\(zigEscaped(command))\\n"]
    }

    /// `tmux new-window`, printing the new pane's id and session for `tmuxNewWindow(fromOutput:)`.
    public static func tmuxNewWindowArguments(folder: String, name: String) -> [String] {
        ["new-window", "-P", "-F", "#{pane_id}\t#{session_name}", "-c", folder, "-n", name]
    }

    public static func tmuxNewWindow(fromOutput output: String) -> (pane: String, session: String)? {
        let fields = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t", maxSplits: 1).map(String.init)
        guard fields.count == 2, fields[0].hasPrefix("%") else { return nil }
        return (fields[0], fields[1])
    }

    /// Types the command literally into the pane, then presses Return.
    public static func tmuxTypeArguments(pane: String, command: String) -> [[String]] {
        [["send-keys", "-t", pane, "-l", command], ["send-keys", "-t", pane, "Enter"]]
    }

    private static func ghostty(folder: String, command: String) -> String {
        """
        tell application id "com.mitchellh.ghostty"
            activate
            set config to new surface configuration
            set initial working directory of config to \(ShellQuoting.appleScriptLiteral(folder))
            set initial input of config to \(ShellQuoting.appleScriptLiteral(command)) & linefeed
            if (count of windows) is 0 then
                new window with configuration config
            else
                new tab in front window with configuration config
            end if
            return "\(launchedResult)"
        end tell
        """
    }

    private static func iTerm(typing line: String) -> String {
        """
        tell application id "com.googlecode.iterm2"
            activate
            if (count of windows) is 0 then
                set targetWindow to (create window with default profile)
            else
                set targetWindow to current window
                tell targetWindow to create tab with default profile
            end if
            tell current session of targetWindow to write text \(ShellQuoting.appleScriptLiteral(line))
            return "\(launchedResult)"
        end tell
        """
    }

    private static func terminalApp(typing line: String) -> String {
        """
        tell application id "com.apple.Terminal"
            activate
            do script \(ShellQuoting.appleScriptLiteral(line))
            return "\(launchedResult)"
        end tell
        """
    }

    /// Ghostty reads `raw:` input as a Zig string literal.
    private static func zigEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
