import MonitorCore
import SwiftUI

/// Dev servers in the form each layout was designed with.
struct LayoutDevServers: View {
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        switch layout {
        case .terminal, .cockpit, .mission: PortTable()
        case .macOS, .bento: ServerCards()
        case .editorial: ServerSentenceList()
        default: DevServersSection()
        }
    }
}

/// PORT · PROJECT · STACK · BRANCH · PID, one row per server; a row opens it in the browser.
private struct PortTable: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ConceptHeading(title: layout == .terminal ? "┤ ports ├" : "Dev servers", count: store.devServers.count)
            row(["PORT", "PROJECT", "STACK", "BRANCH", layout == .mission ? "STATUS" : "PID"], isHeader: true)
            if store.devServers.isEmpty {
                Text("no servers listening").font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.muted)
            }
            ForEach(store.devServers) { port in
                Button { store.openInBrowser(port: port.port) } label: {
                    row([":\(port.port)", port.title, port.framework?.displayName ?? port.processName, port.project?.branch ?? "—", layout == .mission ? "NOMINAL" : "\(port.pid)"], isHeader: false)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open localhost:\(port.port)")
            }
        }
    }

    private func row(_ cells: [String], isHeader: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(cell)
                    .foregroundStyle(color(column: index, isHeader: isHeader))
                    .fontWeight(index == 0 && !isHeader ? .bold : .regular)
                    .frame(maxWidth: index == 1 ? .infinity : nil, alignment: .leading)
                    .frame(width: Self.widths[index], alignment: .leading)
                    .lineLimit(1)
            }
        }
        .font(.system(size: isHeader ? 11 : 13, design: layout == .mission ? .default : .monospaced))
        .tracking(isHeader ? 1.2 : 0)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(isHeader ? theme.border : theme.overlay).frame(height: 1) }
    }

    private static let widths: [CGFloat?] = [64, nil, 110, 140, 70]

    private func color(column: Int, isHeader: Bool) -> Color {
        if isHeader { return theme.muted }
        switch column {
        case 0: return theme.primary
        case 4 where layout == .mission: return theme.success
        case 2, 3, 4: return theme.muted
        default: return theme.foreground
        }
    }
}

/// macOS and Bento: a grid of cards, three to a row.
private struct ServerCards: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConceptHeading(title: "Dev servers", count: store.devServers.count)
            if store.devServers.isEmpty {
                Text("No dev servers running").foregroundStyle(theme.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                ForEach(store.devServers) { card($0) }
            }
        }
    }

    private func card(_ port: ListeningPort) -> some View {
        Button { store.openInBrowser(port: port.port) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    StatusDot(color: theme.success, size: 7)
                    Text(port.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer()
                }
                Text(verbatim: ":\(port.port)").font(.system(size: layout == .bento ? 26 : 20, weight: .bold, design: .monospaced)).foregroundStyle(theme.primary)
                HStack(spacing: 6) {
                    if let framework = port.framework { FrameworkBadge(framework: framework) }
                    if let branch = port.project?.branch { Chip(text: branch, systemImage: "arrow.triangle.branch") }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.overlay.opacity(0.6), in: RoundedRectangle(cornerRadius: layout == .bento ? 18 : 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open localhost:\(port.port)")
    }
}

/// Editorial: a sentence headline over a plain list.
private struct ServerSentenceList: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let count = store.devServers.count
        VStack(alignment: .leading, spacing: 12) {
            Text("\(SentenceWords.number(count, capitalized: true)) server\(count == 1 ? " is" : "s are") listening")
                .font(.system(size: 34, weight: .regular, design: .serif))
            Rectangle().fill(theme.border).frame(height: 1)
            ForEach(store.devServers) { port in
                HStack(alignment: .firstTextBaseline) {
                    Text(port.title).font(.system(size: 17, design: .serif))
                    if let framework = port.framework { Text(framework.displayName).font(.system(size: 13).italic()).foregroundStyle(theme.muted) }
                    Spacer()
                    Button { store.openInBrowser(port: port.port) } label: { Text(verbatim: ":\(port.port)") }.buttonStyle(.plain).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(theme.primary)
                }
                Rectangle().fill(theme.border.opacity(0.6)).frame(height: 1)
            }
        }
    }
}

// MARK: - Projects

/// The Projects layout: one card per project, its checkouts inside with their ports and agents as chips.
struct LayoutProjects: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.dashboardLayout) private var layout
    var searchQuery: String
    var navigate: (DashboardPage) -> Void

    var body: some View {
        if layout == .projects {
            ProjectCards(groups: ProjectGroup.make(ports: store.devServers, agents: store.agents(matching: searchQuery)))
        } else {
            ProjectsList(projects: store.projects(matching: searchQuery), totalPorts: store.devServers.count, navigate: navigate)
        }
    }
}

/// A project and its checkouts, each with the servers and agents running there.
struct ProjectGroup: Identifiable {
    struct Checkout: Identifiable {
        var id: String { label }
        let label: String
        let isWorktree: Bool
        var ports: [ListeningPort]
        var agents: [AgentSession]
    }

    var id: String { name }
    let name: String
    var checkouts: [Checkout]

    static func make(ports: [ListeningPort], agents: [AgentSession]) -> [ProjectGroup] {
        var groups: [String: [String: Checkout]] = [:]
        func checkout(for project: DevProject) -> Checkout {
            let label = project.isWorktree ? "⧉ " + (project.worktreeName ?? "worktree") : "⎇ " + (project.branch ?? "main")
            return groups[project.name]?[label] ?? Checkout(label: label, isWorktree: project.isWorktree, ports: [], agents: [])
        }
        for port in ports {
            guard let project = port.project else { continue }
            var entry = checkout(for: project)
            entry.ports.append(port)
            groups[project.name, default: [:]][entry.label] = entry
        }
        for agent in agents where agent.state != .idle {
            guard let project = agent.project else { continue }
            var entry = checkout(for: project)
            entry.agents.append(agent)
            groups[project.name, default: [:]][entry.label] = entry
        }
        return groups.map { ProjectGroup(name: $0.key, checkouts: $0.value.values.sorted { $0.label < $1.label }) }
            .sorted { $0.name < $1.name }
    }
}

