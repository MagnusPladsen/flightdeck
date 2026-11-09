import Foundation
import Intents
import Observation

/// Reads whether a macOS Focus is on, for keeping alerts quiet during it.
@MainActor
@Observable
final class FocusStatusMonitor {
    enum Access {
        /// `swift run` has no bundle with the usage description, and asking without one crashes.
        case unavailable
        case notDetermined
        case denied
        case authorized
    }

    private(set) var access: Access = .unavailable
    /// Nil when Flightdeck may not read the Focus state.
    private(set) var isFocused: Bool?

    let isAvailable = Bundle.main.object(forInfoDictionaryKey: "NSFocusStatusUsageDescription") != nil

    func requestAuthorization() async {
        guard isAvailable else { return refresh() }
        _ = await withCheckedContinuation { continuation in
            INFocusStatusCenter.default.requestAuthorization { continuation.resume(returning: $0) }
        }
        refresh()
    }

    func refresh() {
        guard isAvailable else { return access = .unavailable }
        let center = INFocusStatusCenter.default
        access = Self.access(for: center.authorizationStatus)
        isFocused = access == .authorized ? center.focusStatus.isFocused : nil
    }

    private static func access(for status: INFocusStatusAuthorizationStatus) -> Access {
        switch status {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}
