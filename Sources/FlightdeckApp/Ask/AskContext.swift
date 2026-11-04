import Foundation
import MonitorCore

/// The folder Claude runs in when asked from the search bar: a CLAUDE.md that explains Flightdeck,
/// and state.md with what the dashboard shows right now.
@MainActor
enum AskContext {
    nonisolated static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Flightdeck/Ask", isDirectory: true)

    static func write(from store: MonitorStore) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try guide.write(to: folder.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try state(from: store).write(to: folder.appendingPathComponent("state.md"), atomically: true, encoding: .utf8)
    }

    private static let guide = """
    # Flightdeck assistant

    You answer questions typed into the search bar of Flightdeck, a macOS menu bar and dashboard app that
    monitors AI coding agents (Claude Code, Codex and others), dev servers, ports and system resources.

    - `state.md` in this folder is what Flightdeck shows right now. Read it first; it is rewritten before every question.
    - Agent states: **working** (busy), **needs approval** (blocked on a permission prompt), **needs you**
      (finished, waiting for the next prompt), **idle** (no activity for a while).
    - Claude Code transcripts live in `~/.claude/projects/<path with / replaced by ->/<session>.jsonl`.
      Read the newest one for a project when asked what an agent is doing or did.
    - You can read the agents' project folders when a question needs it. Do not change any files.
    - The user reads the answer in a small card under the search bar: answer in a few short lines or points,
      lead with the answer, name projects, ports and numbers.
    """

    private static func state(from store: MonitorStore) -> String {
        let generated = Date().formatted(date: .abbreviated, time: .standard)
        return (["# Flightdeck state, \(generated)"] + [system(store), agents(store), ports(store), usage(store), processes(store)])
            .joined(separator: "\n\n")
    }

    private static func system(_ store: MonitorStore) -> String {
        guard let snapshot = store.snapshot else { return "## System\n\nNot sampled yet." }
        var lines = [
            "CPU \(Formatters.percent(snapshot.cpu.total)), load \(snapshot.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " "))",
            "Memory \(Formatters.bytes(snapshot.memory.usedBytes)) of \(Formatters.bytes(snapshot.memory.totalBytes)), pressure \(snapshot.memory.pressure), swap \(Formatters.bytes(snapshot.memory.swapUsedBytes))",
            "Network in \(Formatters.rate(snapshot.network.bytesInPerSecond)), out \(Formatters.rate(snapshot.network.bytesOutPerSecond))",
        ]
        lines += snapshot.disks.map { "Disk \($0.name): \(Formatters.bytes($0.availableBytes)) free of \(Formatters.bytes($0.totalBytes))" }
        if let battery = snapshot.battery {
            lines.append("Battery \(Int(battery.percent))%\(battery.isCharging ? ", charging" : battery.isPluggedIn ? ", plugged in" : "")")
        }
        return "## System\n\n" + lines.map { "- " + $0 }.joined(separator: "\n")
    }

    private static func agents(_ store: MonitorStore) -> String {
        let rows = store.agents.map { agent in
            let action = agent.actionLine
            let checkout = agent.checkoutLabel.map { " \($0)" } ?? ""
            return "- **\(agent.displayName)**\(checkout) — \(agent.tool.displayName), \(stateName(agent.state)). \(action.verb) \(action.detail). "
                + "Last activity \(Formatters.relative(agent.lastActivity)), CPU \(String(format: "%.0f", agent.cpuPercent))%, pid \(agent.pid), `\(agent.workingDirectory)`"
        }
        return "## Agents (\(store.agents.count))\n\n" + (rows.isEmpty ? "None running." : rows.joined(separator: "\n"))
    }

    private static func ports(_ store: MonitorStore) -> String {
        let rows = store.ports.sorted { $0.port < $1.port }.map { port in
            let framework = port.framework.map { " (\($0.displayName))" } ?? ""
            let kind = port.isDevServer ? "dev server" : "system"
            return "- :\(port.port) \(port.title)\(framework), \(kind), \(port.processName) pid \(port.pid)\(port.workingDirectory.map { ", `\($0)`" } ?? "")"
        }
        return "## Listening ports (\(store.ports.count))\n\n" + (rows.isEmpty ? "None." : rows.joined(separator: "\n"))
    }

    private static func usage(_ store: MonitorStore) -> String {
        let rows = store.usage.flatMap { provider in
            provider.windows.map { window in
                let reset = Formatters.resetCountdown(window.resetsAt).map { ", resets in \($0)" } ?? ""
                return "- \(provider.tool.displayName)\(provider.plan.map { " (\($0))" } ?? "") \(window.label): \(Int(window.usedPercent.rounded()))% used\(reset)"
            }
        }
        return "## Usage limits\n\n" + (rows.isEmpty ? "Unknown." : rows.joined(separator: "\n"))
    }

    private static func processes(_ store: MonitorStore) -> String {
        let top = (store.snapshot?.processes ?? []).sorted { $0.cpuPercent > $1.cpuPercent }.prefix(10)
        let rows = top.map { "- \($0.name) pid \($0.pid): CPU \(String(format: "%.1f", $0.cpuPercent))%, \(Formatters.bytes($0.memoryBytes))" }
        return "## Top processes by CPU\n\n" + rows.joined(separator: "\n")
    }

    private static func stateName(_ state: AgentState) -> String {
        switch state {
        case .working: "working"
        case .needsApproval: "needs approval"
        case .yourTurn: "needs you"
        case .idle: "idle"
        }
    }
}
