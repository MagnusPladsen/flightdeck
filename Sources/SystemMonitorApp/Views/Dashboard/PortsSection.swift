import SwiftUI

struct PortsSection: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        List {
            Section("Dev servers") {
                if store.devServers.isEmpty { EmptyHint(text: "No dev servers running") }
                ForEach(store.devServers) { PortRow(port: $0) }
            }
            if settings.showSystemPorts {
                Section("Other listening ports") {
                    ForEach(store.ports.filter { !$0.isDevServer }) { PortRow(port: $0) }
                }
            }
        }
        .themedScrollBackground()
        .toolbar {
            Toggle("Show system ports", isOn: $settings.showSystemPorts)
        }
    }
}

struct AgentsSection: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        List {
            Section("Sessions") {
                if store.visibleAgents.isEmpty { EmptyHint(text: "No agent sessions found") }
                ForEach(store.visibleAgents) { AgentRow(agent: $0) }
            }
            Section("Usage limits") {
                if store.usage.isEmpty { EmptyHint(text: "Loading usage…") }
                ForEach(store.usage) { ProviderUsageView(usage: $0).padding(.vertical, 4) }
                if !settings.claudeLimitsEnabled {
                    Text("Claude limit percentages are off. Turn them on in Settings › AI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .themedScrollBackground()
        .toolbar {
            Toggle("Show idle agents", isOn: $settings.showIdleAgents)
        }
    }
}
