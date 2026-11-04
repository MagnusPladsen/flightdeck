import MonitorCore
import SwiftUI

struct AgentSessionsSection: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Sessions", count: store.visibleAgents.count) {
                Toggle("Show idle", isOn: $settings.showIdleAgents).toggleStyle(.checkbox).font(.system(size: 13))
            }
            HairlineRows(items: store.visibleAgents, emptyText: "No agent sessions found") { AgentRow(agent: $0) }
        }
    }
}

struct UsageLimitsSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Usage limits")
            HairlineRows(items: store.usage, emptyText: "Loading usage…") { ProviderUsageView(usage: $0) }
            if !store.settings.claudeLimitsEnabled {
                Text("Claude limit percentages are off. Turn them on in Settings › AI.")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 8)
            }
        }
    }
}
