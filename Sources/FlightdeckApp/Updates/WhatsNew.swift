import Foundation
import MonitorCore
import Observation

/// The changelog bundled as CHANGELOG.md. It shows the new entries once after an update, and on
/// request from Settings.
@MainActor
@Observable
final class WhatsNew {
    private(set) var entries: [ChangelogEntry] = []
    private(set) var isPresented = false
    @ObservationIgnored private let allEntries: [ChangelogEntry]
    @ObservationIgnored private let defaults: UserDefaults
    private static let lastSeenVersionKey = "whatsNewLastSeenVersion"
    private static let sparkleHasLaunchedBeforeKey = "SUHasLaunchedBefore"
    private static let recentLimit = 5

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let changelog = bundle.url(forResource: "CHANGELOG", withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        allEntries = changelog.map(Changelog.parse) ?? []
        showIfUpdated(currentVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    var isAvailable: Bool { !allEntries.isEmpty }

    func showRecent() {
        present(Array(allEntries.prefix(Self.recentLimit)))
    }

    func dismiss() {
        isPresented = false
    }

    /// A fresh install only records its version; an update shows what changed since the last one opened.
    /// Versions before What's new stored nothing, so an earlier Sparkle launch means an update to this one.
    private func showIfUpdated(currentVersion: String?) {
        guard let currentVersion else { return }
        defer { defaults.set(currentVersion, forKey: Self.lastSeenVersionKey) }
        if let lastSeen = defaults.string(forKey: Self.lastSeenVersionKey) {
            present(Changelog.entries(allEntries, after: lastSeen, through: currentVersion))
        } else if defaults.bool(forKey: Self.sparkleHasLaunchedBeforeKey) {
            present(allEntries.filter { $0.version == currentVersion })
        }
    }

    private func present(_ entries: [ChangelogEntry]) {
        guard !entries.isEmpty else { return }
        self.entries = entries
        isPresented = true
    }
}
