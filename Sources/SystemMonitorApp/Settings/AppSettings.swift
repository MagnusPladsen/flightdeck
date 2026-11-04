import Foundation
import MonitorCore
import Observation

enum MenuBarMetric: String, CaseIterable, Codable, Identifiable {
    case cpu, memory, network, servers, agents, claudeLimit, codexLimit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
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
    var showSystemPorts: Bool { didSet { defaults.set(showSystemPorts, forKey: "showSystemPorts") } }
    var showIdleAgents: Bool { didSet { defaults.set(showIdleAgents, forKey: "showIdleAgents") } }
    var claudeLimitsEnabled: Bool { didSet { defaults.set(claudeLimitsEnabled, forKey: "claudeLimitsEnabled") } }
    var customWidgets: [CustomWidget] { didSet { save(customWidgets, forKey: "customWidgets") } }
    var menuBarLabelStyle: MenuBarLabelStyle { didSet { defaults.set(menuBarLabelStyle.rawValue, forKey: "menuBarLabelStyle") } }
    var themeID: String { didSet { defaults.set(themeID, forKey: "themeID") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarMetrics = Self.load([MenuBarMetric].self, forKey: "menuBarMetrics", from: defaults) ?? [.cpu, .memory, .servers]
        showSystemPorts = defaults.bool(forKey: "showSystemPorts")
        showIdleAgents = defaults.bool(forKey: "showIdleAgents")
        claudeLimitsEnabled = defaults.bool(forKey: "claudeLimitsEnabled")
        customWidgets = Self.load([CustomWidget].self, forKey: "customWidgets", from: defaults) ?? []
        menuBarLabelStyle = defaults.string(forKey: "menuBarLabelStyle").flatMap(MenuBarLabelStyle.init(rawValue:)) ?? .icons
        themeID = defaults.string(forKey: "themeID") ?? Theme.cleanDark.id
    }

    func isShowingInMenuBar(_ metric: MenuBarMetric) -> Bool {
        menuBarMetrics.contains(metric)
    }

    func setMenuBarMetric(_ metric: MenuBarMetric, shown: Bool) {
        if shown, !menuBarMetrics.contains(metric) {
            menuBarMetrics = MenuBarMetric.allCases.filter { $0 == metric || menuBarMetrics.contains($0) }
        } else if !shown {
            menuBarMetrics.removeAll { $0 == metric }
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
