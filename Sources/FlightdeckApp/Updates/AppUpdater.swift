import AppKit
import Observation
import Sparkle

/// Sparkle's updater. It only starts inside the bundled Flightdeck.app, whose Info.plist carries the
/// feed URL and public key; `swift run` leaves it off.
@MainActor
@Observable
final class AppUpdater {
    private(set) var canCheckForUpdates = false
    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    init() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    var isAvailable: Bool { controller != nil }

    /// Stored by Sparkle in the app's user defaults.
    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller?.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    /// Flightdeck runs as an accessory app, so it comes forward first or Sparkle's window opens behind others.
    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }
}
