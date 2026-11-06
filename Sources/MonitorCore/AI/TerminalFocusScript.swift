import Foundation

/// AppleScript that brings the window and tab owning a tty to the front. Each script returns
/// "found" when it matched a terminal, so callers can fall back to just activating the app.
public enum TerminalFocusScript {
    public static let foundResult = "found"

    public static func source(for host: TerminalHost, tty: String) -> String? {
        guard isSafeTTY(tty) else { return nil }
        switch host {
        case .ghostty: return ghostty(tty: tty)
        case .iTerm: return iTerm(tty: tty)
        case .terminalApp: return terminalApp(tty: tty)
        case .tmux, .otherApp: return nil
        }
    }

    /// Only plain device paths go into a script, so nothing can break out of the string literal.
    static func isSafeTTY(_ tty: String) -> Bool {
        tty.range(of: #"^/dev/ttys?[0-9]+$"#, options: .regularExpression) != nil
    }

    private static func ghostty(tty: String) -> String {
        """
        tell application id "com.mitchellh.ghostty"
            set matches to (every terminal whose tty is "\(tty)")
            if (count of matches) is 0 then return ""
            focus (item 1 of matches)
            return "\(foundResult)"
        end tell
        """
    }

    private static func iTerm(tty: String) -> String {
        """
        tell application id "com.googlecode.iterm2"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if tty of aSession is "\(tty)" then
                            select aWindow
                            tell aTab to select
                            tell aSession to select
                            activate
                            return "\(foundResult)"
                        end if
                    end repeat
                end repeat
            end repeat
            return ""
        end tell
        """
    }

    private static func terminalApp(tty: String) -> String {
        """
        tell application id "com.apple.Terminal"
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    if tty of aTab is "\(tty)" then
                        set selected of aTab to true
                        set index of aWindow to 1
                        activate
                        return "\(foundResult)"
                    end if
                end repeat
            end repeat
            return ""
        end tell
        """
    }
}
