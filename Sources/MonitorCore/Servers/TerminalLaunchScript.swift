import Foundation

/// AppleScript that opens a new tab in a terminal and runs a shell command there, so its output stays in view.
public enum TerminalLaunchScript {
    public static func source(for host: TerminalHost, command: String) -> String? {
        let literal = appleScriptLiteral(command)
        switch host {
        case .ghostty: return ghostty(literal)
        case .iTerm: return iTerm(literal)
        case .terminalApp: return terminalApp(literal)
        case .tmux, .otherApp: return nil
        }
    }

    static func appleScriptLiteral(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func ghostty(_ command: String) -> String {
        """
        tell application id "com.mitchellh.ghostty"
            activate
            set launchSettings to new surface configuration
            set initial input of launchSettings to \(command) & linefeed
            if (count of windows) is 0 then
                new window with configuration launchSettings
            else
                new tab in front window with configuration launchSettings
            end if
        end tell
        """
    }

    private static func iTerm(_ command: String) -> String {
        """
        tell application id "com.googlecode.iterm2"
            activate
            if (count of windows) is 0 then
                create window with default profile
            else
                tell current window to create tab with default profile
            end if
            tell current session of current window to write text \(command)
        end tell
        """
    }

    private static func terminalApp(_ command: String) -> String {
        """
        tell application id "com.apple.Terminal"
            activate
            do script \(command)
        end tell
        """
    }
}
