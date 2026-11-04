import MonitorCore
import SwiftUI

/// The Ignition overview: search on top, the page's sections on the grid, resources optionally docked.
struct IgnitionOverview: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var navigate: (DashboardPage) -> Void

    @State private var searchText = ""
    @State private var snoozedAgentIDs: Set<Int32> = []
    @State private var asker = ClaudeAsker()

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    IgnitionHeader(searchText: $searchText, asker: asker)
                    PageCanvas(page: .overview, context: SectionContext(navigate: navigate, searchQuery: searchText, snoozedAgentIDs: $snoozedAgentIDs))
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
        .overlay {
            if asker.status != nil {
                AskPalette(asker: asker).transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: store.settings.resourcesInSidebar)
        .animation(.smooth(duration: 0.2), value: asker.status != nil)
    }
}
