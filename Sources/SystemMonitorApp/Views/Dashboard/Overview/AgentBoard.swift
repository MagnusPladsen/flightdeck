import MonitorCore
import SwiftUI

/// Agents grouped by status: a large "Your turn" section, then Working and Idle columns.
struct AgentBoard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agents: [AgentSession]
    var navigate: (DashboardSection) -> Void
    @State private var isCustomizing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if isShowing(.yourTurn), !sessions(in: .yourTurn).isEmpty {
                YourTurnSection(agents: sessions(in: .yourTurn), navigate: navigate)
            }
            let columns = [AgentBoardColumn.working, .idle].filter(isShowing)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 32, alignment: .top), count: max(columns.count, 1)), alignment: .leading, spacing: 24) {
                ForEach(columns) { column in
                    AgentColumn(column: column, agents: sessions(in: column), navigate: navigate)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Agents").font(.system(size: 15, weight: .bold))
            Text("\(agents.count) session\(agents.count == 1 ? "" : "s")").font(.system(size: 15)).foregroundStyle(theme.muted)
            Spacer()
            Button("Customize") { isCustomizing = true }
                .buttonStyle(PillButtonStyle())
                .popover(isPresented: $isCustomizing, arrowEdge: .bottom) { customizer }
            SeeAllLink(title: "See all →") { navigate(.agents) }
        }
    }

    private var customizer: some View {
        @Bindable var settings = store.settings
        return VStack(alignment: .leading, spacing: 18) {
            OptionChecklist(title: "Show on each agent", options: AgentCardField.allCases, label: \.title,
                            isOn: { settings.agentCardFields.contains($0) },
                            setOn: { settings.agentCardFields = AppSettings.updating(settings.agentCardFields, with: $0, shown: $1) })
            OptionChecklist(title: "Columns", options: AgentBoardColumn.allCases, label: \.title,
                            isOn: { settings.agentBoardColumns.contains($0) },
                            setOn: { settings.agentBoardColumns = AppSettings.updating(settings.agentBoardColumns, with: $0, shown: $1) })
        }
        .padding(16)
        .frame(minWidth: 220, alignment: .leading)
    }

    private func isShowing(_ column: AgentBoardColumn) -> Bool {
        store.settings.agentBoardColumns.contains(column)
    }

    private func sessions(in column: AgentBoardColumn) -> [AgentGroup] {
        AgentSession.grouped(agents.filter { column.contains($0.state) })
    }
}

/// The agents waiting on you, marked with an attention-coloured rail and glow.
private struct YourTurnSection: View {
    @Environment(\.theme) private var theme
    var agents: [AgentGroup]
    var navigate: (DashboardSection) -> Void
    private static let cardLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(theme.attention).frame(width: 9, height: 9)
                Text("Your turn").font(.system(size: 22, weight: .heavy)).tracking(-0.4)
                Text("\(agents.count)").font(.system(size: 22)).foregroundStyle(theme.muted)
                Spacer()
                if agents.count > Self.cardLimit {
                    SeeAllLink(title: "See all \(agents.count) →", color: theme.attention) { navigate(.agents) }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 32, alignment: .top)], alignment: .leading, spacing: 0) {
                ForEach(agents.prefix(Self.cardLimit)) { AgentCard(group: $0, isFeatured: true) }
            }
        }
        .padding(EdgeInsets(top: 20, leading: 26, bottom: 4, trailing: 0))
        .background(RadialGradient(colors: [theme.attention.opacity(0.17), .clear], center: .topLeading, startRadius: 0, endRadius: 560))
        .overlay(alignment: .leading) { Rectangle().fill(theme.attention).frame(width: 3) }
    }
}

private struct AgentColumn: View {
    @Environment(\.theme) private var theme
    var column: AgentBoardColumn
    var agents: [AgentGroup]
    var navigate: (DashboardSection) -> Void
    private static let rowLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(column.title).font(.system(size: 14, weight: .bold))
                Text("\(agents.count)").font(.system(size: 14)).foregroundStyle(theme.muted)
            }
            .padding(.bottom, 10)
            if agents.isEmpty {
                Hairline()
                Text(column == .working ? "Nothing running" : "No idle sessions")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.muted)
                    .padding(.vertical, 14)
            }
            ForEach(agents.prefix(Self.rowLimit)) { AgentCard(group: $0, isFeatured: false) }
            if agents.count > Self.rowLimit {
                SeeAllLink(title: "See all \(agents.count) →") { navigate(.agents) }.padding(.top, 10)
            }
        }
    }

    private var color: Color {
        column == .working ? AgentState.working.color(in: theme) : AgentState.idle.color(in: theme)
    }
}

/// One agent: project, what it is doing, and where. Featured cards are larger and carry actions.
private struct AgentCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var group: AgentGroup
    var isFeatured: Bool
    @State private var isHovering = false

    private var agent: AgentSession { group.agent }

    var body: some View {
        VStack(alignment: .leading, spacing: isFeatured ? 7 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(agent.displayName).font(.system(size: isFeatured ? 19 : 15, weight: isFeatured ? .heavy : .bold)).lineLimit(1)
                Spacer()
                if !isFeatured && isHovering { quickActions }
                Text(agent.ageText()).font(.system(size: isFeatured ? 13 : 12)).foregroundStyle(theme.muted)
            }
            fields
            if isFeatured {
                HStack(spacing: 10) {
                    Button("Reply in terminal") { store.openInTerminal(agent.workingDirectory) }
                        .buttonStyle(PillButtonStyle(isProminent: true))
                    EditorButton(path: agent.project?.rootPath ?? agent.workingDirectory)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, isFeatured ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(isFeatured ? theme.attention.opacity(0.18) : theme.border).frame(height: 1) }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Open in terminal") { store.openInTerminal(agent.workingDirectory) }
            Button("Open in editor") { store.openInEditor(agent.project?.rootPath ?? agent.workingDirectory) }
            Button("Reveal in Finder") { store.revealInFinder(agent.workingDirectory) }
        }
    }

    @ViewBuilder
    private var fields: some View {
        let shown = store.settings.agentCardFields
        let smallSize: CGFloat = isFeatured ? 13 : 12
        if shown.contains(.action) {
            let action = agent.actionLine
            (Text(action.verb).fontWeight(.bold).foregroundStyle(agent.state.color(in: theme)) + Text(action.detail.isEmpty ? "" : " " + action.detail))
                .font(.system(size: isFeatured ? 16 : 14))
                .lineLimit(2)
        }
        if shown.contains(.tool) {
            Text("\(agent.tool.displayName)\(group.count > 1 ? " ×\(group.count)" : "") · \(agent.state.label.lowercased())").font(.system(size: smallSize)).foregroundStyle(theme.muted)
        }
        if shown.contains(.folder) {
            Text(agent.abbreviatedPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        if shown.contains(.branch), let checkout = agent.checkoutLabel {
            Text(checkout).font(.system(size: smallSize)).foregroundStyle(agent.isWorktree ? theme.info : theme.muted).lineLimit(1)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 2) {
            IconButton(systemImage: "terminal", help: "Open in terminal") { store.openInTerminal(agent.workingDirectory) }
            IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open in editor") { store.openInEditor(agent.project?.rootPath ?? agent.workingDirectory) }
        }
        .foregroundStyle(theme.muted)
    }
}
