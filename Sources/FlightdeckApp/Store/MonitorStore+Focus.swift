import Foundation
import MonitorCore

extension MonitorStore {
    var alertQuietReason: AlertQuietReason? {
        settings.quietReason(isFocused: focusStatus.isFocused)
    }

    /// Asks for permission to read the Focus state the first time it's turned on.
    func setQuietDuringFocus(_ isEnabled: Bool) {
        settings.quietDuringFocus = isEnabled
        guard isEnabled else { return }
        Task { await focusStatus.requestAuthorization() }
    }
}
