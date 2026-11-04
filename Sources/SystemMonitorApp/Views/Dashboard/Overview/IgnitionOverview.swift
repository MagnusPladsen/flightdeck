import MonitorCore
import SwiftUI

/// The Ignition layout: who needs you, machine resources, the agent board and projects.
struct IgnitionOverview: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var navigate: (DashboardPage) -> Void

    @State private var searchText = ""
    @State private var snoozedAgentIDs: Set<Int32> = []

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    IgnitionHeader(searchText: $searchText)
                    NeedsYouHero(agent: heroAgent) { agent in snoozedAgentIDs.insert(agent.id) }
                    if !store.settings.resourcesInSidebar { ResourceStrip() }
                    AgentBoard(agents: matchingAgents, navigate: navigate)
                    ProjectsList(projects: matchingProjects, totalPorts: store.devServers.count, navigate: navigate)
                }
                .padding(32)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            if store.settings.resourcesInSidebar {
                ResourceSidebar(navigate: navigate)
                    .frame(width: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(theme.background)
        .animation(.smooth(duration: 0.3), value: store.settings.resourcesInSidebar)
    }

    /// Approvals come first; then whoever has waited on you the longest.
    private var heroAgent: AgentSession? {
        store.agents
            .filter { $0.state.needsYou && !snoozedAgentIDs.contains($0.id) }
            .min { lhs, rhs in
                if (lhs.state == .needsApproval) != (rhs.state == .needsApproval) { return lhs.state == .needsApproval }
                return (lhs.lastActivity ?? .distantFuture) < (rhs.lastActivity ?? .distantFuture)
            }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var matchingAgents: [AgentSession] {
        guard !query.isEmpty else { return store.agents }
        return store.agents.filter { $0.searchText.contains(query) }
    }

    private var matchingProjects: [ProjectSummary] {
        let projects = ProjectSummary.make(ports: store.devServers, agents: store.agents)
        guard !query.isEmpty else { return projects }
        return projects.filter { $0.searchText.contains(query) }
    }
}
