import Foundation

/// What was seen at one poll, for the achievements that follow agents and the system.
public struct AchievementObservation: Sendable {
    public var agents: [AgentSession]
    public var devServerCount: Int
    public var cpuLoad: Double?
    public var memoryPressure: MemoryPressure?
    /// The highest share of any usage-limit window, 0...100.
    public var highestLimitPercent: Double?
    public var tokensToday: Int?

    public init(agents: [AgentSession], devServerCount: Int, cpuLoad: Double? = nil, memoryPressure: MemoryPressure? = nil,
                highestLimitPercent: Double? = nil, tokensToday: Int? = nil) {
        self.agents = agents
        self.devServerCount = devServerCount
        self.cpuLoad = cpuLoad
        self.memoryPressure = memoryPressure
        self.highestLimitPercent = highestLimitPercent
        self.tokensToday = tokensToday
    }
}

/// The achievement numbers, when each achievement unlocked, and what is needed to count things once.
public struct AchievementLedger: Codable, Hashable, Sendable {
    /// Polls further apart than this (sleep, a quit app) don't count as agent time.
    static let longestCountedGap: TimeInterval = 60

    public private(set) var values: [AchievementMetric: Double] = [:]
    public private(set) var unlocked: [String: Date] = [:]
    private var projects: Set<String> = []
    /// The last day each once-a-day metric counted.
    private var countedDays: [AchievementMetric: Date] = [:]
    private var lastActiveDay: Date?
    private var streak = 0
    private var lastStates: [Int32: String] = [:]
    private var lastObservedAt: Date?

    public init() {}

    public func value(of metric: AchievementMetric) -> Double { values[metric] ?? 0 }

    public func isUnlocked(_ achievement: Achievement) -> Bool { unlocked[achievement.id] != nil }

    public mutating func add(_ amount: Double = 1, to metric: AchievementMetric) {
        values[metric, default: 0] += amount
    }

    public mutating func raise(_ metric: AchievementMetric, to value: Double) {
        values[metric] = max(values[metric] ?? 0, value)
    }

    /// Adds one to the metric the first time it is called on a day.
    public mutating func countOncePerDay(_ metric: AchievementMetric, at now: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: now)
        guard countedDays[metric] != day else { return }
        countedDays[metric] = day
        add(to: metric)
    }

    public mutating func observe(_ observation: AchievementObservation, at now: Date, calendar: Calendar = .current) {
        countOncePerDay(.daysUsed, at: now, calendar: calendar)
        observeAgents(observation.agents, at: now, calendar: calendar)
        raise(.peakDevServers, to: Double(observation.devServerCount))
        if let load = observation.cpuLoad, load >= 0.95 { countOncePerDay(.cpuRedlines, at: now, calendar: calendar) }
        if observation.memoryPressure == .critical { countOncePerDay(.memoryCrunches, at: now, calendar: calendar) }
        if let percent = observation.highestLimitPercent, percent >= 100 { countOncePerDay(.limitsHit, at: now, calendar: calendar) }
        if let tokens = observation.tokensToday { raise(.peakDailyMillionTokens, to: Double(tokens) / 1_000_000) }
        lastObservedAt = now
    }

    private mutating func observeAgents(_ agents: [AgentSession], at now: Date, calendar: Calendar) {
        let working = agents.filter { $0.state == .working }
        raise(.peakWorkingAgents, to: Double(working.count))
        if let last = lastObservedAt, case let gap = now.timeIntervalSince(last), gap > 0, gap <= Self.longestCountedGap {
            add(gap * Double(working.count) / 3600, to: .agentHours)
        }
        for agent in agents {
            switch (lastStates[agent.pid].flatMap(AgentState.init(rawValue:)), agent.state) {
            case (.working?, .yourTurn): add(to: .turns)
            case (.needsApproval?, .working): add(to: .approvals)
            default: break
            }
        }
        lastStates = Dictionary(agents.map { ($0.pid, $0.state.rawValue) }, uniquingKeysWith: { first, _ in first })
        projects.formUnion(agents.filter { $0.state != .idle }.map { $0.project?.name ?? URL(fileURLWithPath: $0.workingDirectory).lastPathComponent })
        raise(.projects, to: Double(projects.count))
        guard !working.isEmpty else { return }
        noteActiveDay(now, calendar: calendar)
        let hour = calendar.component(.hour, from: now)
        if hour < 4 { countOncePerDay(.nightOwlNights, at: now, calendar: calendar) }
        if (5..<7).contains(hour) { countOncePerDay(.earlyBirdDays, at: now, calendar: calendar) }
        if calendar.isDateInWeekend(now) { countOncePerDay(.weekendDays, at: now, calendar: calendar) }
    }

    private mutating func noteActiveDay(_ now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        guard lastActiveDay != today else { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        streak = lastActiveDay == yesterday ? streak + 1 : 1
        lastActiveDay = today
        raise(.longestStreak, to: Double(streak))
    }

    /// Marks achievements whose goal is reached and returns the ones that just unlocked.
    public mutating func unlockReached(at now: Date, catalog: [Achievement] = AchievementCatalog.all) -> [Achievement] {
        let reached = catalog.filter { unlocked[$0.id] == nil && value(of: $0.metric) >= $0.goal }
        for achievement in reached { unlocked[achievement.id] = now }
        return reached
    }

    public static func load(from url: URL) -> AchievementLedger {
        guard let data = try? Data(contentsOf: url) else { return AchievementLedger() }
        return (try? JSONDecoder().decode(AchievementLedger.self, from: data)) ?? AchievementLedger()
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
