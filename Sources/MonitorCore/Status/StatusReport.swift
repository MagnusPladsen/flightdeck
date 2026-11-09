import Foundation

/// What `status.json` holds: a small summary of Flightdeck's live state for status bars and scripts.
public struct StatusReport: Codable, Sendable, Equatable {
    public static let schemaVersion = 1

    public var version: Int
    public var appVersion: String?
    /// When the file was last rewritten. The file's modification time says when the app last confirmed it.
    public var updatedAt: Date
    public var counts: StatusCounts
    public var agents: [StatusAgent]
    public var servers: [StatusServer]
    public var system: StatusSystem?
    public var limits: [StatusLimit]

    public init(appVersion: String?, updatedAt: Date, counts: StatusCounts, agents: [StatusAgent], servers: [StatusServer], system: StatusSystem?, limits: [StatusLimit]) {
        version = Self.schemaVersion
        self.appVersion = appVersion
        self.updatedAt = updatedAt
        self.counts = counts
        self.agents = agents
        self.servers = servers
        self.system = system
        self.limits = limits
    }

    /// Even unchanged content is rewritten this often, so the system readings stay roughly current.
    public static let rewriteInterval: TimeInterval = 60

    /// True when everything but `updatedAt`, the system readings and the agents' last activity matches,
    /// so a poll where only those moved doesn't rewrite the file.
    public func hasSameContent(as other: StatusReport) -> Bool {
        withoutVolatileFields == other.withoutVolatileFields
    }

    /// Rewrite when the content changed or the last write is a minute old; otherwise touching the file is enough.
    public func needsRewrite(after published: StatusReport?) -> Bool {
        guard let published else { return true }
        return !hasSameContent(as: published) || updatedAt.timeIntervalSince(published.updatedAt) >= Self.rewriteInterval
    }

    private var withoutVolatileFields: StatusReport {
        var stable = self
        stable.updatedAt = .distantPast
        stable.system = nil
        stable.agents = agents.map { agent in
            var stableAgent = agent
            stableAgent.lastActivity = nil
            return stableAgent
        }
        return stable
    }
}

public struct StatusCounts: Codable, Sendable, Equatable {
    public var working: Int
    public var needsYou: Int
    public var idle: Int
    public var servers: Int

    public init(working: Int, needsYou: Int, idle: Int, servers: Int) {
        self.working = working
        self.needsYou = needsYou
        self.idle = idle
        self.servers = servers
    }
}

public struct StatusAgent: Codable, Sendable, Equatable {
    public var tool: String
    public var folder: String
    public var project: String
    public var branch: String?
    public var state: String
    public var waitingSince: Date?
    public var lastActivity: Date?
    public var lastAction: String?
}

public struct StatusServer: Codable, Sendable, Equatable {
    public var port: Int
    public var project: String?
    public var framework: String?
}

public struct StatusSystem: Codable, Sendable, Equatable {
    public var cpuPercent: Int
    public var memoryPercent: Int
}

public struct StatusLimit: Codable, Sendable, Equatable {
    public var tool: String
    public var window: String
    public var usedPercent: Int
    public var resetsAt: Date?
}
