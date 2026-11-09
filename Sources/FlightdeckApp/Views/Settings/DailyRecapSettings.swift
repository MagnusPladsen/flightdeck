import SwiftUI

/// The optional next-day notification that sums up the agents' day.
struct DailyRecapSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        let settings = store.settings
        Section {
            Toggle("Sum up yesterday in a notification", isOn: Binding(get: { settings.dailyRecapNotificationEnabled }, set: setEnabled))
        } header: {
            Text("Daily recap")
        } footer: {
            Text("The Today section on the Agents page adds up agent hours, time spent waiting on you and turns per project while Flightdeck runs. Nothing is sent to Claude or any other service. With this on, the first poll of a new day posts a summary of the day before, outside quiet hours.")
        }
    }

    private func setEnabled(_ isEnabled: Bool) {
        store.settings.dailyRecapNotificationEnabled = isEnabled
        if isEnabled { Task { await store.notifier.requestAuthorization() } }
    }
}
