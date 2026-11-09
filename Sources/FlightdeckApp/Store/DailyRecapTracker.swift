import Foundation
import MonitorCore
import Observation

/// Keeps the daily recap ledger: fed by the agent polls and saved to Application Support about once a minute.
@MainActor
@Observable
final class DailyRecapTracker {
    nonisolated static let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Flightdeck/recap.json")
    private static let saveInterval: TimeInterval = 60

    private(set) var ledger = RecapLedger()
    @ObservationIgnored private var lastSavedAt = Date()
    @ObservationIgnored private var hasLoaded = false

    var today: DailyRecap { ledger.recap() }
    var yesterday: DailyRecap { ledger.recap(daysAgo: 1) }

    func record(_ agents: [AgentSession], now: Date = Date()) {
        guard !DemoData.isEnabled else { return }
        if !hasLoaded { load() }
        ledger.record(agents.map { RecapSample(pid: $0.pid, project: $0.displayName, activity: RecapActivity($0.state)) }, at: now)
        guard now.timeIntervalSince(lastSavedAt) >= Self.saveInterval else { return }
        lastSavedAt = now
        let ledger = ledger
        Task.detached { try? ledger.save(to: Self.fileURL) }
    }

    /// Posts yesterday's recap once, the first poll of a new day, when the setting is on and alerts aren't quiet.
    func announceYesterdayIfDue(settings: AppSettings, notifier: AgentNotifier, spend: SpendReport?) {
        guard settings.dailyRecapNotificationEnabled, !settings.isQuietForAlerts(),
              let recap = ledger.dayToAnnounce(lastAnnounced: settings.dailyRecapAnnouncedDay) else { return }
        settings.dailyRecapAnnouncedDay = recap.day
        notifier.postDailyRecap(recap, estimatedCost: spend?.days.first { $0.day == recap.day }?.estimatedCost)
    }

    func showDemo(_ ledger: RecapLedger) {
        hasLoaded = true
        self.ledger = ledger
    }

    private func load() {
        hasLoaded = true
        ledger = RecapLedger.load(from: Self.fileURL)
    }
}
