import Foundation
import MonitorCore
import Testing

struct AgentTerminalLocatorTests {
    private let psOutput = """
      1     0 ??       /sbin/launchd
    500     1 ??       /Applications/Ghostty.app/Contents/MacOS/ghostty
    501   500 ttys004  /usr/bin/login
    502   501 ttys004  -zsh
    503   502 ttys004  /opt/homebrew/bin/claude
    600     1 ??       /opt/homebrew/bin/tmux
    601   600 ttys007  -zsh
    602   601 ttys007  claude
    700     1 ??       /Applications/Claude.app/Contents/MacOS/Claude
    701   700 ??       /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper
    702   701 ??       /Users/me/Library/claude
    800     1 ??       /Applications/kitty.app/Contents/MacOS/kitty
    801   800 ttys009  /bin/zsh
    802   801 ttys009  codex
    900     1 ??       /usr/local/bin/orphan
    950     1 ??       /Applications/Superset.app/Contents/MacOS/Superset /x/pty-daemon.js
    951   950 ttys011  /bin/zsh
    952   951 ttys011  claude
    """

    private var table: [Int32: ProcessTableRow] { ProcessTableRow.parse(psOutput: psOutput) }

    @Test func parsesTTYAndCommandsWithSpaces() {
        #expect(table[503]?.tty == "/dev/ttys004")
        #expect(table[701]?.tty == nil)
        #expect(table[701]?.command == "/Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper")
    }

    @Test func findsScriptableTerminalWithAgentTTY() {
        #expect(AgentTerminalLocator.locate(pid: 503, in: table) == AgentTerminal(host: .ghostty, tty: "/dev/ttys004", appBundlePath: "/Applications/Ghostty.app"))
    }

    @Test func recognisesTmuxPanes() {
        #expect(AgentTerminalLocator.locate(pid: 602, in: table) == AgentTerminal(host: .tmux, tty: "/dev/ttys007", appBundlePath: nil))
    }

    @Test func fallsBackToOutermostApp() {
        #expect(AgentTerminalLocator.locate(pid: 702, in: table) == AgentTerminal(host: .otherApp, tty: nil, appBundlePath: "/Applications/Claude.app"))
        #expect(AgentTerminalLocator.locate(pid: 802, in: table) == AgentTerminal(host: .otherApp, tty: "/dev/ttys009", appBundlePath: "/Applications/kitty.app"))
    }

    @Test func daemonInsideABundleResolvesToTheApp() {
        #expect(AgentTerminalLocator.locate(pid: 952, in: table)?.appBundlePath == "/Applications/Superset.app")
    }

    @Test func returnsNilWithoutAnyApp() {
        #expect(AgentTerminalLocator.locate(pid: 900, in: table) == nil)
        #expect(AgentTerminalLocator.locate(pid: 12345, in: table) == nil)
    }
}

struct TmuxTargetsTests {
    @Test func matchesPaneAndMostRecentClient() throws {
        let panes = TmuxTargets.parsePanes("/dev/ttys007\twork\t@1\t%3\n/dev/ttys008\tother\t@2\t%4\n")
        let clients = TmuxTargets.parseClients("/dev/ttys004\t501\twork\t100\n/dev/ttys005\t520\twork\t200\n/dev/ttys006\t530\tother\t300\n")
        let pane = try #require(TmuxTargets.pane(forTTY: "/dev/ttys007", in: panes))
        #expect(pane.paneID == "%3")
        #expect(TmuxTargets.client(showing: pane, among: clients)?.pid == 520)
    }

    @Test func borrowsAnotherClientWhenSessionIsDetached() throws {
        let pane = try #require(TmuxTargets.parsePanes("/dev/ttys007\twork\t@1\t%3").first)
        let clients = TmuxTargets.parseClients("/dev/ttys006\t530\tother\t300")
        #expect(TmuxTargets.client(showing: pane, among: clients)?.pid == 530)
        #expect(TmuxTargets.client(showing: pane, among: []) == nil)
    }
}

struct TerminalFocusScriptTests {
    @Test func embedsTheTTY() throws {
        let script = try #require(TerminalFocusScript.source(for: .ghostty, tty: "/dev/ttys004"))
        #expect(script.contains("whose tty is \"/dev/ttys004\""))
        #expect(TerminalFocusScript.source(for: .iTerm, tty: "/dev/ttys004")?.contains("com.googlecode.iterm2") == true)
        #expect(TerminalFocusScript.source(for: .terminalApp, tty: "/dev/ttys004")?.contains("com.apple.Terminal") == true)
    }

    @Test func refusesAnythingButADevicePath() {
        #expect(TerminalFocusScript.source(for: .ghostty, tty: "/dev/ttys004\" & do shell script \"x") == nil)
        #expect(TerminalFocusScript.source(for: .otherApp, tty: "/dev/ttys004") == nil)
    }
}

struct NeedsYouCycleTests {
    private func agent(_ pid: Int32, _ state: AgentState, waitingSince seconds: TimeInterval) -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: "/code/\(pid)", project: nil, state: state, cpuPercent: 0, lastActivity: Date(timeIntervalSince1970: seconds))
    }

    private var agents: [AgentSession] {
        [agent(1, .yourTurn, waitingSince: 300), agent(2, .working, waitingSince: 50), agent(3, .needsApproval, waitingSince: 100), agent(4, .idle, waitingSince: 10)]
    }

    @Test func startsWithLongestWaiting() {
        #expect(NeedsYouCycle.next(after: nil, among: agents)?.pid == 3)
    }

    @Test func cyclesAndWraps() {
        #expect(NeedsYouCycle.next(after: 3, among: agents)?.pid == 1)
        #expect(NeedsYouCycle.next(after: 1, among: agents)?.pid == 3)
    }

    @Test func restartsWhenPreviousStoppedWaiting() {
        #expect(NeedsYouCycle.next(after: 2, among: agents)?.pid == 3)
    }

    @Test func nobodyWaiting() {
        #expect(NeedsYouCycle.next(after: nil, among: [agent(2, .working, waitingSince: 0)]) == nil)
    }
}

struct HotkeyShortcutTests {
    @Test func displaysInMenuOrder() {
        let shortcut = HotkeyShortcut(keyCode: 45, modifiers: [.command, .shift, .control], keyLabel: "N")
        #expect(shortcut.displayString == "⌃⇧⌘N")
        #expect(HotkeyShortcut.nextAgentDefault.displayString == "⌃⌥N")
    }

    @Test func requiresARealModifier() {
        #expect(!HotkeyShortcut(keyCode: 45, modifiers: [.shift], keyLabel: "N").isUsable)
        #expect(HotkeyShortcut.nextAgentDefault.isUsable)
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(HotkeyShortcut.nextAgentDefault)
        #expect(try JSONDecoder().decode(HotkeyShortcut.self, from: data) == .nextAgentDefault)
    }
}
