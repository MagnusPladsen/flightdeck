import AppKit
import Foundation
import MonitorCore
import Observation

/// App-wide live state. Polls the engine on three cadences so the menu bar stays cheap.
@MainActor
@Observable
final class MonitorStore {
    static let historyLength = 90

    private(set) var snapshot: SystemSnapshot?
    private(set) var cpuHistory: [Double] = []
    private(set) var memoryHistory: [Double] = []
    private(set) var networkInHistory: [Double] = []
    private(set) var networkOutHistory: [Double] = []
    private(set) var ports: [ListeningPort] = []
    private(set) var agents: [AgentSession] = []
    private(set) var usage: [ProviderUsage] = []
    private(set) var usageHistory = UsageHistory()
    private(set) var widgetResults: [UUID: CustomWidgetResult] = [:]
    /// Nil while spend tracking is off or before its first read.
    private(set) var spend: SpendReport?

    let settings: AppSettings
    let notifier = AgentNotifier()
    let worktreeOverview: WorktreeOverview
    let nowPlaying = NowPlayingMonitor()
    private let engine: MonitorEngine
    private var pollingTasks: [Task<Void, Never>] = []
    private var widgetLastRun: [UUID: Date] = [:]
    /// Agents cleared from "Your turn", with the activity time they were cleared at.
    private var clearedTurns: [Int32: Date] = [:]
    private var hasCollectedAgents = false
    private let nextAgentHotkey = GlobalHotkey()
    /// The agent the next-agent hotkey focused last, so repeated presses move on to the next one.
    private var lastCycledAgentPID: Int32?
    /// True when another app already owns the chosen next-agent shortcut.
    private(set) var isNextAgentHotkeyTaken = false
    private var alertBatcher = AlertBatcher()

    init(settings: AppSettings) {
        self.settings = settings
        let engine = MonitorEngine()
        self.engine = engine
        worktreeOverview = WorktreeOverview(engine: engine, settings: settings)
        notifier.openTerminal = { [weak self] pid, folder in
            guard let self else { return }
            if let agent = agents.first(where: { $0.pid == pid }) { openTerminal(for: agent) } else { openInTerminal(folder) }
        }
    }

    var devServers: [ListeningPort] { ports.filter(\.isDevServer) }
    var visiblePorts: [ListeningPort] { settings.showSystemPorts ? ports : devServers }
    var activeAgents: [AgentSession] { agents.filter { $0.state != .idle } }
    var visibleAgents: [AgentSession] { settings.showIdleAgents ? agents : activeAgents }
    var staleWorktrees: [Worktree] { worktreeOverview.staleWorktrees(agents: agents) }

    /// Checkouts that servers and agents run in; their repositories feed the worktree overview.
    var projectFolders: [String] {
        ports.compactMap(\.project?.rootPath) + agents.compactMap { $0.project?.rootPath ?? $0.workingDirectory }
    }

    /// The agent whose limits the default limit resources show: the default agent when it has
    /// limit data, otherwise Claude Code, then Codex, then any other agent that reports limits.
    var limitsAgent: AgentTool {
        let preferred = settings.defaultAgent
        let fallbacks = [preferred, .claude, .codex] + AgentTool.allCases
        return fallbacks.first { usage(for: $0)?.windows.isEmpty == false } ?? preferred
    }

    func usage(for tool: AgentTool) -> ProviderUsage? {
        usage.first { $0.tool == tool }
    }

    func start() {
        guard pollingTasks.isEmpty else { return }
        applyNextAgentHotkey()
        nowPlaying.setUsesSystemAudio(settings.nowPlayingUsesSystemAudio)
        if DemoData.isEnabled { return loadDemo() }
        if settings.nowPlayingEnabled { nowPlaying.start() }
        if settings.alertsEnabled { Task { await notifier.requestAuthorization() } }
        pollingTasks = [
            poll(every: .seconds(2)) { await $0.refreshSystem() },
            poll(every: .seconds(5)) { await $0.refreshPortsAndAgents() },
            poll(every: .seconds(60)) { await $0.refreshUsage() },
            poll(every: .seconds(60)) { await $0.refreshSpend() },
            poll(every: .seconds(5)) { await $0.refreshDueWidgets() },
            poll(every: .seconds(30)) { await $0.refreshProjectCache() },
            poll(every: .seconds(60)) { await $0.refreshWorktrees() },
        ]
    }

