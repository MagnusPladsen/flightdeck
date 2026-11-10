import MonitorCore
import SwiftUI

struct AgentSessionsSection: View {
    @Environment(MonitorStore.self) private var store
    @State private var newAgentRequest: NewAgentRequest?

    var body: some View {
        @Bindable var settings = store.settings
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Sessions", count: store.visibleAgents.count) {
                KeepAwakePill()
                Toggle("Show idle", isOn: $settings.showIdleAgents).toggleStyle(.checkbox).font(.system(size: 13))
                Button { newAgentRequest = NewAgentRequest() } label: { Label("New agent", systemImage: "play.circle") }
                    .disabled(store.worktreeOverview.repositoryRoots.isEmpty)
            }
            .newAgentSheet($newAgentRequest)
            if store.visibleAgents.isEmpty {
                HairlineRows(items: store.visibleAgents, emptyText: "No agent sessions found") { AgentRow(agent: $0) }
            }
            let clashes = CheckoutClashFinder.clashes(among: store.agents, changes: store.agentChanges.changesByPID)
            ForEach(AgentBoardColumn.allCases) { column in
                let agents = store.visibleAgents.filter { column.contains($0.state) }
                if !agents.isEmpty {
                    AgentStatusGroup(column: column, agents: agents, clashes: clashes) { newAgentRequest = NewAgentRequest(repositoryRoot: $0.checkout) }
                }
            }
        }
    }
}

/// One status group on the agents page, ordered like the dashboard: needs you, working, idle.
private struct AgentStatusGroup: View {
    @Environment(\.theme) private var theme
    var column: AgentBoardColumn
    var agents: [AgentSession]
    var clashes: [Int32: CheckoutClash]
    var onUseWorktree: (CheckoutClash) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(column.color(in: theme)).frame(width: 7, height: 7)
                Text(column.title).font(.system(size: 13, weight: .bold))
                Text("\(agents.count)").font(.system(size: 13)).foregroundStyle(theme.muted)
            }
            .padding(.top, 18)
            .padding(.bottom, 6)
            HairlineRows(items: agents, emptyText: "") { agent in
                let clash = clashes[agent.pid]
                AgentRow(agent: agent, clash: clash) { if let clash { onUseWorktree(clash) } }
            }
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
