import Foundation
import MonitorCore
import Observation
import SwiftUI

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
    case icons, text, bars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icons: "Icon and value"
        case .text: "Text and value"
        case .bars: "Compact bars"
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
    var notifiesSketchyBar: Bool { didSet { defaults.set(notifiesSketchyBar, forKey: "notifiesSketchyBar") } }
    var customWidgets: [CustomWidget] { didSet { save(customWidgets, forKey: "customWidgets") } }
    var menuBarLabelStyle: MenuBarLabelStyle { didSet { defaults.set(menuBarLabelStyle.rawValue, forKey: "menuBarLabelStyle") } }
    var themeID: String { didSet { defaults.set(themeID, forKey: "themeID") } }
    var dashboardLayout: DashboardLayout { didSet { defaults.set(dashboardLayout.rawValue, forKey: "dashboardLayout") } }
    /// Editable copies of built-in themes, in the order they were made.
    var customThemes: [CustomTheme] { didSet { save(customThemes, forKey: "customThemes") } }
    var overviewResources: [OverviewResource] { didSet { save(overviewResources, forKey: "overviewResources") } }
    var resourcesInSidebar: Bool { didSet { defaults.set(resourcesInSidebar, forKey: "resourcesInSidebar") } }
    var agentCardFields: [AgentCardField] { didSet { save(agentCardFields, forKey: "agentCardFields") } }
    var defaultAgent: AgentTool { didSet { defaults.set(defaultAgent.rawValue, forKey: "defaultAgent") } }
    /// Customised arrangements keyed by `DashboardLayout` raw value; a missing key means the default.
    var customLayouts: [String: PageLayouts] { didSet { save(customLayouts, forKey: "customLayouts") } }
    /// Nil until the user picks an editor the first time they open a project.
    var editorBundleID: String? { didSet { defaults.set(editorBundleID, forKey: "editorBundleID") } }
    var alertsEnabled: Bool { didSet { defaults.set(alertsEnabled, forKey: "alertsEnabled") } }
    var alertsOnApproval: Bool { didSet { defaults.set(alertsOnApproval, forKey: "alertsOnApproval") } }
    var alertsOnYourTurn: Bool { didSet { defaults.set(alertsOnYourTurn, forKey: "alertsOnYourTurn") } }
    var alertsOnStuck: Bool { didSet { defaults.set(alertsOnStuck, forKey: "alertsOnStuck") } }
    var alertSound: Bool { didSet { defaults.set(alertSound, forKey: "alertSound") } }
    /// Raw values of the agent tools the user turned alerts off for.
    var mutedAlertTools: [String] { didSet { defaults.set(mutedAlertTools, forKey: "mutedAlertTools") } }
    var nextAgentHotkeyEnabled: Bool { didSet { defaults.set(nextAgentHotkeyEnabled, forKey: "nextAgentHotkeyEnabled") } }
    var nextAgentHotkey: HotkeyShortcut { didSet { save(nextAgentHotkey, forKey: "nextAgentHotkey") } }
    var quietHours: QuietHours { didSet { save(quietHours, forKey: "quietHours") } }
    var quietAlertHandling: QuietAlertHandling { didSet { defaults.set(quietAlertHandling.rawValue, forKey: "quietAlertHandling") } }
    /// Set from the menu bar bell; nil when alerts aren't paused.
    var alertsPausedUntil: Date? { didSet { defaults.set(alertsPausedUntil, forKey: "alertsPausedUntil") } }
    /// Days without a commit before a clean worktree counts as stale.
    var staleWorktreeDays: Int { didSet { defaults.set(staleWorktreeDays, forKey: "staleWorktreeDays") } }
    /// Folders of repositories seen through ports and agents, so their worktrees stay listed after those stop.
    var worktreeRepositoryFolders: [String] { didSet { defaults.set(worktreeRepositoryFolders, forKey: "worktreeRepositoryFolders") } }
    /// Off by default: most people are on subscriptions and do not pay per token.
    var spendTrackingEnabled: Bool { didSet { defaults.set(spendTrackingEnabled, forKey: "spendTrackingEnabled") } }
    /// Estimated US dollars per day; zero means no budget.
    var dailySpendBudget: Double { didSet { defaults.set(dailySpendBudget, forKey: "dailySpendBudget") } }
    /// Start of the day the budget alert last fired, so it fires once per day.
    var spendBudgetAlertedDay: Date? { didSet { defaults.set(spendBudgetAlertedDay, forKey: "spendBudgetAlertedDay") } }
    var nowPlayingEnabled: Bool { didSet { defaults.set(nowPlayingEnabled, forKey: "nowPlayingEnabled") } }
    /// Off by default: hearing the audio needs the system audio recording permission.
    var nowPlayingUsesSystemAudio: Bool { didSet { defaults.set(nowPlayingUsesSystemAudio, forKey: "nowPlayingUsesSystemAudio") } }
    var nowPlayingMode: NowPlayingMode { didSet { defaults.set(nowPlayingMode.rawValue, forKey: "nowPlayingMode") } }
    /// Nil follows the layout's own style.
    var visualizerStyle: VisualizerStyle? { didSet { defaults.set(visualizerStyle?.rawValue, forKey: "visualizerStyle") } }
    /// Nil follows the theme's colours.
    var visualizerPalette: VisualizerPalette? { didSet { defaults.set(visualizerPalette?.rawValue, forKey: "visualizerPalette") } }
    var collapsedSections: [CollapsibleSection] { didSet { save(collapsedSections, forKey: "collapsedSections") } }
    /// Treats any macOS Focus as quiet hours.
    var quietDuringFocus: Bool { didSet { defaults.set(quietDuringFocus, forKey: "quietDuringFocus") } }
    /// Off by default: holds a system sleep assertion while an agent works.
    var keepAwakeWhileAgentsWork: Bool { didSet { defaults.set(keepAwakeWhileAgentsWork, forKey: "keepAwakeWhileAgentsWork") } }
    /// Off by default: a notification the next day summing up the agents' day.
    var dailyRecapNotificationEnabled: Bool { didSet { defaults.set(dailyRecapNotificationEnabled, forKey: "dailyRecapNotificationEnabled") } }
    /// Start of the last day the recap notification summed up, so each day is summed up once.
    var dailyRecapAnnouncedDay: Date? { didSet { defaults.set(dailyRecapAnnouncedDay, forKey: "dailyRecapAnnouncedDay") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarMetrics = Self.load([MenuBarMetric].self, forKey: "menuBarMetrics", from: defaults) ?? [.cpu, .memory, .workingAgents, .agentsNeedingYou]
        panelShowsNetworkAndDisk = defaults.bool(forKey: "panelShowsNetworkAndDisk")
        showSystemPorts = defaults.bool(forKey: "showSystemPorts")
        showIdleAgents = defaults.bool(forKey: "showIdleAgents")
        claudeLimitsEnabled = defaults.bool(forKey: "claudeLimitsEnabled")
        notifiesSketchyBar = defaults.bool(forKey: "notifiesSketchyBar")
        customWidgets = Self.load([CustomWidget].self, forKey: "customWidgets", from: defaults) ?? []
        menuBarLabelStyle = defaults.string(forKey: "menuBarLabelStyle").flatMap(MenuBarLabelStyle.init(rawValue:)) ?? .text
        themeID = defaults.string(forKey: "themeID") ?? Theme.ignition.id
        dashboardLayout = defaults.string(forKey: "dashboardLayout").flatMap(DashboardLayout.init(rawValue:)) ?? .ignition
        customThemes = Self.load([CustomTheme].self, forKey: "customThemes", from: defaults) ?? []
        overviewResources = Self.load([OverviewResource].self, forKey: "overviewResources", from: defaults) ?? OverviewResource.defaultSelection
        resourcesInSidebar = defaults.bool(forKey: "resourcesInSidebar")
        agentCardFields = Self.load([AgentCardField].self, forKey: "agentCardFields", from: defaults) ?? AgentCardField.allCases
        defaultAgent = defaults.string(forKey: "defaultAgent").flatMap(AgentTool.init(rawValue:)) ?? .claude
        editorBundleID = defaults.string(forKey: "editorBundleID")
        customLayouts = Self.load([String: PageLayouts].self, forKey: "customLayouts", from: defaults) ?? [:]
        alertsEnabled = defaults.object(forKey: "alertsEnabled") as? Bool ?? true
        alertsOnApproval = defaults.object(forKey: "alertsOnApproval") as? Bool ?? true
        alertsOnYourTurn = defaults.object(forKey: "alertsOnYourTurn") as? Bool ?? true
        alertsOnStuck = defaults.object(forKey: "alertsOnStuck") as? Bool ?? true
        alertSound = defaults.object(forKey: "alertSound") as? Bool ?? true
        mutedAlertTools = defaults.stringArray(forKey: "mutedAlertTools") ?? []
        nextAgentHotkeyEnabled = defaults.object(forKey: "nextAgentHotkeyEnabled") as? Bool ?? true
        nextAgentHotkey = Self.load(HotkeyShortcut.self, forKey: "nextAgentHotkey", from: defaults) ?? .nextAgentDefault
        quietHours = Self.load(QuietHours.self, forKey: "quietHours", from: defaults) ?? QuietHours()
        quietAlertHandling = defaults.string(forKey: "quietAlertHandling").flatMap(QuietAlertHandling.init(rawValue:)) ?? .summarize
        alertsPausedUntil = defaults.object(forKey: "alertsPausedUntil") as? Date
        staleWorktreeDays = defaults.object(forKey: "staleWorktreeDays") as? Int ?? 14
        worktreeRepositoryFolders = defaults.stringArray(forKey: "worktreeRepositoryFolders") ?? []
        spendTrackingEnabled = defaults.bool(forKey: "spendTrackingEnabled")
        dailySpendBudget = defaults.double(forKey: "dailySpendBudget")
        spendBudgetAlertedDay = defaults.object(forKey: "spendBudgetAlertedDay") as? Date
        nowPlayingEnabled = defaults.object(forKey: "nowPlayingEnabled") as? Bool ?? true
        nowPlayingUsesSystemAudio = defaults.bool(forKey: "nowPlayingUsesSystemAudio")
        nowPlayingMode = defaults.string(forKey: "nowPlayingMode").flatMap(NowPlayingMode.init(rawValue:)) ?? .expanded
        visualizerStyle = defaults.string(forKey: "visualizerStyle").flatMap(VisualizerStyle.init(rawValue:))
        visualizerPalette = defaults.string(forKey: "visualizerPalette").flatMap(VisualizerPalette.init(rawValue:))
        collapsedSections = Self.load([CollapsibleSection].self, forKey: "collapsedSections", from: defaults) ?? []
        quietDuringFocus = defaults.bool(forKey: "quietDuringFocus")
        keepAwakeWhileAgentsWork = defaults.bool(forKey: "keepAwakeWhileAgentsWork")
        dailyRecapNotificationEnabled = defaults.bool(forKey: "dailyRecapNotificationEnabled")
        dailyRecapAnnouncedDay = defaults.object(forKey: "dailyRecapAnnouncedDay") as? Date
        migrateLegacyCustomColors()
    }

    /// 1.1 kept colour overrides on the built-in themes; those become custom themes now that built-ins are read-only.
    private func migrateLegacyCustomColors() {
        guard let legacy = Self.load([String: [String: String]].self, forKey: "customColors", from: defaults) else { return }
        let palettes = Dictionary(uniqueKeysWithValues: Theme.all.map { ($0.id, $0.palette) })
        for migrated in CustomTheme.migrating(legacyOverrides: legacy, palettes: palettes) {
            customThemes.append(migrated.theme)
            if themeID == migrated.replacesThemeID { themeID = migrated.theme.id }
        }
        defaults.removeObject(forKey: "customColors")
    }

    var alertStates: Set<AgentState> {
        Set([alertsOnApproval ? AgentState.needsApproval : nil, alertsOnYourTurn ? AgentState.yourTurn : nil, alertsOnStuck ? AgentState.possiblyStuck : nil].compactMap { $0 })
    }

    var alertTools: Set<AgentTool> {
        Set(AgentTool.allCases.filter { !mutedAlertTools.contains($0.rawValue) })
    }

    func isAlertPaused(at now: Date = Date()) -> Bool {
        AlertPause.isPaused(until: alertsPausedUntil, at: now)
    }

    /// Paused from the bell, inside the quiet hours schedule, or in a Focus when following it.
    func isQuietForAlerts(at now: Date = Date(), isFocused: Bool? = nil) -> Bool {
        quietReason(at: now, isFocused: isFocused) != nil
    }

    func quietReason(at now: Date = Date(), isFocused: Bool?) -> AlertQuietReason? {
        AlertQuietness.reason(isPaused: isAlertPaused(at: now), isInSchedule: quietHours.contains(now), followsFocus: quietDuringFocus, isFocused: isFocused)
    }

    func setAlerts(_ isEnabled: Bool, for tool: AgentTool) {
        mutedAlertTools = isEnabled ? mutedAlertTools.filter { $0 != tool.rawValue } : mutedAlertTools + [tool.rawValue]
    }

    /// Switching layout also switches to the theme it was designed with; any theme can be picked after.
    func selectLayout(_ layout: DashboardLayout) {
        dashboardLayout = layout
        themeID = layout.defaultThemeID
    }

    /// The selected theme, custom colours included.
    func currentTheme(systemScheme: ColorScheme) -> Theme {
        if let custom = customTheme(id: themeID) { return theme(for: custom) }
        return Theme.resolve(id: themeID, systemScheme: systemScheme)
    }

    func customTheme(id: String) -> CustomTheme? {
        customThemes.first { $0.id == id }
    }

    func theme(for custom: CustomTheme) -> Theme {
        Theme.resolve(id: custom.baseThemeID, systemScheme: .dark).customized(as: custom)
    }

    /// Duplicates a built-in or custom theme into a new custom theme and selects it.
    func copyToCustomTheme(_ theme: Theme) {
        let baseThemeID = customTheme(id: theme.id)?.baseThemeID ?? theme.id
        let copy = CustomTheme.copy(of: baseThemeID, palette: theme.palette, existingNames: customThemes.map(\.name))
        customThemes.append(copy)
        themeID = copy.id
    }

    func renameCustomTheme(id: String, to name: String) {
        updateCustomTheme(id: id) { $0.name = name }
    }

    /// Falls back to the theme it was copied from when the deleted one was selected.
    func deleteCustomTheme(id: String) {
        guard let custom = customTheme(id: id) else { return }
        customThemes.removeAll { $0.id == id }
        if themeID == id { themeID = custom.baseThemeID }
    }

    func setColor(_ color: Color, for role: ThemeColorRole, inCustomTheme id: String) {
        updateCustomTheme(id: id) { $0.colors[role.rawValue] = color.hexString }
    }

    /// Puts one role, or every role when nil, back to the colour of the theme it was copied from.
    func resetColors(_ role: ThemeColorRole? = nil, inCustomTheme id: String) {
        updateCustomTheme(id: id) { custom in
            let base = Theme.resolve(id: custom.baseThemeID, systemScheme: .dark).palette.colors
            for role in role.map({ [$0] }) ?? ThemeColorRole.allCases { custom.colors[role.rawValue] = base[role.rawValue] }
        }
    }

    private func updateCustomTheme(id: String, _ change: (inout CustomTheme) -> Void) {
        guard let index = customThemes.firstIndex(where: { $0.id == id }) else { return }
        change(&customThemes[index])
    }

    func isCollapsed(_ section: CollapsibleSection) -> Bool {
        collapsedSections.contains(section)
    }

    func toggleCollapsed(_ section: CollapsibleSection) {
        collapsedSections = CollapsibleSection.toggling(section, in: collapsedSections)
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

    /// The spend and now-playing sections exist only while they are turned on, so they never show up otherwise.
    var availableSections: [SectionKind] {
        SectionKind.builtIn.filter { isAvailable($0) } + customWidgets.map { .widget($0.id) }
    }

    private func isAvailable(_ kind: SectionKind) -> Bool {
        switch kind {
        case .spend: spendTrackingEnabled
        case .nowPlaying: nowPlayingEnabled
        default: true
        }
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
