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
        let layouts = editor.layouts(settings: store.settings, layout: theme.layout)
        let placements = visiblePlacements(in: layouts)
        VStack(alignment: .leading, spacing: 36) {
            SectionGrid(spans: placements.map(\.span)) {
                ForEach(placements, id: \.kind) { placement in
                    section(placement)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            if editor.isEditing {
                AddSectionTray(page: page, hidden: layouts.hidden)
            }
        }
        .animation(.smooth(duration: 0.25), value: placements)
    }

    @ViewBuilder
    private func section(_ placement: SectionPlacement) -> some View {
        if editor.isEditing {
            EditableSection(placement: placement, page: page) { SectionHost(kind: placement.kind, context: context) }
        } else {
            SectionHost(kind: placement.kind, context: context)
        }
    }

    /// Resources docked in the sidebar are drawn there instead of on the grid.
    private func visiblePlacements(in layouts: PageLayouts) -> [SectionPlacement] {
        layouts.placements(on: page).filter { !(store.settings.resourcesInSidebar && $0.kind == .resources) }
    }
}
