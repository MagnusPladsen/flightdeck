import Foundation

/// One line of `ps -A -o pid=,ppid=,tty=,comm=`.
public struct ProcessTableRow: Sendable, Equatable {
    public var pid: Int32
    public var parentPID: Int32
    /// Device path such as `/dev/ttys004`; nil for processes without a terminal.
    public var tty: String?
    public var command: String

    public init(pid: Int32, parentPID: Int32, tty: String?, command: String) {
        self.pid = pid
        self.parentPID = parentPID
        self.tty = tty
        self.command = command
    }

    public static let psArguments = ["-A", "-o", "pid=,ppid=,tty=,comm="]

    public static func parse(psOutput: String) -> [Int32: ProcessTableRow] {
        let rows = psOutput.split(separator: "\n").compactMap(parse(line:))
        return Dictionary(rows.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func parse(line: Substring) -> ProcessTableRow? {
        let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard fields.count == 4, let pid = Int32(fields[0]), let parentPID = Int32(fields[1]) else { return nil }
        let tty = fields[2] == "??" ? nil : "/dev/" + fields[2]
        return ProcessTableRow(pid: pid, parentPID: parentPID, tty: tty, command: String(fields[3]).trimmingCharacters(in: .whitespaces))
    }
}

/// The app an agent's terminal lives in, as far as Flightdeck can reach into it.
public enum TerminalHost: Sendable, Equatable {
    case ghostty
    case iTerm
    case terminalApp
    /// A tmux pane; the tmux client shows it in some other terminal.
    case tmux
    /// Any other app (kitty, VS Code, the Claude desktop app): Flightdeck can only bring it forward.
    case otherApp
}

public struct AgentTerminal: Sendable, Equatable {
    public var host: TerminalHost
    public var tty: String?
    /// The app bundle the agent runs under, such as `/Applications/kitty.app`, to activate when the
    /// terminal itself can't be focused. Helpers and daemons inside a bundle resolve to the bundle.
    public var appBundlePath: String?

    public init(host: TerminalHost, tty: String?, appBundlePath: String?) {
        self.host = host
        self.tty = tty
        self.appBundlePath = appBundlePath
    }
}

/// Walks an agent's parent processes to find the terminal it runs in.
public enum AgentTerminalLocator {
    private static let launchdPID: Int32 = 1
    private static let maxDepth = 32
    private static let scriptableHosts: [(String, TerminalHost)] = [
        ("/Ghostty.app/", .ghostty),
        ("/iTerm.app/", .iTerm),
        ("/Terminal.app/", .terminalApp),
    ]

    public static func locate(pid: Int32, in table: [Int32: ProcessTableRow]) -> AgentTerminal? {
        guard let agent = table[pid] else { return nil }
        let ancestors = ancestors(of: agent, in: table)
        let appBundlePath = ancestors.lazy.compactMap { bundlePath(of: $0.command) }.last
        if let host = ancestors.lazy.compactMap(scriptableHost).first {
            return AgentTerminal(host: host, tty: agent.tty, appBundlePath: appBundlePath)
        }
        return appBundlePath.map { AgentTerminal(host: .otherApp, tty: agent.tty, appBundlePath: $0) }
    }

    /// Parents from nearest to furthest, stopping before launchd.
    static func ancestors(of row: ProcessTableRow, in table: [Int32: ProcessTableRow]) -> [ProcessTableRow] {
        var chain: [ProcessTableRow] = []
        var current = row
        while current.parentPID > launchdPID, chain.count < maxDepth, let parent = table[current.parentPID] {
            chain.append(parent)
            current = parent
        }
        return chain
    }

    private static func scriptableHost(_ row: ProcessTableRow) -> TerminalHost? {
        if (row.command as NSString).lastPathComponent == "tmux" { return .tmux }
        return scriptableHosts.first { row.command.contains($0.0) }?.1
    }

    /// The outermost `.app` in an executable path, so a nested helper app maps to its parent app.
    static func bundlePath(of command: String) -> String? {
        guard command.contains(".app/Contents/MacOS/"), let range = command.range(of: ".app/") else { return nil }
        return String(command[..<range.lowerBound]) + ".app"
    }
}
