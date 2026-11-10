import Foundation
import MonitorCore
import Observation

/// Keeps the achievement ledger: fed by the polls and by what you do in the app, saved to Application Support.
@MainActor
@Observable
final class AchievementTracker {
    nonisolated static let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Flightdeck/achievements.json")
    private static let saveInterval: TimeInterval = 60

    private(set) var ledger = AchievementLedger()
    /// The latest unlocks, for the toast on the dashboard; cleared when it is dismissed.
    private(set) var recentUnlocks: [Achievement] = []
    @ObservationIgnored private var lastSavedAt = Date.distantPast
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var isDemo = false
    @ObservationIgnored private var lastTrackKey: String?
    @ObservationIgnored private var lastMusicAt: Date?
    @ObservationIgnored var onUnlock: ([Achievement]) -> Void = { _ in }

    var unlockedCount: Int { AchievementCatalog.all.filter(ledger.isUnlocked).count }

    func observe(_ observation: AchievementObservation, track: NowPlayingTrack?, now: Date = Date()) {
        guard !isDemo else { return }
        loadIfNeeded()
        ledger.observe(observation, at: now)
        observeMusic(track, now: now)
        changed(now: now)
    }

    /// Counts something you did, such as a palette command or a stopped process.
    func record(_ metric: AchievementMetric, by amount: Double = 1) {
        guard !isDemo, amount > 0 else { return }
        loadIfNeeded()
        ledger.add(amount, to: metric)
        changed(now: Date())
    }

    func dismissRecentUnlocks() {
        recentUnlocks = []
    }

    func showDemo(_ ledger: AchievementLedger) {
        isDemo = true
        hasLoaded = true
        self.ledger = ledger
    }

    private func observeMusic(_ track: NowPlayingTrack?, now: Date) {
        guard let track, track.isPlaying else {
            lastMusicAt = nil
            return
        }
        let key = "\(track.title)|\(track.artist ?? "")"
        if key != lastTrackKey { ledger.add(to: .tracksHeard) }
        lastTrackKey = key
        if let last = lastMusicAt, now.timeIntervalSince(last) <= 60 { ledger.add(now.timeIntervalSince(last) / 3600, to: .musicHours) }
        lastMusicAt = now
    }

    private func changed(now: Date) {
        isDirty = true
        let unlocked = ledger.unlockReached(at: now)
        if !unlocked.isEmpty {
            recentUnlocks = Array((unlocked + recentUnlocks).prefix(4))
            onUnlock(unlocked)
        }
        guard !unlocked.isEmpty || now.timeIntervalSince(lastSavedAt) >= Self.saveInterval else { return }
        save(now: now)
    }

    private func save(now: Date) {
        guard isDirty else { return }
        isDirty = false
        lastSavedAt = now
        let ledger = ledger
        Task.detached { try? ledger.save(to: Self.fileURL) }
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        ledger = AchievementLedger.load(from: Self.fileURL)
    }
}
