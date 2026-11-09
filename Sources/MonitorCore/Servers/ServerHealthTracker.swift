import Foundation

/// Tells a crashed dev server apart from one the user stopped and one that restarted.
/// A server that vanishes waits out `restartGrace`; back on the same folder and port means a restart.
public struct ServerHealthTracker: Sendable {
    public static let restartGrace: TimeInterval = 12
    public static let crashLifetime: TimeInterval = 10 * 60
    static let userStopMemory: TimeInterval = 60

    private struct Missing: Sendable {
        var server: ListeningPort
        var since: Date
    }

    private var running: [ServerIdentity: ListeningPort] = [:]
    private var missing: [ServerIdentity: Missing] = [:]
    private var stoppedByUser: [Int32: Date] = [:]
    public private(set) var crashed: [CrashedServer] = []

    public init() {}

    public mutating func noteStoppedByUser(pid: Int32, at now: Date = Date()) {
        stoppedByUser[pid] = now
    }

    public mutating func dismiss(_ id: ServerIdentity) {
        crashed.removeAll { $0.id == id }
    }

    /// Feeds one poll of listening ports and returns the servers that just counted as crashed.
    /// An empty scan is treated as a failed one, since a Mac always has some port open.
    public mutating func update(_ ports: [ListeningPort], at now: Date = Date()) -> [CrashedServer] {
        guard !ports.isEmpty else { return [] }
        let current = Self.servers(in: ports)
        missing = missing.filter { current[$0.key] == nil }
        crashed.removeAll { current[$0.id] != nil || now.timeIntervalSince($0.stoppedAt) >= Self.crashLifetime }
        noteVanished(from: current, at: now)
        running = current
        stoppedByUser = stoppedByUser.filter { now.timeIntervalSince($0.value) < Self.userStopMemory }
        return promoteExpiredMissing(at: now)
    }

    private mutating func noteVanished(from current: [ServerIdentity: ListeningPort], at now: Date) {
        for (id, server) in running where current[id] == nil && stoppedByUser[server.pid] == nil {
            missing[id] = Missing(server: server, since: now)
        }
    }

    private mutating func promoteExpiredMissing(at now: Date) -> [CrashedServer] {
        let expired = missing.filter { now.timeIntervalSince($0.value.since) >= Self.restartGrace }
        missing = missing.filter { expired[$0.key] == nil }
        let newlyCrashed = expired.map { CrashedServer(id: $0.key, server: $0.value.server, stoppedAt: $0.value.since) }
            .sorted { $0.id.port < $1.id.port }
        crashed = crashed.filter { expired[$0.id] == nil } + newlyCrashed
        return newlyCrashed
    }

    static func servers(in ports: [ListeningPort]) -> [ServerIdentity: ListeningPort] {
        var servers: [ServerIdentity: ListeningPort] = [:]
        for port in ports {
            guard let id = port.serverIdentity, servers[id] == nil else { continue }
            servers[id] = port
        }
        return servers
    }
}
