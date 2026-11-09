import AppKit
import IOKit.pwr_mgt

/// Keeps the Mac from idle sleeping while held. The display may still sleep. Released when the app quits.
@MainActor
final class SleepAssertion {
    private static let reason = "Flightdeck: AI agents are working" as CFString
    private var assertionID: IOPMAssertionID?
    private var terminationObserver: NSObjectProtocol?

    init() {
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.release() }
        }
    }

    var isHeld: Bool { assertionID != nil }

    func setHeld(_ shouldHold: Bool) {
        shouldHold ? acquire() : release()
    }

    private func acquire() {
        guard assertionID == nil else { return }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), Self.reason, &id)
        if result == kIOReturnSuccess { assertionID = id }
    }

    func release() {
        guard let id = assertionID else { return }
        IOPMAssertionRelease(id)
        assertionID = nil
    }
}
