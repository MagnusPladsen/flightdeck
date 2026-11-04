import MonitorCore
import SwiftUI

/// Edit-mode footer: drop target for the end of the page and the hidden sections to add back.
struct AddSectionTray: View {
    @Environment(MonitorStore.self) private var store
    @Environment(LayoutEditor.self) private var editor
    @Environment(\.theme) private var theme
    var page: DashboardPage
    var hidden: [SectionKind]
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hidden.isEmpty ? "Drop here to move a section to the end" : "Add section")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.muted)
            if !hidden.isEmpty {
                FlowButtons(kinds: hidden, title: { $0.title(in: store.settings) }) { kind in
                    editor.update { $0.move(kind, to: page) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDropTarget ? theme.attention : theme.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
        .dropDestination(for: String.self) { tokens, _ in
            guard let kind = tokens.first.flatMap(SectionKind.init(token:)) else { return false }
            editor.update { $0.move(kind, to: page) }
            return true
        } isTargeted: { isDropTarget = $0 }
    }
}

private struct FlowButtons: View {
    var kinds: [SectionKind]
    var title: (SectionKind) -> String
    var add: (SectionKind) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(kinds, id: \.self) { kind in
                Button { add(kind) } label: { Label(title(kind), systemImage: "plus") }
                    .buttonStyle(PillButtonStyle(size: 12))
            }
        }
    }
}
