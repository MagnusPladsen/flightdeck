import MonitorCore
import SwiftUI

extension DashboardPage: Identifiable {
    public var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .ports: "Servers & Ports"
        case .agents: "AI Agents"
        case .worktrees: "Worktrees"
        case .processes: "Processes"
        case .widgets: "Widgets"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .ports: "network"
        case .agents: "sparkles"
        case .worktrees: "arrow.triangle.branch"
        case .processes: "cpu"
        case .widgets: "square.grid.2x2"
        }
    }
}

struct DashboardView: View {
    static let windowID = "dashboard"

    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout
    @Environment(DashboardNavigation.self) private var navigation
    @State private var layoutEditor = LayoutEditor()
    @Environment(ClaudeAsker.self) private var asker
    @Environment(WhatsNew.self) private var whatsNew
    @Environment(CommandPaletteState.self) private var palette
    @State private var newAgentRequest: NewAgentRequest?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth, max: layout.style.navigation == .rail ? sidebarWidth : 320)
        } detail: {
            detail(for: navigation.destination)
                .navigationTitle(title(for: navigation.destination))
                .toolbar {
                    if case .page = navigation.destination { LayoutLockButton() }
                    if navigation.destination != .office {
                        Button { navigation.showOffice() } label: { Label("Visualize", systemImage: "gamecontroller") }
                            .help("Show your agents in the office")
                    }
                    Button { Task { await store.refreshAll() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                }
        }
        .overlay {
            if palette.isPresented {
                CommandPalette(state: palette, source: paletteSource).transition(.opacity)
            } else if asker.isPresented {
                AskPalette(asker: asker).transition(.opacity)
            } else if whatsNew.isPresented {
                WhatsNewCard(whatsNew: whatsNew).transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) { AchievementToast().padding(20) }
        .animation(.smooth(duration: 0.2), value: palette.isPresented)
        .animation(.smooth(duration: 0.2), value: asker.isPresented)
        .animation(.smooth(duration: 0.2), value: whatsNew.isPresented)
        .toolbarBackground(theme.background, for: .windowToolbar)
        .fontDesign(layout.style.fontDesign)
        .environment(layoutEditor)
        .environment(store.beatAccent)
        .background { BeatAccentDriver() }
        .newAgentSheet($newAgentRequest)
    }

    private var paletteSource: PaletteCommandSource {
        PaletteCommandSource(store: store, navigation: navigation, asker: asker) { newAgentRequest = NewAgentRequest() }
    }

    /// The page list in the style of the chosen layout.
    @ViewBuilder
    private var sidebar: some View {
        @Bindable var navigation = navigation
        switch layout.style.navigation {
        case .list: PageListSidebar(selection: $navigation.destination, count: badgeCount)
        case .rail: RailSidebar(selection: $navigation.destination, count: badgeCount)
        }
    }

    private var sidebarWidth: CGFloat {
        layout.style.navigation == .rail ? 76 : 250
    }

    @ViewBuilder
    private func detail(for destination: DashboardDestination) -> some View {
        switch destination {
        case .page(.overview): LayoutOverview(navigate: navigation.show)
        case .page(.widgets): WidgetsPage(navigate: navigation.show)
        case .page(let page): GridPage(page: page, navigate: navigation.show)
        case .office: OfficePage()
        case .achievements: AchievementsPage()
        case .settings: SettingsView()
        }
    }

    private func title(for destination: DashboardDestination) -> String {
        switch destination {
        case .page(let page): page.title
        case .office: "Office"
        case .achievements: "Achievements"
        case .settings: "Settings"
        }
    }

    private func badgeCount(for section: DashboardPage) -> Int {
        switch section {
        case .ports: store.devServers.count
        case .agents: store.activeAgents.count
        case .worktrees: store.staleWorktrees.count
        default: 0
        }
    }
}
