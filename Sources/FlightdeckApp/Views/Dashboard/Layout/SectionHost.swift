import MonitorCore
import SwiftUI

/// Draws one section by kind.
struct SectionHost: View {
    @Environment(MonitorStore.self) private var store
    var kind: SectionKind
    var context: SectionContext

    var body: some View {
        switch kind {
        case .needsYou:
            let hero = store.heroAgent(excluding: context.snoozedAgentIDs.wrappedValue)
            LayoutNeedsYou(agent: hero, othersCount: max(store.needsYouGroups.count - 1, 0)) { context.snoozedAgentIDs.wrappedValue.insert($0.id) }
        case .clock:
            ClockSection()
        case .resources:
            LayoutResources()
        case .yourTurn:
            LayoutAgentColumn(column: .yourTurn, groups: AgentBoardColumn.yourTurn.groups(from: agents), navigate: context.navigate)
        case .workingAgents:
            LayoutAgentColumn(column: .working, groups: AgentBoardColumn.working.groups(from: agents), navigate: context.navigate)
        case .idleAgents:
            LayoutAgentColumn(column: .idle, groups: AgentBoardColumn.idle.groups(from: agents), navigate: context.navigate)
        case .projects:
            LayoutProjects(searchQuery: context.searchQuery, navigate: context.navigate)
        case .devServers:
            LayoutDevServers()
        case .otherPorts:
            OtherPortsSection()
        case .agentSessions:
            AgentSessionsSection()
        case .usageLimits:
            LayoutUsageLimits()
        case .spend:
            SpendSection()
        case .processTable:
            ProcessTableSection()
        case .widget(let id):
            WidgetSection(widgetID: id)
        }
    }

    private var agents: [AgentSession] {
        store.agents(matching: context.searchQuery)
    }
}

extension MonitorStore {
    /// Approvals come first; then whoever has waited on you the longest.
    func heroAgent(excluding snoozed: Set<Int32>) -> AgentSession? {
        agents
            .filter { $0.state.needsYou && !snoozed.contains($0.id) }
            .min { lhs, rhs in
                if (lhs.state == .needsApproval) != (rhs.state == .needsApproval) { return lhs.state == .needsApproval }
                return (lhs.lastActivity ?? .distantFuture) < (rhs.lastActivity ?? .distantFuture)
            }
    }

    /// The agents waiting on you, one per session group as on the "Your turn" cards. The menu bar
    /// label, its panel and the overview headline all count these.
    var needsYouGroups: [AgentGroup] {
        AgentBoardColumn.yourTurn.groups(from: agents)
    }

    func agents(matching query: String) -> [AgentSession] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        return query.isEmpty ? agents : agents.filter { $0.searchText.contains(query) }
    }

    func projects(matching query: String) -> [ProjectSummary] {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        let projects = ProjectSummary.make(ports: devServers, agents: agents)
        return query.isEmpty ? projects : projects.filter { $0.searchText.contains(query) }
    }
}
