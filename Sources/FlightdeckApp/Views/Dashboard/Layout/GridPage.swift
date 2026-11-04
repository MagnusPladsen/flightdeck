import MonitorCore
import SwiftUI

/// A dashboard page that is just its sections on the grid.
struct GridPage: View {
    @Environment(\.theme) private var theme
    var page: DashboardPage
    var navigate: (DashboardPage) -> Void
    @State private var snoozedAgentIDs: Set<Int32> = []

    var body: some View {
        ScrollView {
            PageCanvas(page: page, context: SectionContext(navigate: navigate, snoozedAgentIDs: $snoozedAgentIDs))
                .padding(32)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
        }
        .background(theme.background)
    }
}

/// The widgets page: the grid plus adding new widgets.
struct WidgetsPage: View {
    @Environment(MonitorStore.self) private var store
    var navigate: (DashboardPage) -> Void
    @State private var newWidget: CustomWidget?

    var body: some View {
        GridPage(page: .widgets, navigate: navigate)
            .overlay {
                if store.settings.customWidgets.isEmpty {
                    ContentUnavailableView("No widgets yet", systemImage: "square.grid.2x2", description: Text("A widget runs a shell command on a timer and shows its output."))
                }
            }
            .toolbar {
                Button { newWidget = CustomWidget(title: "", command: "") } label: { Label("Add widget", systemImage: "plus") }
            }
            .sheet(item: $newWidget) { WidgetEditor.saving($0, to: store) }
    }
}
