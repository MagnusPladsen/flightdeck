import Foundation
import MonitorCore

/// What each office object explains about itself on hover.
enum OfficeTooltipText {
    static func text(for object: OfficeObject, readings: OfficeReadings, map: OfficeMap) -> String? {
        switch object {
        case .agent(let pid):
            guard let agent = readings.agents.first(where: { $0.pid == pid }) else { return nil }
            return "\(agent.tool.displayName) · \(agent.displayName) · \(agent.state.label) — click to talk"
        case .rack(let port): return rack(port)
        case .cpuRack: return cpu(readings.snapshot)
        case .waterCooler: return memory(readings.snapshot?.memory)
        case .wallClock: return limits(readings)
        case .jukebox: return jukebox(readings.track)
        case .jukeboxPad(let command): return readings.track == nil ? nil : pad(command)
        }
    }

    private static func pad(_ command: NowPlayingCommand) -> String {
        switch command {
        case .previousTrack: "Previous track (Q by the jukebox)"
        case .nextTrack: "Next track (E by the jukebox)"
        default: "Play or pause (Space by the jukebox)"
        }
    }

    private static func jukebox(_ track: NowPlayingTrack?) -> String {
        guard let track else { return "Jukebox: nothing playing" }
        let parts = [track.title, track.artist, track.sourceName].compactMap { $0 }.filter { !$0.isEmpty }
        return (track.isPlaying ? "Jukebox: " : "Jukebox (paused): ") + parts.joined(separator: " · ")
    }

    private static func rack(_ port: ListeningPort) -> String {
        let checkout = port.project.map { $0.isWorktree ? ($0.worktreeName ?? "worktree") : ($0.branch ?? $0.name) }
        let parts = [":\(port.port)", port.framework?.displayName ?? port.containerName ?? port.processName, checkout].compactMap { $0 }
        return parts.joined(separator: " · ") + " — click to open"
    }

    private static func cpu(_ snapshot: SystemSnapshot?) -> String {
        guard let snapshot else { return "CPU: no reading yet" }
        let load = snapshot.loadAverage.first.map { String(format: " · load %.1f", $0) } ?? ""
        return "Server rack: CPU \(Formatters.percent(snapshot.cpu.total))\(load)"
    }

    private static func memory(_ memory: MemoryUsage?) -> String {
        guard let memory else { return "Memory: no reading yet" }
        return "Water cooler: memory \(Formatters.bytes(memory.usedBytes)) of \(Formatters.bytes(memory.totalBytes)) · pressure \(memory.pressure.rawValue)"
    }

    private static func limits(_ readings: OfficeReadings) -> String {
        guard !readings.limitWindows.isEmpty else { return "Clock: \(Date().formatted(date: .omitted, time: .shortened)) · no usage-limit data" }
        let windows = readings.limitWindows.map { window in
            let reset = Formatters.resetCountdown(window.resetsAt).map { " · \($0)" } ?? ""
            return "\(window.label) \(Int(window.usedPercent.rounded()))% used\(reset)"
        }
        return "\(readings.limitsTool.displayName) limits: " + windows.joined(separator: ", ")
    }
}
