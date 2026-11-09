import SwiftUI

/// Keeping the Mac awake while agents work.
struct KeepAwakeSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        Section {
            Toggle("Keep the Mac awake while agents work", isOn: Binding(get: { store.settings.keepAwakeWhileAgentsWork }, set: { store.setKeepAwakeWhileAgentsWork($0) }))
        } header: {
            Text("Keep awake")
        } footer: {
            Text("Stops idle sleep while an agent is working or seems stuck, and lets the Mac sleep again once none are. The display can still sleep. Also on the overview and the AI Agents page.")
        }
    }
}
