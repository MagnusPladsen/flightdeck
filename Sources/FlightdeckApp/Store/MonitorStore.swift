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
    private(set) var widgetResults: [UUID: CustomWidgetResult] = [:]

    let settings: AppSettings
    private let engine = MonitorEngine()
    private var pollingTasks: [Task<Void, Never>] = []
    private var widgetLastRun: [UUID: Date] = [:]

    init(settings: AppSettings) {
        self.settings = settings
    }

    var devServers: [ListeningPort] { ports.filter(\.isDevServer) }
    var visiblePorts: [ListeningPort] { settings.showSystemPorts ? ports : devServers }
    var activeAgents: [AgentSession] { agents.filter { $0.state != .idle } }
    var visibleAgents: [AgentSession] { settings.showIdleAgents ? agents : activeAgents }

    func usage(for tool: AgentTool) -> ProviderUsage? {
        usage.first { $0.tool == tool }
    }

    func start() {
        guard pollingTasks.isEmpty else { return }
        pollingTasks = [
            poll(every: .seconds(2)) { await $0.refreshSystem() },
            poll(every: .seconds(5)) { await $0.refreshPortsAndAgents() },
            poll(every: .seconds(60)) { await $0.refreshUsage() },
            poll(every: .seconds(5)) { await $0.refreshDueWidgets() },
            poll(every: .seconds(30)) { await $0.refreshProjectCache() },
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
        (self.ports, self.agents) = await (ports, agents)
    }

    func refreshUsage() async {
        let engine = engine
        let includeLimits = settings.claudeLimitsEnabled
        usage = await Task.detached { await engine.collectUsage(includeClaudeLimits: includeLimits) }.value
    }

    func refreshAll() async {
        await refreshSystem()
        await refreshPortsAndAgents()
        await refreshUsage()
        await refreshDueWidgets(force: true)
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
