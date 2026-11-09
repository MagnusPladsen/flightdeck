import Foundation
import Testing
@testable import MonitorCore

struct RecapLedgerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private let start = ClaudeTokenTracker.parseTimestamp("2026-11-09T10:00:00Z")!

    private func sample(_ pid: Int32, _ project: String, _ activity: RecapActivity) -> RecapSample {
        RecapSample(pid: pid, project: project, activity: activity)
    }

    /// Records one poll every five seconds, each poll given as the activities of the listed agents.
    private func ledger(_ polls: [[RecapSample]], from date: Date? = nil) -> RecapLedger {
        var ledger = RecapLedger()
        for (index, samples) in polls.enumerated() {
            ledger.record(samples, at: (date ?? start).addingTimeInterval(Double(index) * 5), calendar: calendar)
        }
        return ledger
    }

    @Test func creditsTimeToWhatTheAgentWasDoingBeforeThePoll() {
        let polls = [[sample(1, "shop", .working)], [sample(1, "shop", .working)], [sample(1, "shop", .yourTurn)], [sample(1, "shop", .yourTurn)]]
        let recap = ledger(polls).recap(now: start, calendar: calendar)
        #expect(recap.workingSeconds == 10)
        #expect(recap.waitingSeconds == 5)
        #expect(recap.turns == 1)
        #expect(recap.sessions == 1)
    }

    @Test func longestWaitIsTheLongestUnbrokenRun() {
        let shop = { (activity: RecapActivity) in [self.sample(1, "shop", activity)] }
        let polls = [shop(.yourTurn), shop(.yourTurn), shop(.yourTurn), shop(.working), shop(.needsApproval), shop(.needsApproval)]
        let recap = ledger(polls).recap(now: start, calendar: calendar)
        #expect(recap.waitingSeconds == 20)
        #expect(recap.longestWaitSeconds == 15)
        #expect(recap.turns == 0)
    }

    @Test func approvalsAndAnswersBothCountAsOneWait() {
        let polls = [[sample(1, "shop", .needsApproval)], [sample(1, "shop", .yourTurn)], [sample(1, "shop", .yourTurn)]]
        let recap = ledger(polls).recap(now: start, calendar: calendar)
        #expect(recap.longestWaitSeconds == 10)
        #expect(recap.turns == 1)
    }

    @Test func projectsAreSplitAndBusiestComesFirst() {
        let polls = Array(repeating: [sample(1, "shop", .working), sample(2, "api", .working), sample(3, "api", .working), sample(4, "blog", .idle)], count: 3)
        let recap = ledger(polls).recap(now: start, calendar: calendar)
        #expect(recap.projects.map(\.project) == ["api", "shop"])
        #expect(recap.projects.first?.workingSeconds == 20)
        #expect(recap.projects.first?.sessions == 2)
    }

    @Test func gapsFromSleepOrQuittingAreNotCounted() {
        var ledger = RecapLedger()
        ledger.record([sample(1, "shop", .working)], at: start, calendar: calendar)
        ledger.record([sample(1, "shop", .working)], at: start.addingTimeInterval(600), calendar: calendar)
        ledger.record([sample(1, "shop", .working)], at: start.addingTimeInterval(605), calendar: calendar)
        #expect(ledger.recap(now: start, calendar: calendar).workingSeconds == 5)
    }

    @Test func keepsTwoWeeksAndSurvivesARoundTrip() throws {
        var ledger = RecapLedger()
        for day in 0..<20 {
            let date = start.addingTimeInterval(Double(day) * 86_400)
            ledger.record([sample(1, "shop", .working)], at: date, calendar: calendar)
            ledger.record([sample(1, "shop", .working)], at: date.addingTimeInterval(5), calendar: calendar)
        }
        #expect(ledger.days.count == RecapLedger.keptDays)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recap-\(UUID().uuidString)/recap.json")
        try ledger.save(to: url)
        #expect(RecapLedger.load(from: url) == ledger)
        #expect(RecapLedger.load(from: url.appendingPathExtension("missing")).days.isEmpty)
    }

    @Test func yesterdayIsAnnouncedOnceTheNextDay() {
        let ledger = ledger([[sample(1, "shop", .working)], [sample(1, "shop", .yourTurn)]])
        let nextMorning = start.addingTimeInterval(86_400)
        let yesterday = calendar.startOfDay(for: start)
        #expect(ledger.dayToAnnounce(lastAnnounced: nil, now: start, calendar: calendar) == nil)
        #expect(ledger.dayToAnnounce(lastAnnounced: nil, now: nextMorning, calendar: calendar)?.day == yesterday)
        #expect(ledger.dayToAnnounce(lastAnnounced: yesterday, now: nextMorning, calendar: calendar) == nil)
        #expect(ledger.recap(daysAgo: 1, now: nextMorning, calendar: calendar).turns == 1)
    }
}
