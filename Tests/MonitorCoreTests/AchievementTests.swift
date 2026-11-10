import Foundation
import Testing
@testable import MonitorCore

struct AchievementTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ text: String) -> Date { ClaudeTokenTracker.parseTimestamp(text)! }

    private func agent(_ pid: Int32, _ state: AgentState, folder: String = "/code/shop") -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: folder, project: nil, state: state, cpuPercent: 0, lastActivity: nil)
    }

    private func observe(_ ledger: inout AchievementLedger, _ agents: [AgentSession], at text: String) {
        ledger.observe(AchievementObservation(agents: agents, devServerCount: 0), at: date(text), calendar: calendar)
    }

    @Test func catalogIDsAreUniqueAndGoalsPositive() {
        let ids = AchievementCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(AchievementCatalog.all.allSatisfy { $0.goal > 0 })
        #expect(AchievementCatalog.all.count >= 50)
    }

    @Test func countsAgentTimeTurnsAndApprovals() {
        var ledger = AchievementLedger()
        observe(&ledger, [agent(1, .working), agent(2, .needsApproval)], at: "2026-11-09T10:00:00Z")
        observe(&ledger, [agent(1, .working), agent(2, .working)], at: "2026-11-09T10:00:30Z")
        observe(&ledger, [agent(1, .yourTurn), agent(2, .working)], at: "2026-11-09T10:01:00Z")
        #expect(ledger.value(of: .peakWorkingAgents) == 2)
        #expect(ledger.value(of: .approvals) == 1)
        #expect(ledger.value(of: .turns) == 1)
        #expect(abs(ledger.value(of: .agentHours) - 90.0 / 3600) < 0.0001)
    }

    @Test func longGapsDoNotCountAsAgentTime() {
        var ledger = AchievementLedger()
        observe(&ledger, [agent(1, .working)], at: "2026-11-09T10:00:00Z")
        observe(&ledger, [agent(1, .working)], at: "2026-11-09T12:00:00Z")
        #expect(ledger.value(of: .agentHours) == 0)
    }

    @Test func streaksAndOncePerDayMetrics() {
        var ledger = AchievementLedger()
        observe(&ledger, [agent(1, .working)], at: "2026-11-06T02:00:00Z")
        observe(&ledger, [agent(1, .working)], at: "2026-11-06T02:00:10Z")
        observe(&ledger, [agent(1, .working)], at: "2026-11-07T06:00:00Z")
        observe(&ledger, [agent(1, .working)], at: "2026-11-08T12:00:00Z")
        observe(&ledger, [agent(1, .working)], at: "2026-11-10T12:00:00Z")
        #expect(ledger.value(of: .longestStreak) == 3)
        #expect(ledger.value(of: .nightOwlNights) == 1)
        #expect(ledger.value(of: .earlyBirdDays) == 1)
        #expect(ledger.value(of: .weekendDays) == 2)
        #expect(ledger.value(of: .daysUsed) == 4)
    }

    @Test func unlocksOnceWhenTheGoalIsReached() {
        var ledger = AchievementLedger()
        ledger.add(to: .paletteUses)
        let now = date("2026-11-09T10:00:00Z")
        #expect(ledger.unlockReached(at: now).map(\.id) == ["shortcut"])
        #expect(ledger.unlockReached(at: now).isEmpty)
        let shortcut = AchievementCatalog.all.first { $0.id == "shortcut" }!
        #expect(ledger.isUnlocked(shortcut))
    }

    @Test func survivesASaveAndLoad() throws {
        var ledger = AchievementLedger()
        ledger.add(3, to: .tracksHeard)
        _ = ledger.unlockReached(at: date("2026-11-09T10:00:00Z"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("achievements-\(UUID()).json")
        try ledger.save(to: url)
        #expect(AchievementLedger.load(from: url) == ledger)
    }
}
