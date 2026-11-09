import Foundation

/// Quotes text for the places a launch command passes through: the user's shell and AppleScript.
public enum ShellQuoting {
    /// Single-quotes `text`, stepping out of the quotes for `'` and `\`, so sh, bash, zsh and
    /// fish all read it back unchanged and nothing inside is expanded.
    public static func quote(_ text: String) -> String {
        var quoted = "'"
        for character in text {
            switch character {
            case "'": quoted += #"'\''"#
            case "\\": quoted += #"'\\'"#
            default: quoted.append(character)
            }
        }
        return quoted + "'"
    }

    /// A double-quoted AppleScript string literal.
    public static func appleScriptLiteral(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Newlines, tabs and other control characters become spaces, so a typed command is one line.
    public static func singleLine(_ text: String) -> String {
        String(text.map { $0.unicodeScalars.allSatisfy { CharacterSet.controlCharacters.contains($0) } ? " " : $0 })
    }
}