    private func poll(every interval: Duration, _ work: @escaping @MainActor (MonitorStore) async -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await work(self)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func refreshSystem() async {
        let engine = engine
        let snapshot = await Task.detached { engine.collectSystem() }.value
        self.snapshot = snapshot
        append(snapshot.cpu.total, to: &cpuHistory)
        append(snapshot.memory.usedFraction, to: &memoryHistory)
        append(snapshot.network.bytesInPerSecond, to: &networkInHistory)
        append(snapshot.network.bytesOutPerSecond, to: &networkOutHistory)
    }

    func refreshPortsAndAgents() async {
        let engine = engine
        let processes = snapshot?.processes ?? []
        async let ports = Task.detached { engine.collectPorts() }.value
        async let agents = Task.detached { engine.collectAgents(from: processes) }.value
        let collected: [AgentSession]
        (self.ports, collected) = await (ports, agents)
        let previous = hasCollectedAgents ? self.agents : nil
        self.agents = applyingClearedTurns(to: collected)
        hasCollectedAgents = true
        alertAboutChanges(since: previous)
        if previous == nil { await refreshWorktrees() }
    }

    func setAlertsEnabled(_ isEnabled: Bool) {
        settings.alertsEnabled = isEnabled
        if isEnabled { Task { await notifier.requestAuthorization() } } else { alertBatcher.discard() }
    }

    func pauseAlerts(until date: Date) {
        settings.alertsPausedUntil = date
    }

    /// Ends a pause; alerts held during it go out on the next poll.
    func resumeAlerts() {
        settings.alertsPausedUntil = nil
    }

    private func alertAboutChanges(since previous: [AgentSession]?) {
        notifier.withdraw(folders: AgentAlerts.stoppedWaiting(previous: previous, current: agents))
        guard settings.alertsEnabled else { return }
        let newAlerts = AgentAlerts.newlyWaiting(previous: previous, current: agents, states: settings.alertStates, tools: settings.alertTools)
        let delivery = alertBatcher.deliver(newAlerts, current: agents, isQuiet: settings.isQuietForAlerts(), handling: settings.quietAlertHandling)
        for agent in delivery.individual {
            notifier.post(about: agent, playsSound: settings.alertSound)
        }
        notifier.postSummary(of: delivery.summary, playsSound: settings.alertSound)
    }

    /// Takes an agent out of "Your turn" until it does something new.
    func clearYourTurn(_ agent: AgentSession) {
        for sibling in agents where sibling.state == .yourTurn && sibling.workingDirectory == agent.workingDirectory {
            clearedTurns[sibling.pid] = sibling.lastActivity ?? .distantPast
        }
        agents = applyingClearedTurns(to: agents)
        notifier.withdraw(folders: [agent.workingDirectory])
    }

    private func applyingClearedTurns(to agents: [AgentSession]) -> [AgentSession] {
        let lastActivity = Dictionary(agents.map { ($0.pid, $0.lastActivity ?? .distantPast) }, uniquingKeysWith: { first, _ in first })
        clearedTurns = clearedTurns.filter { lastActivity[$0.key] == $0.value }
        return agents.map { agent in
            guard agent.state == .yourTurn, clearedTurns[agent.pid] != nil else { return agent }
            var cleared = agent
            cleared.state = .idle
            return cleared
        }
    }

    func refreshUsage() async {
        let engine = engine
        let includeLimits = settings.claudeLimitsEnabled
        usage = await Task.detached { await engine.collectUsage(includeClaudeLimits: includeLimits) }.value
        usageHistory.record(usage, at: Date())
    }

    func refreshSpend() async {
        guard settings.spendTrackingEnabled else { return spend = nil }
        if DemoData.isEnabled { return spend = DemoData.spend }
        let engine = engine
        spend = await Task.detached { engine.collectSpend() }.value
        alertIfOverBudget()
    }

    func setNowPlayingEnabled(_ isEnabled: Bool) {
        settings.nowPlayingEnabled = isEnabled
        guard !DemoData.isEnabled else { return }
        if isEnabled { nowPlaying.start() } else { nowPlaying.stop() }
    }

    func setNowPlayingUsesSystemAudio(_ isEnabled: Bool) {
        settings.nowPlayingUsesSystemAudio = isEnabled
        nowPlaying.setUsesSystemAudio(isEnabled)
    }

    func setSpendTrackingEnabled(_ isEnabled: Bool) {
        settings.spendTrackingEnabled = isEnabled
        Task { await refreshSpend() }
    }

    private func alertIfOverBudget() {
        guard let today = spend?.today else { return }
        let budget = settings.dailySpendBudget
        guard SpendBudget.shouldAlert(todayCost: today.estimatedCost, budget: budget, lastAlertedDay: settings.spendBudgetAlertedDay, today: today.day) else { return }
        settings.spendBudgetAlertedDay = today.day
        if settings.alertsEnabled { notifier.postBudgetAlert(estimatedCost: today.estimatedCost, budget: budget, playsSound: settings.alertSound) }
    }

    func refreshAll() async {
        await refreshSystem()
        await refreshPortsAndAgents()
        await refreshUsage()
        await refreshSpend()
        await refreshDueWidgets(force: true)
        await refreshWorktrees()
    }

    func refreshWorktrees() async {
        await worktreeOverview.refresh(projectFolders: projectFolders)
    }

    func cleanUpWorktrees(_ targets: [Worktree]) async {
        await worktreeOverview.cleanUp(targets, projectFolders: projectFolders)
    }

    private func refreshProjectCache() async {
        let engine = engine
        await Task.detached { engine.refreshProjectCache() }.value
    }

    func refreshDueWidgets(force: Bool = false) async {
        let now = Date()
        let due = settings.customWidgets.filter { widget in
            force || widgetLastRun[widget.id].map { now.timeIntervalSince($0) >= widget.intervalSeconds } ?? true
        }
        for widget in due {
            widgetLastRun[widget.id] = now
            widgetResults[widget.id] = await Task.detached { CustomWidgetResult.run(widget) }.value
        }
    }

    private func loadDemo() {
        snapshot = DemoData.snapshot
        ports = DemoData.ports
        agents = DemoData.agents
        usage = DemoData.usage
        usageHistory = DemoData.usageHistory
        worktreeOverview.showDemo(DemoData.worktrees)
        spend = settings.spendTrackingEnabled ? DemoData.spend : nil
        nowPlaying.showDemo(DemoData.nowPlaying)
        cpuHistory = DemoData.history(around: 0.34, swing: 0.15)
        memoryHistory = DemoData.history(around: 0.61, swing: 0.04)
        networkInHistory = DemoData.history(around: 1_800_000, swing: 900_000)
        networkOutHistory = DemoData.history(around: 240_000, swing: 120_000)
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > Self.historyLength { history.removeFirst(history.count - Self.historyLength) }
    }

    // MARK: - Actions

    func stopProcess(_ pid: Int32) {
        kill(pid, SIGTERM)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await refreshPortsAndAgents()
        }
    }

