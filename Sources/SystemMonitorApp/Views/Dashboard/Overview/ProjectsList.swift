import MonitorCore
import SwiftUI

/// A repository with its checkouts, dev-server ports and the most urgent agent status.
struct ProjectSummary: Identifiable {
    var id: String { name }
    let name: String
    let checkouts: [String]
    let ports: [Int]
    let agents: [AgentSession]

    var urgentState: AgentState? {
        let priority: [AgentState] = [.needsApproval, .yourTurn, .working, .idle]
        return priority.first { state in agents.contains { $0.state == state } }
    }

    var searchText: String {
        ([name] + checkouts + ports.map(String.init)).joined(separator: " ").lowercased()
    }

    static func make(ports: [ListeningPort], agents: [AgentSession]) -> [ProjectSummary] {
        let projects = ports.compactMap(\.project) + agents.compactMap(\.project)
        let names = Array(Set(projects.map(\.name)))
        return names.map { name in
            let checkouts = projects.filter { $0.name == name }.compactMap(checkoutLabel)
            return ProjectSummary(
                name: name,
                checkouts: checkouts.reduce(into: []) { if !$0.contains($1) { $0.append($1) } },
                ports: Array(Set(ports.filter { $0.project?.name == name }.map(\.port))).sorted(),
                agents: agents.filter { $0.project?.name == name }
            )
        }
        .sorted { lhs, rhs in
            let lhsRank = rank(lhs.urgentState), rhsRank = rank(rhs.urgentState)
            return lhsRank == rhsRank ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : lhsRank < rhsRank
        }
    }

    private static func checkoutLabel(_ project: DevProject) -> String? {
        project.isWorktree ? "⧉ " + (project.worktreeName ?? "worktree") : project.branch
    }

    private static func rank(_ state: AgentState?) -> Int {
        switch state {
        case .needsApproval?, .yourTurn?: 0
        case .working?: 1
        default: 2
        }
    }
}

struct ProjectsList: View {
    @Environment(\.theme) private var theme
    var projects: [ProjectSummary]
    var totalPorts: Int
    var navigate: (DashboardSection) -> Void
    private static let rowLimit = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Projects").font(.system(size: 15, weight: .bold))
                Text("\(projects.count)").font(.system(size: 15)).foregroundStyle(theme.muted)
                Spacer()
                SeeAllLink(title: "See all \(projects.count) projects and \(totalPorts) ports →") { navigate(.ports) }
            }
            if projects.isEmpty {
                Text("No projects running").font(.system(size: 13)).foregroundStyle(theme.muted).padding(.vertical, 14)
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                ForEach(projects.prefix(Self.rowLimit)) { project in
                    Hairline().gridCellColumns(4)
                    GridRow {
                        Text(project.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
                        Text(project.checkouts.joined(separator: "  ")).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
                        Text(project.ports.map { ":\($0)" }.joined(separator: " ")).font(.system(size: 13, design: .monospaced))
                        Text(statusText(project)).font(.system(size: 13)).foregroundStyle(statusColor(project)).gridColumnAlignment(.trailing)
                    }
                    .font(.system(size: 15))
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func statusText(_ project: ProjectSummary) -> String {
        guard let state = project.urgentState else { return "" }
        let count = project.agents.filter { $0.state == state }.count
        switch state {
        case .needsApproval: return "needs you"
        case .yourTurn: return count > 1 ? "\(count) your turn" : "your turn"
        case .working: return count > 1 ? "\(count) working" : "\(project.agents.first { $0.state == .working }?.tool.displayName ?? "agent") working"
        case .idle: return "idle"
        }
    }

    private func statusColor(_ project: ProjectSummary) -> Color {
        project.urgentState?.color(in: theme) ?? theme.muted
    }
}
