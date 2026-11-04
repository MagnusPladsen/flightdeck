import SwiftUI

/// "Open in editor ▾" until the user picks one; then "Open in Zed" with a menu to change it.
struct EditorButton: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var path: String

    var body: some View {
        Group {
            if let editor = store.preferredEditor {
                Menu { choices } label: { Text("Open in \(editor.name)") } primaryAction: { store.open(path, in: editor) }
            } else {
                Menu { choices } label: { Text("Open in editor") }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(theme.foreground)
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .overlay(Capsule().strokeBorder(theme.border))
    }

    @ViewBuilder
    private var choices: some View {
        if store.installedEditors.isEmpty {
            Button("Reveal in Finder") { store.revealInFinder(path) }
        } else {
            Section("Open projects in") {
                ForEach(store.installedEditors) { editor in
                    Button {
                        store.settings.editorBundleID = editor.bundleID
                        store.open(path, in: editor)
                    } label: {
                        if editor == store.preferredEditor {
                            Label(editor.name, systemImage: "checkmark")
                        } else {
                            Text(editor.name)
                        }
                    }
                }
            }
            Text("Saved as your default editor")
        }
    }
}
