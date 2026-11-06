import AppKit
import MonitorCore
import SwiftUI

/// Settings for the global shortcut that jumps to the next agent waiting on the user.
struct NextAgentHotkeySection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var settings = store.settings
        Section {
            Toggle("Jump to the next agent that needs you", isOn: $settings.nextAgentHotkeyEnabled)
                .onChange(of: settings.nextAgentHotkeyEnabled) { store.applyNextAgentHotkey() }
            LabeledContent("Shortcut") {
                HStack(spacing: 8) {
                    ShortcutRecorder(shortcut: settings.nextAgentHotkey) { recorded in
                        settings.nextAgentHotkey = recorded
                        store.applyNextAgentHotkey()
                    }
                    Button("Reset") {
                        settings.nextAgentHotkey = .nextAgentDefault
                        store.applyNextAgentHotkey()
                    }
                    .disabled(settings.nextAgentHotkey == .nextAgentDefault)
                }
            }
            .disabled(!settings.nextAgentHotkeyEnabled)
            if store.isNextAgentHotkeyTaken && settings.nextAgentHotkeyEnabled {
                Text("Another app already uses \(settings.nextAgentHotkey.displayString). Pick a different shortcut.")
                    .font(.caption).foregroundStyle(theme.error)
            }
        } header: {
            Text("Keyboard")
        } footer: {
            Text("Works from any app. Each press focuses the terminal of the next agent in Needs you, longest-waiting first.")
        }
    }
}

/// Click, then press a key combination with ⌃, ⌥ or ⌘. Esc cancels.
private struct ShortcutRecorder: View {
    @Environment(MonitorStore.self) private var store
    var shortcut: HotkeyShortcut
    var onRecord: (HotkeyShortcut) -> Void
    @State private var monitor: Any?

    private var isRecording: Bool { monitor != nil }

    var body: some View {
        Button(isRecording ? "Type shortcut…" : shortcut.displayString) {
            isRecording ? stopRecording() : startRecording()
        }
        .monospaced()
        .frame(minWidth: 110)
        .help("Click, then press the new shortcut")
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        store.suspendNextAgentHotkey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            guard let recorded = HotkeyShortcut(event: event), recorded.isUsable else { return nil }
            onRecord(recorded)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        store.applyNextAgentHotkey()
    }
}
