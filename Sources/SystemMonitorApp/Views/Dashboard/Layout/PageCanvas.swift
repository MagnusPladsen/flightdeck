import MonitorCore
import SwiftUI

/// What sections need from the page they sit on.
struct SectionContext {
    var navigate: (DashboardPage) -> Void
    var searchQuery = ""
    var snoozedAgentIDs: Binding<Set<Int32>> = .constant([])
}

/// The sections of one page, arranged on the grid from the current layout.
struct PageCanvas: View {
    @Environment(MonitorStore.self) private var store
    @Environment(LayoutEditor.self) private var editor
    @Environment(\.theme) private var theme
    var page: DashboardPage
    var context: SectionContext

    var body: some View {
        let placements = visiblePlacements
        SectionGrid(spans: placements.map(\.span)) {
            ForEach(placements, id: \.kind) { placement in
                SectionHost(kind: placement.kind, context: context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    /// Resources docked in the sidebar are drawn there instead of on the grid.
    private var visiblePlacements: [SectionPlacement] {
        editor.layouts(settings: store.settings, layout: theme.layout)
            .placements(on: page)
            .filter { !(store.settings.resourcesInSidebar && $0.kind == .resources) }
    }
}
