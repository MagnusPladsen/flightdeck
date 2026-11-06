import Foundation

/// The office's "Needs you" corner: a fresh request shows as a full post for a while, then shrinks
/// into an avatar that stays at the top of the office until the agent no longer needs you.
public struct NeedsYouQueue: Equatable, Sendable {
    /// How long a post stays full size before it shrinks into an avatar.
    public static let postSeconds: TimeInterval = 20
    /// Full posts shown at once; further requests start as avatars.
    public static let maxPosts = 3

    /// When each waiting agent started needing you.
    public private(set) var waitingSince: [Int32: Date] = [:]
    /// Agents whose post the user shrank, or walked over to.
    public private(set) var shrunk: Set<Int32> = []

    public init() {}

    /// Starts the clock for agents that just began waiting and forgets those that no longer wait.
    /// A newly seen agent counts as waiting since its last activity, so one that has waited a while starts as an avatar.
    public mutating func update(agents: [AgentSession], now: Date) {
        let waiting = agents.filter { NeedsYouFeed.needsPost($0.state) }
        let pids = Set(waiting.map(\.pid))
        waitingSince = waitingSince.filter { pids.contains($0.key) }
        for agent in waiting where waitingSince[agent.pid] == nil {
            waitingSince[agent.pid] = min(agent.lastActivity ?? now, now)
        }
        shrunk.formIntersection(pids)
    }

    public mutating func shrink(_ pid: Int32) {
        guard waitingSince[pid] != nil else { return }
        shrunk.insert(pid)
    }

    /// Posts newest first; avatars longest-waiting first, so the most overdue sits at the start of the row.
    public func layout(of agents: [AgentSession], now: Date) -> NeedsYouLayout {
        let waiting = agents.compactMap { agent in waitingSince[agent.pid].map { (agent, $0) } }
        let fresh = waiting.filter { !shrunk.contains($0.0.pid) && now.timeIntervalSince($0.1) < Self.postSeconds }
            .sorted(by: Self.newestFirst)
            .prefix(Self.maxPosts)
        let postPIDs = Set(fresh.map(\.0.pid))
        let avatars = waiting.filter { !postPIDs.contains($0.0.pid) }.sorted(by: Self.longestWaitingFirst)
        return NeedsYouLayout(posts: fresh.map(\.0), avatars: avatars.map(\.0))
    }

    private static func newestFirst(_ lhs: (AgentSession, Date), _ rhs: (AgentSession, Date)) -> Bool {
        lhs.1 == rhs.1 ? lhs.0.pid < rhs.0.pid : lhs.1 > rhs.1
    }

    private static func longestWaitingFirst(_ lhs: (AgentSession, Date), _ rhs: (AgentSession, Date)) -> Bool {
        lhs.1 == rhs.1 ? lhs.0.pid < rhs.0.pid : lhs.1 < rhs.1
    }
}

/// Which waiting agents show as full posts and which as avatars.
public struct NeedsYouLayout: Equatable, Sendable {
    public var posts: [AgentSession]
    public var avatars: [AgentSession]
}
