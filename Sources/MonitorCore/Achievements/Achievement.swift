import Foundation

/// A number Flightdeck keeps for achievements, such as agent hours or tracks heard.
public enum AchievementMetric: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case peakWorkingAgents, agentHours, turns, approvals, projects, agentsLaunched, limitsHit, peakDailyMillionTokens
    case nightOwlNights, earlyBirdDays, weekendDays, longestStreak, daysUsed
    case cpuRedlines, memoryCrunches, peakDevServers, processesStopped, worktreesCleaned, cacheGigabytesCleaned
    case tracksHeard, musicHours, partyMinutes, jukeboxPresses, officeVisits, officeTilesWalked
    case paletteUses, questionsAsked
}

public enum AchievementCategory: String, CaseIterable, Sendable {
    case agents = "Agents"
    case habits = "Habits"
    case system = "System"
    case music = "Music & office"
    case dashboard = "Dashboard"
}

/// Something to unlock: reach `goal` on `metric`.
public struct Achievement: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var symbol: String
    public var category: AchievementCategory
    public var metric: AchievementMetric
    public var goal: Double

    public init(_ id: String, _ title: String, _ detail: String, symbol: String, _ category: AchievementCategory, _ metric: AchievementMetric, goal: Double) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.category = category
        self.metric = metric
        self.goal = goal
    }

    /// 0...1 towards the goal.
    public func progress(_ value: Double) -> Double {
        min(max(value / goal, 0), 1)
    }
}
