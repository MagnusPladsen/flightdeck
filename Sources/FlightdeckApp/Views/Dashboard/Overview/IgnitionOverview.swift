import MonitorCore
import SwiftUI

/// The Ignition overview: search on top, the page's sections on the grid, resources optionally docked.
struct IgnitionOverview: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var navigate: (DashboardPage) -> Void

    @State private var searchText = ""
    @State private var snoozedAgentIDs: Set<Int32> = []

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    IgnitionHeader(searchText: $searchText)
                    if isSearchEmpty {
                        noMatches
                    } else {
                        PageCanvas(page: .overview, context: SectionContext(navigate: navigate, searchQuery: searchText, snoozedAgentIDs: $snoozedAgentIDs))
                    }
                }
                .padding(32)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            if store.settings.resourcesInSidebar {
                ResourceSidebar(navigate: navigate)
                    .frame(width: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(theme.background)
        .animation(.smooth(duration: 0.3), value: store.settings.resourcesInSidebar)
    }

    /// Typed text that matches no agent or project: likely a question for Claude.
    private var isSearchEmpty: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            && store.agents(matching: searchText).isEmpty
            && store.projects(matching: searchText).isEmpty
    }

    private var noMatches: some View {
        (Text("Nothing matches “\(searchText)”. ") + Text("Press Return to ask Claude.").foregroundStyle(theme.accent))
            .font(.system(size: 15))
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
