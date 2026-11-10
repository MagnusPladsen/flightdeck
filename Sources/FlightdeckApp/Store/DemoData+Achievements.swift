import Foundation
import MonitorCore

extension DemoData {
    /// About half the achievements unlocked over the last weeks, with progress on the rest.
    static var achievements: AchievementLedger {
        var ledger = AchievementLedger()
        let values: [AchievementMetric: Double] = [
            .peakWorkingAgents: 6, .agentHours: 214, .turns: 640, .approvals: 77, .projects: 7, .agentsLaunched: 12, .limitsHit: 1,
            .peakDailyMillionTokens: 4.2, .daysUsed: 41, .longestStreak: 9, .nightOwlNights: 3, .earlyBirdDays: 1, .weekendDays: 4,
            .cpuRedlines: 2, .peakDevServers: 4, .processesStopped: 9, .worktreesCleaned: 14, .cacheGigabytesCleaned: 37,
            .tracksHeard: 380, .musicHours: 46, .partyMinutes: 35, .jukeboxPresses: 18, .officeVisits: 22, .officeTilesWalked: 3400,
            .paletteUses: 64, .questionsAsked: 11,
        ]
        for (metric, value) in values { ledger.add(value, to: metric) }
        _ = ledger.unlockReached(at: Date())
        return ledger
    }

    static let officeWeather: OfficeWeatherCondition = ProcessInfo.processInfo.environment["FLIGHTDECK_WEATHER"]
        .flatMap(OfficeWeatherCondition.init(rawValue:)) ?? .clear
}

extension DemoData {
    static let networkConsumers: [NetworkConsumer] = [
        NetworkConsumer(name: "Google Chrome", bytesInPerSecond: 1_420_000, bytesOutPerSecond: 86_000, processCount: 9),
        NetworkConsumer(name: "Docker", bytesInPerSecond: 610_000, bytesOutPerSecond: 240_000, processCount: 3),
        NetworkConsumer(name: "claude", bytesInPerSecond: 92_000, bytesOutPerSecond: 31_000, processCount: 4),
        NetworkConsumer(name: "Slack", bytesInPerSecond: 38_000, bytesOutPerSecond: 6_000, processCount: 5),
        NetworkConsumer(name: "node", bytesInPerSecond: 12_000, bytesOutPerSecond: 19_000, processCount: 2),
        NetworkConsumer(name: "Spotify", bytesInPerSecond: 21_000, bytesOutPerSecond: 1_200, processCount: 3),
    ]
}
