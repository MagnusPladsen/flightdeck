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
    @Environment(\.dashboardLayout) private var layout
    var page: DashboardPage
    var context: SectionContext

    var body: some View {
        let layouts = editor.layouts(settings: store.settings, layout: layout)
        let placements = visiblePlacements(in: layouts)
        VStack(alignment: .leading, spacing: layout.style.rowSpacing) {
            SectionGrid(spans: placements.map(\.span), columnSpacing: layout.style.columnSpacing, rowSpacing: layout.style.rowSpacing) {
                ForEach(placements, id: \.kind) { placement in
                    section(placement)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .modifier(SectionChromeModifier(chrome: layout.style.chrome))
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

    /// Resources docked in the sidebar are drawn there instead of on the grid; an empty "Your turn"
    /// and now playing with nothing playing only show while editing, so they can still be moved.
    private func visiblePlacements(in layouts: PageLayouts) -> [SectionPlacement] {
        let isYourTurnEmpty = AgentBoardColumn.yourTurn.groups(from: store.agents(matching: context.searchQuery)).isEmpty
        return layouts.placements(on: page).filter { placement in
            if store.settings.resourcesInSidebar && placement.kind == .resources { return false }
            if placement.kind == .nowPlaying && !store.nowPlaying.isVisible && !editor.isEditing { return false }
            return !(placement.kind == .yourTurn && isYourTurnEmpty && !editor.isEditing)
        }
    }
}