    /// Focuses the agent's own terminal window or tab; opens a new terminal in its folder when that can't be found.
    func openTerminal(for agent: AgentSession) {
        guard !DemoData.isEnabled else { return }
        Task {
            if await !AgentTerminalFocuser.focus(agentPID: agent.pid) { openInTerminal(agent.workingDirectory) }
        }
    }

    /// Repeated hotkey presses shouldn't pile up new terminal windows, so an unreachable terminal only beeps.
    private func focusExistingTerminal(of agent: AgentSession) {
        guard !DemoData.isEnabled else { return }
        Task {
            if await !AgentTerminalFocuser.focus(agentPID: agent.pid) { NSSound.beep() }
        }
    }

    /// Interrupts the agent like Ctrl-C. CLIs that only cancel the turn on the first interrupt get a second one.
    func stopAgent(_ agent: AgentSession) {
        guard !DemoData.isEnabled else { return }
        kill(agent.pid, SIGINT)
        Task {
            try? await Task.sleep(for: .seconds(1))
            if kill(agent.pid, 0) == 0 { kill(agent.pid, SIGINT) }
            try? await Task.sleep(for: .milliseconds(600))
            await refreshPortsAndAgents()
        }
    }

    /// Focuses the next agent waiting on the user, longest-waiting first; beeps when nobody is waiting.
    func focusNextAgentNeedingYou() {
        guard let next = NeedsYouCycle.next(after: lastCycledAgentPID, among: agents) else {
            NSSound.beep()
            return
        }
        lastCycledAgentPID = next.pid
        focusExistingTerminal(of: next)
    }

    func applyNextAgentHotkey() {
        let shortcut = settings.nextAgentHotkeyEnabled ? settings.nextAgentHotkey : nil
        isNextAgentHotkeyTaken = !nextAgentHotkey.register(shortcut) { [weak self] in self?.focusNextAgentNeedingYou() }
    }

    /// Lets the shortcut recorder capture the current shortcut instead of triggering it.
    func suspendNextAgentHotkey() {
        nextAgentHotkey.unregister()
    }

    func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    let installedEditors = EditorApp.installed()

    var preferredEditor: EditorApp? {
        installedEditors.first { $0.bundleID == settings.editorBundleID }
    }

    /// Opens with the chosen editor, else the first installed one, else Finder.
    func openInEditor(_ path: String) {
        guard let editor = preferredEditor ?? installedEditors.first else {
            revealInFinder(path)
            return
        }
        open(path, in: editor)
    }

    func open(_ path: String, in editor: EditorApp) {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: editor.bundleID) else { return }
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    func openInTerminal(_ path: String) {
        let terminalIdentifiers = ["com.mitchellh.ghostty", "net.kovidgoyal.kitty", "com.googlecode.iterm2", "com.apple.Terminal"]
        guard let terminal = terminalIdentifiers.lazy.compactMap({ NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }).first else { return }
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}
