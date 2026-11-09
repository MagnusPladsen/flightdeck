import AppKit
import SwiftUI

/// Rows in the quiet hours section for keeping alerts quiet during any macOS Focus.
struct FocusQuietSettings: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        Toggle("Keep alerts quiet during a macOS Focus", isOn: Binding(get: { store.settings.quietDuringFocus }, set: { store.setQuietDuringFocus($0) }))
        if store.settings.quietDuringFocus { accessRow }
    }

    @ViewBuilder
    private var accessRow: some View {
        switch store.focusStatus.access {
        case .unavailable:
            Text("Following Focus works only from the bundled Flightdeck.app.").foregroundStyle(.secondary)
        case .notDetermined:
            Button("Allow Flightdeck to See Your Focus…") { store.setQuietDuringFocus(true) }
        case .denied:
            LabeledContent {
                Button("Open Focus Settings…", action: openFocusSettings)
            } label: {
                Text("macOS doesn't let Flightdeck see your Focus, so only the schedule applies.").foregroundStyle(theme.error)
            }
        case .authorized:
            Text(store.focusStatus.isFocused == true ? "A Focus is on, so alerts are quiet." : "No Focus is on.").foregroundStyle(.secondary)
        }
    }

    private func openFocusSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
