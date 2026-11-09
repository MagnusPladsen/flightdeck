import MonitorCore
import SwiftUI

/// Where "New agent" opens its terminal and puts new worktrees.
struct AgentLaunchSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        Section {
            Picker("Open in", selection: $settings.launchTerminal) {
                ForEach(LaunchTerminalChoice.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("New worktrees go", selection: $settings.newWorktreeLocation) {
                ForEach(WorktreeLocation.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } header: {
            Text("New agent")
        } footer: {
            Text("Ghostty, iTerm2 and Terminal open a new tab or window; tmux opens a new window in the session you used last. The first launch asks for permission to control the terminal.")
        }
    }
}
