import MonitorCore
import SwiftUI

struct WidgetsSection: View {
    @Environment(MonitorStore.self) private var store
    @State private var editingWidget: CustomWidget?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(store.settings.customWidgets) { widget in
                    WidgetTile(widget: widget, result: store.widgetResults[widget.id])
                        .onTapGesture(count: 2) { editingWidget = widget }
                        .contextMenu {
                            Button("Edit…") { editingWidget = widget }
                            Button("Remove", role: .destructive) { store.settings.customWidgets.removeAll { $0.id == widget.id } }
                        }
                }
            }
            .padding(20)
            if store.settings.customWidgets.isEmpty {
                ContentUnavailableView("No widgets yet", systemImage: "square.grid.2x2", description: Text("A widget runs a shell command on a timer and shows its output."))
            }
        }
        .themedScrollBackground()
        .toolbar {
            Button { editingWidget = CustomWidget(title: "", command: "") } label: { Label("Add widget", systemImage: "plus") }
        }
        .sheet(item: $editingWidget) { widget in
            WidgetEditor(widget: widget) { saved in
                store.settings.upsertWidget(saved)
                Task { await store.refreshDueWidgets(force: true) }
            }
        }
    }
}

struct WidgetTile: View {
    @Environment(\.theme) private var theme
    var widget: CustomWidget
    var result: CustomWidgetResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(widget.title).font(.caption).foregroundStyle(.secondary)
            Text(displayValue)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(3)
                .textSelection(.enabled)
            Text(result.map { "Updated \(Formatters.relative($0.updatedAt))" } ?? "Waiting for first run")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border.opacity(0.6)))
    }

    private var displayValue: String {
        guard let output = result?.output, !output.isEmpty else { return "—" }
        return output
    }

    private var valueColor: Color {
        guard let result else { return theme.foreground }
        if result.isError { return theme.error }
        if let limit = widget.warnAbove, let value = result.numericValue, value > limit { return theme.warning }
        return theme.foreground
    }
}

struct WidgetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var widget: CustomWidget
    var onSave: (CustomWidget) -> Void

    var body: some View {
        Form {
            TextField("Title", text: $widget.title)
            TextField("Shell command", text: $widget.command, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2...6)
            Stepper("Every \(Int(widget.intervalSeconds))s", value: $widget.intervalSeconds, in: 5...3600, step: 5)
            TextField("Warn above", value: $widget.warnAbove, format: .number, prompt: Text("Optional number"))
            if widget.command.isEmpty {
                Menu("Start from an example") {
                    ForEach(CustomWidget.examples, id: \.title) { example in
                        Button(example.title) {
                            widget.title = example.title
                            widget.command = example.command
                            widget.intervalSeconds = example.intervalSeconds
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .themedScrollBackground()
        .frame(width: 440)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(widget)
                    dismiss()
                }
                .disabled(widget.title.isEmpty || widget.command.isEmpty)
            }
        }
    }
}
