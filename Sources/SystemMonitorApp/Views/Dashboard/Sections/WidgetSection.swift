import MonitorCore
import SwiftUI

/// One custom widget as a grid section; double-click or the context menu edits it.
struct WidgetSection: View {
    @Environment(MonitorStore.self) private var store
    var widgetID: UUID
    @State private var editingWidget: CustomWidget?

    var body: some View {
        if let widget = store.settings.customWidgets.first(where: { $0.id == widgetID }) {
            WidgetTile(widget: widget, result: store.widgetResults[widget.id])
                .onTapGesture(count: 2) { editingWidget = widget }
                .contextMenu {
                    Button("Edit…") { editingWidget = widget }
                    Button("Remove", role: .destructive) { store.settings.customWidgets.removeAll { $0.id == widget.id } }
                }
                .sheet(item: $editingWidget) { WidgetEditor.saving($0, to: store) }
        }
    }
}

extension WidgetEditor {
    /// Editor that stores the widget and runs it straight away.
    static func saving(_ widget: CustomWidget, to store: MonitorStore) -> WidgetEditor {
        WidgetEditor(widget: widget) { saved in
            store.settings.upsertWidget(saved)
            Task { await store.refreshDueWidgets(force: true) }
        }
    }
}
