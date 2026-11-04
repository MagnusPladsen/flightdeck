import MonitorCore
import SwiftUI

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
