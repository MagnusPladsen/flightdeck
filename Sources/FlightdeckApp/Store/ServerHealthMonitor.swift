import Foundation
import MonitorCore
import Observation

/// Crashed dev servers, port conflicts and the logs of servers Flightdeck relaunched.
@MainActor
@Observable
final class ServerHealthMonitor {
    static let logLineCount = 12
    private static let logReadLimit = 16_384

    private(set) var conflicts: [String: PortConflict] = [:]
    /// Servers relaunched from Flightdeck this session, whose output is copied to a log file.
    private(set) var logFiles: [ServerIdentity: URL] = [:]
    private var tracker = ServerHealthTracker()
    private var alertQueue = ServerAlertQueue()
    private var demoCrashes: [CrashedServer]?
    private var demoLogs: [ServerIdentity: [String]] = [:]

    var crashed: [CrashedServer] { demoCrashes ?? tracker.crashed }

    /// Returns the crashes to alert about now, holding them back while alerts are quiet.
    func update(ports: [ListeningPort], isQuiet: Bool, handling: QuietAlertHandling) -> [CrashedServer] {
        conflicts = PortConflicts.detect(in: ports)
        let newCrashes = tracker.update(ports)
        return alertQueue.deliver(newCrashes, stillCrashed: tracker.crashed, isQuiet: isQuiet, handling: handling)
    }

    func noteStoppedByUser(_ pid: Int32) {
        tracker.noteStoppedByUser(pid: pid)
    }

    func dismiss(_ server: CrashedServer) {
        tracker.dismiss(server.id)
        demoCrashes?.removeAll { $0.id == server.id }
    }

    func discardHeldAlerts() {
        alertQueue.discard()
    }

    func logURL(for id: ServerIdentity) -> URL {
        let folder = URL.applicationSupportDirectory.appending(path: "Flightdeck/Server Logs", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: ServerRelaunch.logFileName(for: id))
        logFiles[id] = url
        return url
    }

    func hasLog(for id: ServerIdentity?) -> Bool {
        guard let id else { return false }
        return demoLogs[id] != nil || logFiles[id] != nil
    }

    func logLines(for id: ServerIdentity) -> [String] {
        if let demo = demoLogs[id] { return demo }
        guard let url = logFiles[id], let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > UInt64(Self.logReadLimit) ? size - UInt64(Self.logReadLimit) : 0)
        let text = String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)
        return LogTail.lastLines(of: text, count: Self.logLineCount)
    }

    func showDemo(ports: [ListeningPort], crashed: [CrashedServer], logs: [ServerIdentity: [String]]) {
        conflicts = PortConflicts.detect(in: ports)
        demoCrashes = crashed
        demoLogs = logs
    }
}
