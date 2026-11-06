import Foundation

/// A page of the dashboard window.
public enum DashboardPage: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case overview, ports, agents, worktrees, processes, widgets
}

/// A block that can be placed on a dashboard page.
public enum SectionKind: Codable, Hashable, Sendable {
    case needsYou, clock, resources, yourTurn, workingAgents, idleAgents, projects
    case devServers, otherPorts
    case agentSessions, usageLimits
    case worktrees
    /// Token and estimated spend tracking; only available while it is turned on in Settings.
    case spend
    case processTable
    case widget(UUID)

    /// Every kind except widgets, which come from the user's widget list.
    public static let builtIn: [SectionKind] = [
        .needsYou, .clock, .resources, .yourTurn, .workingAgents, .idleAgents, .projects,
        .devServers, .otherPorts, .agentSessions, .usageLimits, .spend, .worktrees, .processTable,
    ]

    /// Where the kind goes when it is new or re-added without a page.
    public var homePage: DashboardPage {
        switch self {
        case .needsYou, .clock, .resources, .yourTurn, .workingAgents, .idleAgents, .projects: .overview
        case .devServers, .otherPorts: .ports
        case .agentSessions, .usageLimits, .spend: .agents
        case .worktrees: .worktrees
        case .processTable: .processes
        case .widget: .widgets
        }
    }

    /// Plain-text form used when a section is dragged.
    public var token: String {
        if case .widget(let id) = self { return "widget:\(id.uuidString)" }
        return String(describing: self)
    }

    public init?(token: String) {
        if token.hasPrefix("widget:") {
            guard let id = UUID(uuidString: String(token.dropFirst("widget:".count))) else { return nil }
            self = .widget(id)
        } else if let kind = Self.builtIn.first(where: { $0.token == token }) {
            self = kind
        } else {
            return nil
        }
    }

    public var defaultSpan: Int {
        switch self {
        case .workingAgents, .idleAgents: 6
        case .widget, .clock: 4
        default: GridPacking.columns
        }
    }
}

/// A section and how many of the 12 grid columns it covers.
public struct SectionPlacement: Codable, Hashable, Sendable {
    public var kind: SectionKind
    public var span: Int

    public init(kind: SectionKind, span: Int? = nil) {
        self.kind = kind
        self.span = GridPacking.snapped(span ?? kind.defaultSpan)
    }
}

/// The arrangement of sections on every page, plus the sections the user hid.
public struct PageLayouts: Codable, Hashable, Sendable {
    public var pages: [DashboardPage: [SectionPlacement]]
    public var hidden: [SectionKind]

    public init(pages: [DashboardPage: [SectionPlacement]], hidden: [SectionKind] = []) {
        self.pages = pages
        self.hidden = hidden
    }

    public func placements(on page: DashboardPage) -> [SectionPlacement] {
        pages[page] ?? []
    }

    public func page(containing kind: SectionKind) -> DashboardPage? {
        pages.first { $0.value.contains { $0.kind == kind } }?.key
    }

    /// Moves a section onto a page, before another section or at the end. Also un-hides it.
    public mutating func move(_ kind: SectionKind, to page: DashboardPage, before target: SectionKind? = nil) {
        guard kind != target else { return }
        let span = pages.values.joined().first { $0.kind == kind }?.span
        remove(kind)
        var placements = pages[page] ?? []
        let index = target.flatMap { target in placements.firstIndex { $0.kind == target } } ?? placements.endIndex
        placements.insert(SectionPlacement(kind: kind, span: span), at: index)
        pages[page] = placements
    }

    public mutating func resize(_ kind: SectionKind, span: Int) {
        for (page, placements) in pages {
            pages[page] = placements.map { $0.kind == kind ? SectionPlacement(kind: kind, span: span) : $0 }
        }
    }

    public mutating func hide(_ kind: SectionKind) {
        remove(kind)
        hidden.append(kind)
    }

    /// Drops sections that no longer exist and places new ones (e.g. a just-added widget) on their home page.
    public func sanitized(available: [SectionKind]) -> PageLayouts {
        var result = PageLayouts(pages: [:], hidden: [])
        var seen = Set<SectionKind>()
        for page in DashboardPage.allCases {
            result.pages[page] = placements(on: page).filter { available.contains($0.kind) && seen.insert($0.kind).inserted }
        }
        result.hidden = hidden.filter { available.contains($0) && seen.insert($0).inserted }
        for kind in available where !seen.contains(kind) {
            result.pages[kind.homePage, default: []].append(SectionPlacement(kind: kind))
        }
        return result
    }

    private mutating func remove(_ kind: SectionKind) {
        for (page, placements) in pages {
            pages[page] = placements.filter { $0.kind != kind }
        }
        hidden.removeAll { $0 == kind }
    }
}

/// Packs sections into rows of a 12-column grid.
public enum GridPacking {
    public static let columns = 12
    public static let spanSteps = [3, 4, 6, 8, 12]

    public static func snapped(_ span: Int) -> Int {
        spanSteps.min { abs($0 - span) < abs($1 - span) } ?? columns
    }

    /// Groups indices into rows, starting a new row when the next span does not fit.
    public static func rows(spans: [Int]) -> [[Int]] {
        var rows: [[Int]] = []
        var used = columns
        for (index, span) in spans.enumerated() {
            if used + span > columns {
                rows.append([])
                used = 0
            }
            rows[rows.count - 1].append(index)
            used += span
        }
        return rows
    }
}
