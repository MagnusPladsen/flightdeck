import MonitorCore
import SwiftUI

/// The `flightdeck` command and the status file it reads, for SketchyBar, tmux and Raycast.
struct CommandLineSettings: View {
    @Environment(MonitorStore.self) private var store
    @State private var isInstalling = false
    @State private var result: Result<CommandLineToolInstallation, CommandLineToolInstallError>?
    private let helperPath = CommandLineTool.helperPath
    private let hasSketchyBar = CommandRunner.locate("sketchybar") != nil

    var body: some View {
        @Bindable var settings = store.settings
        Section {
            Button("Install command-line tool") { install() }
                .disabled(helperPath == nil || isInstalling)
            if let result { InstallResultText(result: result) }
            Toggle("Notify SketchyBar when the status changes", isOn: $settings.notifiesSketchyBar)
                .disabled(!hasSketchyBar)
        } header: {
            Text("Command line")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        let path = (StatusFile.defaultURL.path as NSString).abbreviatingWithTildeInPath
        let missingHelper = helperPath == nil ? "The command is only bundled with Flightdeck.app. " : ""
        let sketchyBar = hasSketchyBar ? "SketchyBar gets the \(StatusPublisher.sketchyBarEvent) event." : "SketchyBar isn't installed."
        return "\(missingHelper)Run `flightdeck status` for a one-line summary, `--json` for everything or `--format '{needsYou}/{working}'`. It reads \(path), which Flightdeck keeps current. \(sketchyBar)"
    }

    private func install() {
        guard let helperPath else { return }
        isInstalling = true
        Task {
            result = await CommandLineTool.install(helper: helperPath)
            isInstalling = false
        }
    }
}

private struct InstallResultText: View {
    @Environment(\.theme) private var theme
    var result: Result<CommandLineToolInstallation, CommandLineToolInstallError>

    var body: some View {
        switch result {
        case .success(let installation):
            VStack(alignment: .leading, spacing: 4) {
                Text("Linked \((installation.linkPath as NSString).abbreviatingWithTildeInPath)").font(.caption)
                if let instruction = installation.pathInstruction {
                    Text("That folder isn't on your PATH yet. Add this to your shell profile:").font(.caption).foregroundStyle(theme.warning)
                    Text(instruction).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
            }
        case .failure(let error):
            Text(error.description).font(.caption).foregroundStyle(theme.error)
        }
    }
}
