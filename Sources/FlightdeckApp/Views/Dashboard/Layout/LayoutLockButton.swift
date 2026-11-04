import SwiftUI

/// Toolbar button that unlocks the window's sections for editing and saves them on lock.
struct LayoutLockButton: View {
    @Environment(MonitorStore.self) private var store
    @Environment(LayoutEditor.self) private var editor
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            if editor.isEditing {
                editor.lock(settings: store.settings, layout: theme.layout)
            } else {
                editor.unlock(settings: store.settings, layout: theme.layout)
            }
        } label: {
            Label(editor.isEditing ? "Done editing layout" : "Edit layout", systemImage: editor.isEditing ? "lock.open.fill" : "lock")
        }
        .help(editor.isEditing ? "Lock and save the layout" : "Unlock to move, resize and hide sections")
    }
}
