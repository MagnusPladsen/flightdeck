import MonitorCore
import SwiftUI

/// The agent sections (needs you, working, idle) in the form each layout was designed with.
struct LayoutAgentColumn: View {
    @Environment(\.dashboardLayout) private var layout
    var column: AgentBoardColumn
    var groups: [AgentGroup]
    var navigate: (DashboardPage) -> Void

    var body: some View {
        switch layout {
        case .agentFocus: KanbanColumn(column: column, groups: groups)
        case .timeline: AgentFeed(column: column, groups: groups, navigate: navigate)
        case .terminal, .cockpit, .mission: AgentStatusTable(column: column, groups: groups)
        default:
            if column == .yourTurn {
                YourTurnSection(agents: groups, navigate: navigate)
            } else {
                AgentColumnSection(column: column, agents: groups, navigate: navigate)
            }
        }
    }
}

extension AgentBoardColumn {
    func color(in theme: Theme) -> Color {
        switch self {
        case .yourTurn: theme.attention
        case .working: AgentState.working.color(in: theme)
        case .idle: AgentState.idle.color(in: theme)
        }
    }
}

// MARK: - Kanban (Agent focus)

private struct KanbanColumn: View {
    @Environment(\.theme) private var theme
    var column: AgentBoardColumn
    var groups: [AgentGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(column.color(in: theme)).frame(width: 8, height: 8)
                Text(column.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Text("\(groups.count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.muted)
                Spacer()
            }
            if groups.isEmpty {
                Text("Nothing here").font(.system(size: 13)).foregroundStyle(theme.muted).padding(.vertical, 8)
            }
            ForEach(groups) { KanbanCard(group: $0, column: column) }
        }
    }
}

private struct KanbanCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var group: AgentGroup
    var column: AgentBoardColumn

    var body: some View {
        let agent = group.agent
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(agent.displayName).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Spacer()
                Text(agent.ageText()).font(.system(size: 12)).foregroundStyle(theme.muted)
            }
            (Text(agent.actionLine.verb).foregroundStyle(column.color(in: theme)).bold() + Text(" " + agent.actionLine.detail))
                .font(.system(size: 13)).lineLimit(3)
            HStack(spacing: 6) {
                Chip(text: agent.tool.displayName, systemImage: agent.tool.symbolName)
                if let checkout = agent.checkoutLabel { Chip(text: checkout) }
            }
            Text(agent.abbreviatedPath).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.middle)
            Button(column == .yourTurn ? "Reply" : "Open terminal") { store.openInTerminal(agent.workingDirectory) }
                .buttonStyle(KanbanActionStyle(color: column.color(in: theme)))
        }
        .padding(12)
        .background(theme.overlay, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border))
    }
}

private struct KanbanActionStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(theme.background)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: - Feed (Timeline)

private struct AgentFeed: View {
    @Environment(\.theme) private var theme
    var column: AgentBoardColumn
    var groups: [AgentGroup]
    var navigate: (DashboardPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                Text(column.title).font(.system(size: 16, weight: .heavy))
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { Capsule().fill(theme.primary).frame(height: 4) }
                Button("Everything") { navigate(.agents) }.buttonStyle(.plain).font(.system(size: 16, weight: .medium)).foregroundStyle(theme.muted).padding(.bottom, 10)
                Spacer()
            }
            Hairline()
            if groups.isEmpty {
                Text("No posts here yet.").font(.system(size: 15)).foregroundStyle(theme.muted).padding(.vertical, 20)
            }
            ForEach(groups) { group in
                FeedPost(agent: group.agent)
                Hairline()
            }
        }
    }
}

private struct FeedPost: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(agent.displayName.prefix(1)).uppercased())
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(theme.background)
                .frame(width: 40, height: 40)
                .background(agent.state.color(in: theme), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(agent.displayName).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    Text("@\(agent.tool.rawValue) · \(agent.ageText())").font(.system(size: 15)).foregroundStyle(theme.muted).lineLimit(1)
                }
                message
                HStack(spacing: 10) {
                    if agent.state.needsYou {
                        Button("Reply") { store.openInTerminal(agent.workingDirectory) }.buttonStyle(PillButtonStyle(isProminent: true))
                    }
                    Button("Go to terminal") { store.openInTerminal(agent.workingDirectory) }.buttonStyle(PillButtonStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 14)
    }

    /// Commands show as a code block; everything else as the post's text.
    @ViewBuilder
    private var message: some View {
        let action = agent.actionLine
        if action.verb == "Running" {
            Text(agent.state == .needsApproval ? "Wants to run:" : "Running:").font(.system(size: 15))
            Text(action.detail).font(.system(size: 13, design: .monospaced))
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
        } else {
            Text("\(action.verb) \(action.detail)").font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Status table (Terminal, Cockpit, Mission control)

private struct AgentStatusTable: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout
    var column: AgentBoardColumn
    var groups: [AgentGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ConceptHeading(title: heading, count: groups.count)
            if groups.isEmpty {
                Text(layout == .terminal ? "-- none --" : "NONE").font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.muted)
            }
            ForEach(groups) { group in
                let agent = group.agent
                Button { store.openInTerminal(agent.workingDirectory) } label: {
                    HStack(spacing: 12) {
                        badge(agent.state)
                        Text(agent.displayName).fontWeight(.bold).frame(width: 160, alignment: .leading).lineLimit(1)
                        Text("\(agent.actionLine.verb.lowercased()) \(agent.actionLine.detail)").lineLimit(1)
                        Spacer(minLength: 8)
                        Text(agent.tool.rawValue.uppercased()).foregroundStyle(theme.muted)
                        Text(agent.ageText()).foregroundStyle(theme.muted).frame(width: 50, alignment: .trailing)
                    }
                    .font(.system(size: 13, design: layout == .mission ? .default : .monospaced))
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.overlay).frame(height: 1) }
            }
        }
    }

    private var heading: String {
        switch (layout, column) {
        case (.mission, .yourTurn): "Awaiting crew"
        case (.mission, .working): "Burning"
        case (.terminal, _): "┤ agents · \(column.title.lowercased()) ├"
        default: column.title
        }
    }

    @ViewBuilder
    private func badge(_ state: AgentState) -> some View {
        let color = state.color(in: theme)
        switch layout {
        case .terminal:
            Text(Self.glyph(state)).foregroundStyle(color)
        default:
            Text(Self.code(state)).font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .foregroundStyle(color).overlay(Rectangle().strokeBorder(color))
        }
    }

    static func glyph(_ state: AgentState) -> String {
        switch state {
        case .working: "●"
        case .needsApproval: "◆"
        case .yourTurn: "○"
        case .possiblyStuck: "▲"
        case .idle: "·"
        }
    }

    static func code(_ state: AgentState) -> String {
        switch state {
        case .working: "RUN"
        case .needsApproval: "APR"
        case .yourTurn: "USR"
        case .possiblyStuck: "STK"
        case .idle: "IDL"
        }
    }
}
