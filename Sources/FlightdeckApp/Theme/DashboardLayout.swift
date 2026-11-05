import MonitorCore
import SwiftUI

/// How the dashboard is arranged and drawn. Independent of the theme, which only sets colours.
enum DashboardLayout: String, CaseIterable, Identifiable {
    /// Needs-you headline, a resource strip, the agent board and projects by git checkout.
    case ignition
    case macOS = "macos"
    case terminal, glass, bento, cockpit, editorial, neon
    case agentFocus = "agent-focus"
    case projects, zen, mission, timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ignition: "Ignition"
        case .macOS: "macOS"
        case .terminal: "Terminal"
        case .glass: "Glass"
        case .bento: "Bento"
        case .cockpit: "Cockpit"
        case .editorial: "Editorial"
        case .neon: "Neon"
        case .agentFocus: "Agent focus"
        case .projects: "Projects"
        case .zen: "Zen"
        case .mission: "Mission control"
        case .timeline: "Timeline"
        }
    }

    var summary: String {
        switch self {
        case .ignition: "Big needs-you headline over the agent board"
        case .macOS: "Soft rounded cards, Apple style"
        case .terminal: "Monospace panes like a TUI"
        case .glass: "Frosted panels over coloured light"
        case .bento: "Borderless tiles in a tight grid"
        case .cockpit: "Amber avionics panel with scanlines"
        case .editorial: "Serif front page with hairline rules"
        case .neon: "Glowing outlines on a grid"
        case .agentFocus: "Agents as a board by state"
        case .projects: "Everything grouped by project"
        case .zen: "One calm column of what needs you"
        case .mission: "Thin outlined telemetry console"
        case .timeline: "Agent activity as a feed"
        }
    }

    /// The theme the layout was designed in, picked when the user switches to it.
    var defaultThemeID: String {
        switch self {
        case .ignition: Theme.ignition.id
        case .macOS, .agentFocus: Theme.macOS.id
        case .terminal: Theme.terminal.id
        case .glass: Theme.glass.id
        case .bento: Theme.bento.id
        case .cockpit: Theme.cockpit.id
        case .editorial: Theme.editorial.id
        case .neon: Theme.neon.id
        case .projects: Theme.tokyoNight.id
        case .zen: Theme.nord.id
        case .mission: Theme.mission.id
        case .timeline: Theme.timeline.id
        }
    }

    /// The layout as designed, before the user customises it.
    var defaultPages: PageLayouts {
        PageLayouts(pages: [
            .overview: overviewPlacements.map { SectionPlacement(kind: $0.0, span: $0.1) },
            .ports: [SectionPlacement(kind: .devServers), SectionPlacement(kind: .otherPorts)],
            .agents: [SectionPlacement(kind: .agentSessions, span: 8), SectionPlacement(kind: .usageLimits, span: 4)],
            .processes: [SectionPlacement(kind: .processTable)],
        ])
    }

    private var overviewPlacements: [(SectionKind, Int)] {
        switch self {
        case .ignition:
            [(.needsYou, 8), (.clock, 4), (.resources, 12), (.yourTurn, 12), (.workingAgents, 6), (.idleAgents, 6), (.projects, 12)]
        case .macOS:
            [(.needsYou, 8), (.clock, 4), (.resources, 12), (.yourTurn, 12), (.devServers, 8), (.usageLimits, 4), (.workingAgents, 6), (.idleAgents, 6)]
        case .terminal:
            [(.resources, 12), (.yourTurn, 12), (.devServers, 12), (.workingAgents, 6), (.usageLimits, 6)]
        case .glass:
            [(.needsYou, 12), (.resources, 12), (.devServers, 8), (.usageLimits, 4), (.yourTurn, 12)]
        case .bento:
            [(.needsYou, 8), (.clock, 4), (.resources, 12), (.devServers, 8), (.usageLimits, 4), (.yourTurn, 12), (.workingAgents, 6), (.idleAgents, 6)]
        case .cockpit:
            [(.needsYou, 8), (.clock, 4), (.resources, 12), (.devServers, 6), (.usageLimits, 6), (.yourTurn, 12), (.workingAgents, 12)]
        case .editorial:
            [(.needsYou, 12), (.resources, 12), (.devServers, 6), (.usageLimits, 6), (.yourTurn, 12), (.projects, 12)]
        case .neon:
            [(.resources, 12), (.needsYou, 8), (.clock, 4), (.devServers, 6), (.usageLimits, 6), (.yourTurn, 12)]
        case .agentFocus:
            [(.resources, 12), (.needsYou, 12), (.yourTurn, 4), (.workingAgents, 4), (.idleAgents, 4), (.usageLimits, 12)]
        case .projects:
            [(.needsYou, 12), (.projects, 12), (.resources, 12)]
        case .zen:
            [(.needsYou, 12), (.resources, 12), (.yourTurn, 12), (.devServers, 6), (.usageLimits, 6)]
        case .mission:
            [(.needsYou, 8), (.clock, 4), (.resources, 12), (.devServers, 8), (.usageLimits, 4), (.yourTurn, 12)]
        case .timeline:
            [(.needsYou, 12), (.yourTurn, 8), (.usageLimits, 4), (.workingAgents, 8), (.resources, 4)]
        }
    }

    var style: LayoutStyle {
        switch self {
        case .ignition: LayoutStyle()
        case .macOS: LayoutStyle(chrome: .card(radius: 16), columnSpacing: 16, rowSpacing: 16, padding: 24, maxWidth: 1240)
        case .terminal: LayoutStyle(fontDesign: .monospaced, chrome: .outlined(radius: 4), columnSpacing: 14, rowSpacing: 14, padding: 20, maxWidth: 1280, navigation: .rail)
        case .glass: LayoutStyle(fontDesign: .rounded, chrome: .glass(radius: 22), columnSpacing: 20, rowSpacing: 20, padding: 32, maxWidth: 1200, navigation: .rail, backdrop: .blobs)
        case .bento: LayoutStyle(chrome: .tile(radius: 28), columnSpacing: 12, rowSpacing: 12, padding: 20, maxWidth: 1280, navigation: .rail)
        case .cockpit: LayoutStyle(fontDesign: .monospaced, chrome: .outlined(radius: 0), columnSpacing: 10, rowSpacing: 10, padding: 20, maxWidth: 1280, navigation: .rail, backdrop: .scanlines, uppercaseLabels: true)
        case .editorial: LayoutStyle(fontDesign: .serif, columnSpacing: 40, rowSpacing: 40, padding: 48, navigation: .rail)
        case .neon: LayoutStyle(chrome: .outlined(radius: 0, glows: true), columnSpacing: 18, rowSpacing: 18, padding: 28, maxWidth: 1240, navigation: .rail, backdrop: .grid, uppercaseLabels: true)
        case .agentFocus: LayoutStyle(chrome: .card(radius: 14), columnSpacing: 16, rowSpacing: 16, padding: 24, maxWidth: 1280)
        case .projects: LayoutStyle(chrome: .card(radius: 16), columnSpacing: 16, rowSpacing: 16, padding: 28, maxWidth: 1240, navigation: .rail)
        case .zen: LayoutStyle(columnSpacing: 48, rowSpacing: 48, padding: 48, maxWidth: 760, navigation: .rail)
        case .mission: LayoutStyle(chrome: .outlined(radius: 0), columnSpacing: 16, rowSpacing: 16, padding: 28, maxWidth: 1280, navigation: .rail, uppercaseLabels: true)
        case .timeline: LayoutStyle(columnSpacing: 32, rowSpacing: 28, padding: 24, maxWidth: 1100)
        }
    }
}
