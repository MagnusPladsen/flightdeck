import Foundation
import MonitorCore

extension MonitorStore {
    var busyAgentCount: Int { KeepAwake.busyCount(in: agents) }

    var keepAwakeStatusText: String {
        KeepAwake.statusText(isEnabled: settings.keepAwakeWhileAgentsWork, busyCount: busyAgentCount)
    }

    func setKeepAwakeWhileAgentsWork(_ isEnabled: Bool) {
        settings.keepAwakeWhileAgentsWork = isEnabled
        updateKeepAwake()
    }

    /// Demo agents never keep the real Mac awake.
    func updateKeepAwake() {
        let shouldHold = !DemoData.isEnabled && KeepAwake.shouldHoldAssertion(isEnabled: settings.keepAwakeWhileAgentsWork, agents: agents)
        sleepAssertion.setHeld(shouldHold)
    }
}
