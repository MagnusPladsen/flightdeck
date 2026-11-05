import MonitorCore
import SwiftUI

/// When Flightdeck posts a notification, and how to keep other apps from doubling it.
struct AlertSettings: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var settings = store.settings
        Form {
            Section {
                Toggle("Alert me when an agent needs me", isOn: Binding(get: { settings.alertsEnabled }, set: { store.setAlertsEnabled($0) }))
            } footer: {
                Text("You can also turn alerts on and off with the bell in the menu bar panel. Clicking an alert opens the agent's terminal.")
            }
            Section("Alert when") {
                Toggle("An agent asks to run something", isOn: $settings.alertsOnApproval)
                Toggle("An agent finishes and waits for your next prompt", isOn: $settings.alertsOnYourTurn)
                Toggle("Play a sound", isOn: $settings.alertSound)
            }
            .disabled(!settings.alertsEnabled)
            Section("Agents") {
                ForEach(AgentTool.allCases, id: \.self) { tool in
                    Toggle(tool.displayName, isOn: Binding(get: { settings.alertTools.contains(tool) }, set: { settings.setAlerts($0, for: tool) }))
                }
            }
            .disabled(!settings.alertsEnabled)
            permissionSection
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Flightdeck alerts for every agent in one place. To get each alert once, turn off the notifications the agents send themselves:")
                    Text("• Claude desktop app and Codex app: System Settings › Notifications › the app › Allow notifications off.")
                    Text("• Claude Code: run /config and set Notifications to Disabled.")
                    Text("• Codex CLI: add notifications = false under [tui] in ~/.codex/config.toml.")
                    Text("• Terminals (Ghostty, kitty, iTerm2): turn off their desktop notifications or bell alerts.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } header: {
                Text("Avoid double alerts")
            }
        }
        .formStyle(.grouped)
        .themedScrollBackground()
        .task { await store.notifier.refreshAuthorization() }
    }

    @ViewBuilder
    private var permissionSection: some View {
        Section {
            if !store.notifier.isAvailable {
                Text("Alerts work only from the bundled Flightdeck.app.").foregroundStyle(.secondary)
            } else if store.notifier.authorization == .denied {
                Text("macOS is blocking Flightdeck's notifications.").foregroundStyle(theme.error)
                Button("Open Notification Settings…") { openNotificationSettings() }
            }
            Button("Send test alert") { Task { await store.notifier.sendTest(playsSound: store.settings.alertSound) } }
                .disabled(!store.notifier.isAvailable)
        }
    }

    private func openNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)") else { return }
        NSWorkspace.shared.open(url)
    }
}
