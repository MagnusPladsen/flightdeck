import Foundation

/// The shell command that runs a server's original argv again in its folder, recording its output to a log.
public enum ServerRelaunch {
    private static let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./=:@%+,")

    /// Argv that can't be typed back: empty, multi-line, or rewritten into a process title such as `next-server (v15.0.0)`.
    public static func isRelaunchable(_ arguments: [String]) -> Bool {
        guard let executable = arguments.first, !executable.isEmpty, !executable.contains(" ") else { return false }
        return !arguments.contains { $0.contains("\n") || $0.contains("\r") || $0.contains("\0") }
    }

    /// Single-quotes anything that isn't plainly safe, so the shell passes each argument through unchanged.
    public static func quote(_ argument: String) -> String {
        if !argument.isEmpty, argument.unicodeScalars.allSatisfy(safeCharacters.contains) { return argument }
        return ShellQuoting.quote(argument)
    }

    public static func commandLine(_ arguments: [String]) -> String {
        arguments.map(quote).joined(separator: " ")
    }

    /// `script` keeps the server on a real terminal, so colours and key shortcuts still work, while copying its output to the log.
    public static func shellCommand(arguments: [String], logPath: String) -> String {
        "/usr/bin/script -q -F \(quote(logPath)) \(commandLine(arguments))"
    }

    public static func logFileName(for id: ServerIdentity) -> String {
        let folderName = URL(fileURLWithPath: id.folder).lastPathComponent
        let safeName = String(folderName.unicodeScalars.map { safeCharacters.contains($0) && $0 != "/" ? Character($0) : "_" })
        return "\(safeName)-\(id.port).log"
    }
}
