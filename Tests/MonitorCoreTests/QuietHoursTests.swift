import Foundation
import MonitorCore
import Testing

struct QuietHoursTests {
    private static let sunday = 1, monday = 2, friday = 6, saturday = 7

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
        return calendar
    }

    /// 2026-11-02 is a Monday, so day 0 is Monday and day 4 is Friday.
    private func date(day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 2 + day, hour: hour, minute: minute))!
    }

    private func hours(_ start: Int, _ end: Int, days: Set<Int> = Set(1...7)) -> QuietHours {
        QuietHours(isEnabled: true, startMinute: start * 60, endMinute: end * 60, weekdays: days)
    }

    @Test func disabledScheduleIsNeverQuiet() {
        var schedule = hours(0, 0)
        schedule.isEnabled = false
        #expect(!schedule.contains(date(day: 0, 12), calendar: calendar))
    }

    @Test func sameDayWindowIncludesStartAndExcludesEnd() {
        let schedule = hours(9, 17)
        #expect(!schedule.contains(date(day: 0, 8, 59), calendar: calendar))
        #expect(schedule.contains(date(day: 0, 9), calendar: calendar))
        #expect(schedule.contains(date(day: 0, 16, 59), calendar: calendar))
        #expect(!schedule.contains(date(day: 0, 17), calendar: calendar))
    }

    @Test func windowCrossingMidnightCoversBothSides() {
        let schedule = hours(22, 7)
        #expect(schedule.contains(date(day: 0, 23, 30), calendar: calendar))
        #expect(schedule.contains(date(day: 1, 3), calendar: calendar))
        #expect(!schedule.contains(date(day: 1, 7), calendar: calendar))
        #expect(!schedule.contains(date(day: 1, 21, 59), calendar: calendar))
    }

    @Test func morningAfterBelongsToTheDayTheWindowStarted() {
        let schedule = hours(22, 7, days: [Self.friday])
        #expect(schedule.contains(date(day: 4, 23), calendar: calendar))
        #expect(schedule.contains(date(day: 5, 6), calendar: calendar))
        #expect(!schedule.contains(date(day: 4, 6), calendar: calendar))
    }

    @Test func saturdayNightRunsIntoSunday() {
        let schedule = hours(22, 7, days: [Self.saturday])
        #expect(schedule.contains(date(day: 6, 2), calendar: calendar))
        #expect(!schedule.contains(date(day: 7, 2), calendar: calendar))
    }

    @Test func sundayNightRunsIntoMonday() {
        let schedule = hours(22, 7, days: [Self.sunday])
        #expect(schedule.contains(date(day: 7, 5), calendar: calendar))
        #expect(!schedule.contains(date(day: 1, 5), calendar: calendar))
    }

    @Test func unselectedDaysStayLoud() {
        let schedule = hours(9, 17, days: [Self.monday])
        #expect(schedule.contains(date(day: 0, 10), calendar: calendar))
        #expect(!schedule.contains(date(day: 1, 10), calendar: calendar))
    }

    @Test func equalStartAndEndIsTheWholeDay() {
        let schedule = hours(0, 0, days: [Self.saturday, Self.sunday])
        #expect(schedule.contains(date(day: 5, 0), calendar: calendar))
        #expect(schedule.contains(date(day: 6, 23, 59), calendar: calendar))
        #expect(!schedule.contains(date(day: 4, 23, 59), calendar: calendar))
    }

    @Test func pauseUntilTomorrowEndsAtEightTheNextMorning() {
        let pausedUntil = AlertPause.untilTomorrow(from: date(day: 0, 23, 15), calendar: calendar)
        #expect(pausedUntil == date(day: 1, 8))
    }

    @Test func pauseEndsAtItsTime() {
        let pausedUntil = AlertPause.forOneHour(from: date(day: 0, 10))
        #expect(AlertPause.isPaused(until: pausedUntil, at: date(day: 0, 10, 59)))
        #expect(!AlertPause.isPaused(until: pausedUntil, at: date(day: 0, 11)))
        #expect(!AlertPause.isPaused(until: nil, at: date(day: 0, 10)))
    }
}

struct AlertBatcherTests {
    private func agent(_ pid: Int32, _ state: AgentState = .needsApproval, folder: String) -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: folder, project: nil, state: state, cpuPercent: 0, lastActivity: nil)
    }

    @Test func alertsPassStraightThroughWhenNotQuiet() {
        var batcher = AlertBatcher()
        let alerts = [agent(1, folder: "/a")]
        #expect(batcher.deliver(alerts, current: alerts, isQuiet: false, handling: .summarize) == AlertDelivery(individual: alerts, summary: []))
    }

    @Test func quietPeriodHoldsAlertsAndFlushesOneSummary() {
        var batcher = AlertBatcher()
        let first = agent(1, folder: "/a"), second = agent(2, .yourTurn, folder: "/b"), third = agent(3, folder: "/c")
        #expect(batcher.deliver([first], current: [first], isQuiet: true, handling: .summarize) == .none)
        #expect(batcher.deliver([second, third], current: [first, second, third], isQuiet: true, handling: .summarize) == .none)
        let delivery = batcher.deliver([], current: [first, second, third], isQuiet: false, handling: .summarize)
        #expect(delivery.summary.map(\.pid) == [1, 2, 3])
        #expect(batcher.held.isEmpty)
        #expect(batcher.deliver([], current: [first, second, third], isQuiet: false, handling: .summarize) == .none)
    }

    @Test func summaryLeavesOutAgentsThatStoppedWaiting() {
        var batcher = AlertBatcher()
        let first = agent(1, folder: "/a"), second = agent(2, folder: "/b")
        _ = batcher.deliver([first, second], current: [first, second], isQuiet: true, handling: .summarize)
        let delivery = batcher.deliver([], current: [first, agent(2, .working, folder: "/b")], isQuiet: false, handling: .summarize)
        #expect(delivery.summary.map(\.pid) == [1])
    }

    @Test func heldAlertsKeepOnePerFolder() {
        var batcher = AlertBatcher()
        _ = batcher.deliver([agent(1, folder: "/a")], current: [], isQuiet: true, handling: .summarize)
        _ = batcher.deliver([agent(2, .yourTurn, folder: "/a")], current: [], isQuiet: true, handling: .summarize)
        #expect(batcher.held.map(\.pid) == [2])
    }

    @Test func newAlertInASummarizedFolderIsNotPostedTwice() {
        var batcher = AlertBatcher()
        let held = agent(1, folder: "/a"), fresh = agent(2, folder: "/a"), other = agent(3, folder: "/b")
        _ = batcher.deliver([held], current: [held], isQuiet: true, handling: .summarize)
        let delivery = batcher.deliver([fresh, other], current: [held, fresh, other], isQuiet: false, handling: .summarize)
        #expect(delivery.summary.map(\.pid) == [1])
        #expect(delivery.individual.map(\.pid) == [3])
    }

    @Test func dropHandlingDiscardsQuietAlerts() {
        var batcher = AlertBatcher()
        let first = agent(1, folder: "/a")
        #expect(batcher.deliver([first], current: [first], isQuiet: true, handling: .drop) == .none)
        #expect(batcher.deliver([], current: [first], isQuiet: false, handling: .drop) == .none)
    }
}
