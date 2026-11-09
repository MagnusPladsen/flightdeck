import MonitorCore
import SwiftUI

/// Header shared by the agent sections: title, count, card customisation and a link to the Agents page.
private struct AgentSectionHeader: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var column: AgentBoardColumn
    var count: Int
    var isLarge: Bool
    var navigate: (DashboardPage) -> Void
    @State private var isCustomizing = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: isLarge ? 10 : 8) {
            Circle().fill(color).frame(width: isLarge ? 9 : 7, height: isLarge ? 9 : 7)
            Text(column.title).font(.system(size: isLarge ? 22 : 14, weight: isLarge ? .heavy : .bold)).tracking(isLarge ? -0.4 : 0)
            Text("\(count)").font(.system(size: isLarge ? 22 : 14)).foregroundStyle(theme.muted)
            Spacer()
            Button { isCustomizing = true } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.borderless)
                .foregroundStyle(theme.muted)
                .help("Choose what each agent shows")
                .popover(isPresented: $isCustomizing, arrowEdge: .bottom) { customizer }
            SeeAllLink(title: "See all →", color: isLarge ? theme.attention : nil) { navigate(.agents) }
        }
    }

    private var color: Color {
        switch column {
        case .yourTurn: theme.attention
        case .working: AgentState.working.color(in: theme)
        case .idle: AgentState.idle.color(in: theme)
        }
    }

    private var customizer: some View {
        @Bindable var settings = store.settings
        return OptionChecklist(title: "Show on each agent", options: AgentCardField.allCases, label: \.title,
                               isOn: { settings.agentCardFields.contains($0) },
                               setOn: { settings.agentCardFields = AppSettings.updating(settings.agentCardFields, with: $0, shown: $1) })
            .padding(16)
            .frame(minWidth: 220, alignment: .leading)
    }
}

extension AgentBoardColumn {
    func groups(from agents: [AgentSession]) -> [AgentGroup] {
        AgentSession.grouped(agents.filter { contains($0.state) })
    }
}

/// The agents waiting on you, marked with an attention-coloured rail and glow.
struct YourTurnSection: View {
    @Environment(\.theme) private var theme
    var agents: [AgentGroup]
    var navigate: (DashboardPage) -> Void
    private static let minimumCardWidth: CGFloat = 320
    private static let cardSpacing: CGFloat = 32
    @State private var width: CGFloat = 0

    /// As many cards as fit side by side, so the section never grows past one row.
    private var cardsPerRow: Int {
        max(1, Int((width + Self.cardSpacing) / (Self.minimumCardWidth + Self.cardSpacing)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AgentSectionHeader(column: .yourTurn, count: agents.count, isLarge: true, navigate: navigate)
            if agents.isEmpty {
                Text("Nobody is waiting on you.").font(.system(size: 14)).foregroundStyle(theme.muted).padding(.vertical, 12)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.cardSpacing, alignment: .top), count: cardsPerRow), alignment: .leading, spacing: 0) {
                ForEach(agents.prefix(cardsPerRow)) { AgentCard(group: $0, isFeatured: true) }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .padding(EdgeInsets(top: 20, leading: 26, bottom: 4, trailing: 0))
        .background(RadialGradient(colors: [theme.attention.opacity(0.17), .clear], center: .topLeading, startRadius: 0, endRadius: 560))
        .overlay(alignment: .leading) { Rectangle().fill(theme.attention).frame(width: 3) }
    }
}

struct AgentColumnSection: View {
    @Environment(\.theme) private var theme
    var column: AgentBoardColumn
    var agents: [AgentGroup]
    var navigate: (DashboardPage) -> Void
    private static let rowLimit = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AgentSectionHeader(column: column, count: agents.count, isLarge: false, navigate: navigate)
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

}

/// Says an agent looks busy but is making no progress, and why.
private struct StuckBadge: View {
    @Environment(\.theme) private var theme
    var reason: StuckReason

    var body: some View {
        Label("Possibly stuck · \(reason.summary)", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.warning.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

/// One agent: project, what it is doing, and where. Featured cards are larger and carry actions.
private struct AgentCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var group: AgentGroup
    var isFeatured: Bool
    @State private var isHovering = false
    @State private var isConfirmingStop = false

    private var agent: AgentSession { group.agent }

    var body: some View {
        VStack(alignment: .leading, spacing: isFeatured ? 7 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(agent.displayName).font(.system(size: isFeatured ? 19 : 15, weight: isFeatured ? .heavy : .bold)).lineLimit(1)
                Spacer()
                if !isFeatured && isHovering { quickActions }
                Text(agent.ageText()).font(.system(size: isFeatured ? 13 : 12)).foregroundStyle(theme.muted)
                if isHovering && agent.state == .yourTurn {
                    IconButton(systemImage: "xmark", help: "Clear until this agent does something new") { store.clearYourTurn(agent) }
                        .foregroundStyle(theme.muted)
                }
            }
            if let stuckReason = agent.stuckReason { StuckBadge(reason: stuckReason) }
            fields
            if isFeatured {
                HStack(spacing: 10) {
                    Button("Reply") { store.openTerminal(for: agent) }
                        .buttonStyle(PillButtonStyle(isProminent: true))
                        .help("Reply in the terminal")
                    EditorButton(path: agent.project?.rootPath ?? agent.workingDirectory)
                    Button("Stop") { isConfirmingStop = true }
                        .buttonStyle(PillButtonStyle())
                        .help("Stop this agent")
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
            Button("Go to terminal") { store.openTerminal(for: agent) }
            Button("Open in editor") { store.openInEditor(agent.project?.rootPath ?? agent.workingDirectory) }
            Button("Reveal in Finder") { store.revealInFinder(agent.workingDirectory) }
            ShowChangesButton(agent: agent)
            Divider()
            Button("Stop Agent…") { isConfirmingStop = true }
        }
        .confirmingStop(of: agent, isPresented: $isConfirmingStop)
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
            AgentWaitingMessage(agent: agent, size: smallSize)
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
        if shown.contains(.resources), let resources = agent.resourceText {
            Text(resources).font(.system(size: smallSize).monospacedDigit()).foregroundStyle(theme.muted).lineLimit(1)
                .help("The agent plus the builds, tests and tools it started")
        }
        AgentChangesPeek(agent: agent, size: smallSize)
    }

    private var quickActions: some View {
        HStack(spacing: 2) {
            AgentControlButtons(agent: agent)
            IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open in editor") { store.openInEditor(agent.project?.rootPath ?? agent.workingDirectory) }
        }
        .foregroundStyle(theme.muted)
    }
}
