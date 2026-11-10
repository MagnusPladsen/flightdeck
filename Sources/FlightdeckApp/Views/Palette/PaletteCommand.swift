import MonitorCore
import SwiftUI

/// One thing the command palette can do.
struct PaletteCommand: Identifiable {
    enum Group: String {
        case ask = "Ask"
        case pages = "Go to"
        case agents = "Agents"
        case servers = "Dev servers"
        case worktrees = "Worktrees"
        case actions = "Actions"
    }

    var id: String
    var title: String
    var subtitle: String?
    var symbol: String
    var group: Group
    var run: () -> Void

    var searchText: String { [title, subtitle].compactMap { $0 }.joined(separator: " ") }
}

/// Builds the palette's commands from what the dashboard knows right now.
@MainActor
struct PaletteCommandSource {
    var store: MonitorStore
    var navigation: DashboardNavigation
    var asker: ClaudeAsker
    var startNewAgent: () -> Void

    func commands(matching query: String) -> [PaletteCommand] {
        let all = pages + agents + servers + worktrees + actions
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        let ranked = all.compactMap { command in FuzzyMatch.score(trimmed, in: command.searchText).map { (command, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        return ranked + [ask(trimmed)]
    }

    private func ask(_ question: String) -> PaletteCommand {
        PaletteCommand(id: "ask", title: "Ask Claude: \(question)", subtitle: "About your agents, ports and usage", symbol: "sparkle", group: .ask) {
            asker.ask(question, store: store)
        }
    }

    private var pages: [PaletteCommand] {
        let destinations: [(DashboardDestination, String, String)] = DashboardPage.allCases.map { (.page($0), $0.title, $0.symbolName) }
            + [(.office, "Office", "gamecontroller"), (.achievements, "Achievements", "trophy"), (.settings, "Settings", "gearshape")]
        return destinations.map { destination, title, symbol in
            PaletteCommand(id: "page:\(title)", title: title, subtitle: "Page", symbol: symbol, group: .pages) { navigation.destination = destination }
        }
    }

    private var agents: [PaletteCommand] {
        store.agents.map { agent in
            PaletteCommand(id: "agent:\(agent.pid)", title: "\(agent.displayName)", subtitle: "\(agent.tool.displayName) · \(agent.state.label) · open its terminal",
                           symbol: "terminal", group: .agents) { store.openTerminal(for: agent) }
        }
    }

    private var servers: [PaletteCommand] {
        store.devServers.map { port in
            PaletteCommand(id: "port:\(port.id)", title: "localhost:\(port.port)", subtitle: "\(port.project?.name ?? port.processName) · open in the browser",
                           symbol: "globe", group: .servers) { store.openInBrowser(port: port.port) }
        }
    }

    private var worktrees: [PaletteCommand] {
        store.worktreeOverview.worktrees.map { worktree in
            PaletteCommand(id: "worktree:\(worktree.path)", title: worktree.branch ?? (worktree.path as NSString).lastPathComponent,
                           subtitle: "\(worktree.repositoryName) · open in the editor", symbol: "arrow.triangle.branch", group: .worktrees) {
                store.openInEditor(worktree.path)
            }
        }
    }

    private var actions: [PaletteCommand] {
        var actions = [
            PaletteCommand(id: "new-agent", title: "New agent…", subtitle: "Start an agent in a repository or new worktree", symbol: "play.circle", group: .actions, run: startNewAgent),
            PaletteCommand(id: "refresh", title: "Refresh now", subtitle: nil, symbol: "arrow.clockwise", group: .actions) { Task { await store.refreshAll() } },
            alertsCommand,
        ]
        if let track = store.nowPlaying.track, store.nowPlaying.isVisible {
            actions += [
                PaletteCommand(id: "play-pause", title: track.isPlaying ? "Pause music" : "Play music", subtitle: track.title, symbol: track.isPlaying ? "pause.fill" : "play.fill",
                               group: .actions) { store.nowPlaying.send(.togglePlayPause) },
                PaletteCommand(id: "next-track", title: "Next track", subtitle: track.title, symbol: "forward.fill", group: .actions) { store.nowPlaying.send(.nextTrack) },
                PaletteCommand(id: "previous-track", title: "Previous track", subtitle: track.title, symbol: "backward.fill", group: .actions) { store.nowPlaying.send(.previousTrack) },
            ]
        }
        return actions
    }

    private var alertsCommand: PaletteCommand {
        if store.settings.alertsPausedUntil != nil {
            return PaletteCommand(id: "alerts", title: "Resume alerts", subtitle: nil, symbol: "bell", group: .actions) { store.resumeAlerts() }
        }
        return PaletteCommand(id: "alerts", title: "Pause alerts for an hour", subtitle: nil, symbol: "bell.slash", group: .actions) {
            store.pauseAlerts(until: Date().addingTimeInterval(3600))
        }
    }
}
