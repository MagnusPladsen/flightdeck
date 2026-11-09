import Foundation

/// What an agent was doing at a poll, as far as the daily recap cares.
public enum RecapActivity: String, Codable, Sendable {
    case working, needsApproval, yourTurn, idle

    public init(_ state: AgentState) {
        switch state {
        case .working, .possiblyStuck: self = .working
        case .needsApproval: self = .needsApproval
        case .yourTurn: self = .yourTurn
        case .idle: self = .idle
        }
    }

    public var isWaiting: Bool { self == .needsApproval || self == .yourTurn }
}

/// One agent at one poll.
public struct RecapSample: Sendable, Hashable {
    public var pid: Int32
    public var project: String
    public var activity: RecapActivity

    public init(pid: Int32, project: String, activity: RecapActivity) {
        self.pid = pid
        self.project = project
        self.activity = activity
    }
}

/// Time and turns for one project on one day.
public struct RecapTally: Codable, Hashable, Sendable {
    public var workingSeconds: TimeInterval = 0
    public var waitingSeconds: TimeInterval = 0
    public var longestWaitSeconds: TimeInterval = 0
    /// Turns that ended with the agent handing back to you.
    public var turns = 0
    /// Agent processes that were busy or waiting on you this day.
    public var sessionIDs: Set<Int32> = []

    public init(workingSeconds: TimeInterval = 0, waitingSeconds: TimeInterval = 0, longestWaitSeconds: TimeInterval = 0, turns: Int = 0, sessionIDs: Set<Int32> = []) {
        self.workingSeconds = workingSeconds
        self.waitingSeconds = waitingSeconds
        self.longestWaitSeconds = longestWaitSeconds
        self.turns = turns
        self.sessionIDs = sessionIDs
    }
}

public struct RecapDay: Codable, Hashable, Sendable, Identifiable {
    public var id: Date { day }
    public var day: Date
    public var projects: [String: RecapTally]

    public init(day: Date, projects: [String: RecapTally] = [:]) {
        self.day = day
        self.projects = projects
    }
}

/// Agent time per project and day, built up from the agent polls and kept for two weeks.
public struct RecapLedger: Codable, Hashable, Sendable {
    public static let keptDays = 14
    /// Longer gaps between polls (sleep, the app not running) are left out rather than guessed.
    public static let maximumGap: TimeInterval = 30

    /// Newest first.
    public private(set) var days: [RecapDay]
    private var lastSampleAt: Date?
    private var tracked: [TrackedAgent]

    private struct TrackedAgent: Codable, Hashable {
        var pid: Int32
        var project: String
        var activity: RecapActivity
        var waitSeconds: TimeInterval
    }

    public init(days: [RecapDay] = []) {
        self.days = days
        tracked = []
    }

    /// Credits the time since the previous poll to what each agent was doing then.
    public mutating func record(_ samples: [RecapSample], at now: Date, calendar: Calendar = .current) {
        let elapsed = lastSampleAt.map { now.timeIntervalSince($0) } ?? 0
        let credited = elapsed > 0 && elapsed <= Self.maximumGap ? elapsed : 0
        let day = calendar.startOfDay(for: now)
        let previous = Dictionary(tracked.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        tracked = samples.map { advance(previous[$0.pid], to: $0, crediting: credited, on: day) }
        lastSampleAt = now
        prune(before: calendar.date(byAdding: .day, value: 1 - Self.keptDays, to: day) ?? day)
    }

    private mutating func advance(_ prior: TrackedAgent?, to sample: RecapSample, crediting elapsed: TimeInterval, on day: Date) -> TrackedAgent {
        let waitSoFar = (prior?.waitSeconds ?? 0) + elapsed
        if let prior { credit(prior, elapsed: elapsed, waited: waitSoFar, on: day) }
        let finishedTurn = sample.activity == .yourTurn && (prior?.activity == .working || prior?.activity == .needsApproval)
        if sample.activity != .idle {
            update(project: sample.project, on: day) { tally in
                tally.sessionIDs.insert(sample.pid)
                if finishedTurn { tally.turns += 1 }
            }
        }
        let keepsWaiting = prior?.activity.isWaiting == true && sample.activity.isWaiting
        return TrackedAgent(pid: sample.pid, project: sample.project, activity: sample.activity, waitSeconds: keepsWaiting ? waitSoFar : 0)
    }

    private mutating func credit(_ agent: TrackedAgent, elapsed: TimeInterval, waited: TimeInterval, on day: Date) {
        guard elapsed > 0, agent.activity != .idle else { return }
        update(project: agent.project, on: day) { tally in
            if agent.activity == .working { tally.workingSeconds += elapsed }
            guard agent.activity.isWaiting else { return }
            tally.waitingSeconds += elapsed
            tally.longestWaitSeconds = max(tally.longestWaitSeconds, waited)
        }
    }

    private mutating func update(project: String, on day: Date, _ change: (inout RecapTally) -> Void) {
        if days.first?.day != day { days.insert(RecapDay(day: day), at: 0) }
        change(&days[0].projects[project, default: RecapTally()])
    }

    private mutating func prune(before oldest: Date) {
        days.removeAll { $0.day < oldest }
    }
}
