import Foundation
import MonitorCore
import Observation

enum MenuBarMetric: String, CaseIterable, Codable, Identifiable {
    case cpu, memory, workingAgents, agentsNeedingYou, network, servers, agents, claudeLimit, codexLimit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .workingAgents: "Working AI agents"
        case .agentsNeedingYou: "AI agents needing you"
        case .network: "Network"
        case .servers: "Running servers"
        case .agents: "Active AI agents"
        case .claudeLimit: "Claude 5h limit"
        case .codexLimit: "Codex 5h limit"
        }
    }

    var symbolName: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .workingAgents: "faceid"
        case .agentsNeedingYou: "circle.fill"
        case .network: "arrow.down"
        case .servers: "server.rack"
        case .agents: "sparkles"
        case .claudeLimit: "sparkle"
        case .codexLimit: "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Short text prefix used by the text label style.
    var shortTitle: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "MEM"
        case .workingAgents: "RUN"
        case .agentsNeedingYou: "YOU"
        case .network: "NET"
        case .servers: "SRV"
        case .agents: "AI"
        case .claudeLimit: "CC"
        case .codexLimit: "CX"
        }
    }
}

enum MenuBarLabelStyle: String, CaseIterable, Identifiable {
    case icons, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icons: "Icon and value"
        case .text: "Text and value"
        }
    }
}

/// User preferences, persisted to UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var menuBarMetrics: [MenuBarMetric] { didSet { save(menuBarMetrics, forKey: "menuBarMetrics") } }
    var panelShowsNetworkAndDisk: Bool { didSet { defaults.set(panelShowsNetworkAndDisk, forKey: "panelShowsNetworkAndDisk") } }
    var showSystemPorts: Bool { didSet { defaults.set(showSystemPorts, forKey: "showSystemPorts") } }
    var showIdleAgents: Bool { didSet { defaults.set(showIdleAgents, forKey: "showIdleAgents") } }
    var claudeLimitsEnabled: Bool { didSet { defaults.set(claudeLimitsEnabled, forKey: "claudeLimitsEnabled") } }
    var customWidgets: [CustomWidget] { didSet { save(customWidgets, forKey: "customWidgets") } }
    var menuBarLabelStyle: MenuBarLabelStyle { didSet { defaults.set(menuBarLabelStyle.rawValue, forKey: "menuBarLabelStyle") } }
    var themeID: String { didSet { defaults.set(themeID, forKey: "themeID") } }
    var overviewResources: [OverviewResource] { didSet { save(overviewResources, forKey: "overviewResources") } }
    var resourcesInSidebar: Bool { didSet { defaults.set(resourcesInSidebar, forKey: "resourcesInSidebar") } }
    var agentCardFields: [AgentCardField] { didSet { save(agentCardFields, forKey: "agentCardFields") } }
    var defaultAgent: AgentTool { didSet { defaults.set(defaultAgent.rawValue, forKey: "defaultAgent") } }
    /// Customised arrangements keyed by `DashboardLayout` raw value; a missing key means the default.
    var customLayouts: [String: PageLayouts] { didSet { save(customLayouts, forKey: "customLayouts") } }
    /// Nil until the user picks an editor the first time they open a project.
    var editorBundleID: String? { didSet { defaults.set(editorBundleID, forKey: "editorBundleID") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarMetrics = Self.load([MenuBarMetric].self, forKey: "menuBarMetrics", from: defaults) ?? [.cpu, .memory, .workingAgents, .agentsNeedingYou]
        panelShowsNetworkAndDisk = defaults.bool(forKey: "panelShowsNetworkAndDisk")
        showSystemPorts = defaults.bool(forKey: "showSystemPorts")
        showIdleAgents = defaults.bool(forKey: "showIdleAgents")
        claudeLimitsEnabled = defaults.bool(forKey: "claudeLimitsEnabled")
        customWidgets = Self.load([CustomWidget].self, forKey: "customWidgets", from: defaults) ?? []
        menuBarLabelStyle = defaults.string(forKey: "menuBarLabelStyle").flatMap(MenuBarLabelStyle.init(rawValue:)) ?? .text
        themeID = defaults.string(forKey: "themeID") ?? Theme.ignition.id
        overviewResources = Self.load([OverviewResource].self, forKey: "overviewResources", from: defaults) ?? OverviewResource.defaultSelection
        resourcesInSidebar = defaults.bool(forKey: "resourcesInSidebar")
        agentCardFields = Self.load([AgentCardField].self, forKey: "agentCardFields", from: defaults) ?? AgentCardField.allCases
        defaultAgent = defaults.string(forKey: "defaultAgent").flatMap(AgentTool.init(rawValue:)) ?? .claude
        editorBundleID = defaults.string(forKey: "editorBundleID")
        customLayouts = Self.load([String: PageLayouts].self, forKey: "customLayouts", from: defaults) ?? [:]
    }

    func isShowingInMenuBar(_ metric: MenuBarMetric) -> Bool {
        menuBarMetrics.contains(metric)
    }

    func setMenuBarMetric(_ metric: MenuBarMetric, shown: Bool) {
        menuBarMetrics = Self.updating(menuBarMetrics, with: metric, shown: shown)
    }

    /// Adds or removes an option while keeping the options in their declared order.
    static func updating<Option: CaseIterable & Equatable>(_ selection: [Option], with option: Option, shown: Bool) -> [Option] {
        shown ? Option.allCases.filter { $0 == option || selection.contains($0) } : selection.filter { $0 != option }
    }

    /// The arrangement in use for a layout, with removed widgets dropped and new ones placed.
    func pageLayouts(for layout: DashboardLayout) -> PageLayouts {
        (customLayouts[layout.rawValue] ?? layout.defaultPages).sanitized(available: availableSections)
    }

    func isCustomized(_ layout: DashboardLayout) -> Bool {
        customLayouts[layout.rawValue] != nil
    }

    func saveCustomLayout(_ pages: PageLayouts, for layout: DashboardLayout) {
        customLayouts[layout.rawValue] = pages
    }

    /// "Ignition", or "Ignition (custom)" once the user has rearranged it.
    func layoutTitle(_ layout: DashboardLayout) -> String {
        isCustomized(layout) ? "\(layout.title) (custom)" : layout.title
    }

    func resetLayout(_ layout: DashboardLayout) {
        customLayouts[layout.rawValue] = nil
    }

    var availableSections: [SectionKind] {
        SectionKind.builtIn + customWidgets.map { .widget($0.id) }
    }

    func upsertWidget(_ widget: CustomWidget) {
        if let index = customWidgets.firstIndex(where: { $0.id == widget.id }) {
            customWidgets[index] = widget
        } else {
            customWidgets.append(widget)
        }
    }

    private func save<Value: Encodable>(_ value: Value, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, forKey key: String, from defaults: UserDefaults) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
