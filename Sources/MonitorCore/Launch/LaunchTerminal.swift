import Foundation

/// A terminal "New agent" can open a tab or window in.
public enum LaunchTerminal: String, CaseIterable, Codable, Sendable {
    case ghostty, iTerm, terminalApp, tmux

    public var title: String {
        switch self {
        case .ghostty: "Ghostty"
        case .iTerm: "iTerm2"
        case .terminalApp: "Terminal"
        case .tmux: "tmux (new window)"
        }
    }

    /// Nil for tmux, which runs inside whichever app shows its client.
    public var bundleID: String? {
        switch self {
        case .ghostty: "com.mitchellh.ghostty"
        case .iTerm: "com.googlecode.iterm2"
        case .terminalApp: "com.apple.Terminal"
        case .tmux: nil
        }
    }

    init?(host: TerminalHost) {
        switch host {
        case .ghostty: self = .ghostty
        case .iTerm: self = .iTerm
        case .terminalApp: self = .terminalApp
        case .tmux: self = .tmux
        case .otherApp: return nil
        }
    }
}

/// The terminal setting: one terminal, or whichever the user's agents already run in.
public enum LaunchTerminalChoice: String, CaseIterable, Codable, Sendable {
    case automatic, ghostty, iTerm, terminalApp, tmux

    public var terminal: LaunchTerminal? { LaunchTerminal(rawValue: rawValue) }

    public var title: String { terminal?.title ?? "Where my agents already run" }

    /// `available` holds the installed apps, plus tmux when a client is attached.
    /// Automatic picks the terminal of the first running agent that can be scripted, then
    /// Ghostty, iTerm2 and Terminal in that order.
    public func resolve(agentHosts: [TerminalHost], available: Set<LaunchTerminal>) -> LaunchTerminal? {
        if let terminal { return available.contains(terminal) ? terminal : nil }
        let fromAgents = agentHosts.compactMap(LaunchTerminal.init(host:)).first(where: available.contains)
        return fromAgents ?? [.ghostty, .iTerm, .terminalApp].first(where: available.contains)
    }
}
