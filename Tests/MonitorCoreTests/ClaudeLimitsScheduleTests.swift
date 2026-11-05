import Foundation
import MonitorCore
import Testing

struct ClaudeLimitsScheduleTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let usage = ProviderUsage(tool: .claude, windows: [UsageWindow(label: "5h", usedPercent: 42, resetsAt: nil)])

    @Test func firstFetchIsDueAtOnce() {
        #expect(ClaudeLimitsSchedule().isDue(at: start))
    }

    @Test func successWaitsTheRefreshInterval() {
        var schedule = ClaudeLimitsSchedule()
        schedule.record(.usage(usage), at: start)
        #expect(!schedule.isDue(at: start + 60))
        #expect(schedule.isDue(at: start + ClaudeLimitsSchedule.refreshInterval))
    }

    @Test func rateLimitKeepsTheLastUsage() {
        var schedule = ClaudeLimitsSchedule()
        schedule.record(.usage(usage), at: start)
        schedule.record(.rateLimited(retryAfter: nil), at: start + 300)
        #expect(schedule.lastUsage == usage)
    }

    @Test func repeatedFailuresBackOffUpToTheMaximum() {
        var schedule = ClaudeLimitsSchedule()
        var now = start
        var waits: [TimeInterval] = []
        for _ in 0..<5 {
            schedule.record(.rateLimited(retryAfter: nil), at: now)
            waits.append(schedule.nextFetch.timeIntervalSince(now))
            now = schedule.nextFetch
        }
        #expect(waits == [300, 600, 1200, 1800, 1800])
    }

    @Test func retryAfterLongerThanBackoffWins() {
        var schedule = ClaudeLimitsSchedule()
        schedule.record(.rateLimited(retryAfter: 3600), at: start)
        #expect(schedule.nextFetch == start + 3600)
    }
}
