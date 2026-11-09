import AppKit
import Foundation
import MonitorCore

/// Crash alerts and the Restart action for dev servers.
extension MonitorStore {
    private static let portReleaseTimeout: Duration = .seconds(10)
    private static let portReleasePollInterval: Duration = .milliseconds(500)
    private static let terminalScriptTimeout: TimeInterval = 30
    private static let launchTerminals: [(bundleID: String, host: TerminalHost)] = [
        ("com.mitchellh.ghostty", .ghostty), ("com.googlecode.iterm2", .iTerm), ("com.apple.Terminal", .terminalApp),
    ]

    func refreshServerHealth() {
        let quiet = settings.isQuietForAlerts()
        let crashes = serverHealth.update(ports: ports, isQuiet: quiet, handling: settings.quietAlertHandling)
        guard settings.alertsEnabled, settings.serverCrashAlertsEnabled else { return serverHealth.discardHeldAlerts() }
        notifier.postServerCrashes(crashes, playsSound: settings.alertSound)
    }

    func canRestart(_ server: ListeningPort) -> Bool {
        server.serverIdentity != nil && server.workingDirectory != nil && ServerRelaunch.isRelaunchable(server.arguments)
    }

    /// Stops the server, waits for its port to free, then runs its original command again in a new terminal tab.
    func restartServer(_ server: ListeningPort) {
        guard !DemoData.isEnabled, canRestart(server) else { return }
        serverHealth.noteStoppedByUser(server.pid)
        kill(server.pid, SIGTERM)
        Task {
            guard await Self.waitForPortToFree(server.port) else { return NSSound.beep() }
            relaunch(server)
        }
    }

    func relaunch(_ crashed: CrashedServer) {
        guard !DemoData.isEnabled, canRestart(crashed.server) else { return }
        serverHealth.dismiss(crashed)
        relaunch(crashed.server)
    }

    private func relaunch(_ server: ListeningPort) {
        guard let id = server.serverIdentity, let folder = server.workingDirectory else { return }
        let command = ServerRelaunch.shellCommand(arguments: server.arguments, workingDirectory: folder, logPath: serverHealth.logURL(for: id).path)
        guard let terminal = Self.launchTerminals.first(where: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }),
              let script = TerminalLaunchScript.source(for: terminal.host, command: command) else { return NSSound.beep() }
        let timeout = Self.terminalScriptTimeout
        Task {
            await Task.detached { _ = CommandRunner.run("/usr/bin/osascript", ["-e", script], timeout: timeout) }.value
            try? await Task.sleep(for: .seconds(2))
            await refreshPortsAndAgents()
        }
    }

    private static func waitForPortToFree(_ port: Int) async -> Bool {
        let scanner = PlatformServices.makeListeningSocketScanner()
        let deadline = ContinuousClock.now + portReleaseTimeout
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: portReleasePollInterval)
            let sockets = await Task.detached { scanner.scanListeningSockets() }.value
            if !sockets.contains(where: { $0.port == port }) { return true }
        }
        return false
    }
}