private struct ProjectCards: View {
    @Environment(\.theme) private var theme
    var groups: [ProjectGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConceptHeading(title: "Projects", count: groups.count)
            if groups.isEmpty { Text("No projects with servers or agents right now.").foregroundStyle(theme.muted) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                ForEach(groups) { ProjectCard(group: $0) }
            }
        }
    }
}

private struct ProjectCard: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var group: ProjectGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.name).font(.system(size: 18, weight: .bold)).lineLimit(1)
            ForEach(group.checkouts) { checkout in
                VStack(alignment: .leading, spacing: 8) {
                    Text(checkout.label).font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(checkout.isWorktree ? theme.info : theme.accent)
                    FlowChips(items: chips(for: checkout))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.overlay.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
    }

    private func chips(for checkout: ProjectGroup.Checkout) -> [TintedChip.Item] {
        checkout.ports.map { port in
            TintedChip.Item(id: "port\(port.id)", text: ":\(port.port) \(port.framework?.displayName ?? "")", color: theme.primary) { store.openInBrowser(port: port.port) }
        } + checkout.agents.map { agent in
            TintedChip.Item(id: "agent\(agent.pid)", text: "\(agent.tool.displayName) · \(agent.state.label.lowercased())", color: agent.state.color(in: theme)) { store.openTerminal(for: agent) }
        }
    }
}

/// Small colour-tinted capsule that acts on click.
struct TintedChip: View {
    struct Item: Identifiable {
        let id: String
        let text: String
        let color: Color
        let action: () -> Void
    }

    var item: Item

    var body: some View {
        Button(action: item.action) {
            Text(item.text.trimmingCharacters(in: .whitespaces)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .foregroundStyle(item.color)
                .background(item.color.opacity(0.17), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Chips that wrap onto new lines.
private struct FlowChips: View {
    var items: [TintedChip.Item]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items) { TintedChip(item: $0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + size.width > width, !rows[rows.count - 1].indices.isEmpty {
                let previous = rows[rows.count - 1]
                rows.append(Row(y: previous.y + previous.height + spacing))
            }
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

// MARK: - Usage limits

/// Usage limits in the form each layout was designed with.
struct LayoutUsageLimits: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        switch layout {
        case .bento: limitGrid(title: "Limits", transform: { $0 }, size: 40)
        case .mission: limitGrid(title: "Propellant", transform: { 100 - $0 }, size: 34, suffix: " left")
        case .cockpit: ledLimits
        case .terminal: textLimits
        default: UsageLimitsSection()
        }
    }

    private struct LimitItem: Identifiable {
        var id: String { "\(tool.rawValue)-\(window.label)" }
        let tool: AgentTool
        let window: UsageWindow
    }

    private var windows: [LimitItem] {
        store.usage.flatMap { usage in usage.windows.map { LimitItem(tool: usage.tool, window: $0) } }
    }

    /// Big percentages, two to a row. Mission control shows what is left rather than what is used.
    private func limitGrid(title: String, transform: @escaping (Double) -> Double, size: CGFloat, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ConceptHeading(title: title)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(windows) { item in
                    let color = UsageLevel.color(forPercent: item.window.usedPercent, in: theme)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.tool.displayName) \(item.window.label)".uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(theme.muted).lineLimit(1)
                        Text("\(Int(transform(item.window.usedPercent).rounded()))%\(suffix)").font(.system(size: size, weight: layout == .mission ? .ultraLight : .bold).monospacedDigit()).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.5)
                        Text(Formatters.resetCountdown(item.window.resetsAt) ?? "").font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(1)
                        if let forecast = store.limitForecast(for: item.tool, window: item.window) { ForecastText(forecast: forecast).font(.system(size: 11)) }
                    }
                    .padding(layout == .bento ? 14 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(layout == .bento ? theme.overlay : .clear, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            if windows.isEmpty { Text("No usage data yet").foregroundStyle(theme.muted) }
        }
    }

    private var ledLimits: some View {
        VStack(alignment: .leading, spacing: 10) {
            ConceptHeading(title: "Quota")
            ForEach(windows) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(item.tool.rawValue).\(item.window.label)".uppercased()).foregroundStyle(theme.muted)
                        Spacer()
                        Text(String(format: "%03d", Int(item.window.usedPercent.rounded()))).foregroundStyle(theme.primary).fontWeight(.bold)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    LEDBar(fraction: item.window.usedPercent / 100, color: UsageLevel.color(forPercent: item.window.usedPercent, in: theme))
                }
            }
        }
    }

    private var textLimits: some View {
        VStack(alignment: .leading, spacing: 6) {
            ConceptHeading(title: "┤ limits ├")
            ForEach(windows) { item in
                let filled = Int((item.window.usedPercent / 100 * 20).rounded())
                HStack(spacing: 10) {
                    Text("\(item.tool.rawValue) \(item.window.label.lowercased())").frame(width: 110, alignment: .leading)
                    (Text(String(repeating: "■", count: filled)).foregroundStyle(UsageLevel.color(forPercent: item.window.usedPercent, in: theme))
                        + Text(String(repeating: "■", count: max(20 - filled, 0))).foregroundStyle(theme.overlay))
                    Text("\(Int(item.window.usedPercent.rounded()))%")
                }
                .font(.system(size: 13, design: .monospaced))
            }
        }
    }
}
