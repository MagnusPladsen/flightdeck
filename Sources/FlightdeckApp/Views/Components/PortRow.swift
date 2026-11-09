import MonitorCore
import SwiftUI

struct PortRow: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var port: ListeningPort
    var isCompact = false

    @State private var isHovering = false
    @State private var isConfirmingStop = false
    @State private var isConfirmingRestart = false

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: port.isDevServer ? theme.success : theme.foreground.opacity(0.4))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(port.title).fontWeight(.medium).lineLimit(1)
                    if let framework = port.framework { FrameworkBadge(framework: framework) }
                }
                details
            }
            Spacer(minLength: 4)
            if isHovering || !isCompact { actions }
            portChip
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .confirmationDialog("Stop \(port.processName) (pid \(String(port.pid)))?", isPresented: $isConfirmingStop) {
            Button("Stop process", role: .destructive) { store.stopProcess(port.pid) }
        }
        .confirmationDialog("Restart \(port.title) on :\(String(port.port))?", isPresented: $isConfirmingRestart) {
            Button("Restart in terminal") { store.restartServer(port) }
        } message: {
            Text("Stops the process, then runs \(ServerRelaunch.commandLine(port.arguments)) again in a new terminal tab.")
        }
    }

    @ViewBuilder
    private var details: some View {
        HStack(spacing: 4) {
            if let project = port.project {
                if let branch = project.branch { Chip(text: branch, systemImage: "arrow.triangle.branch") }
                if project.isWorktree { Chip(text: project.worktreeName ?? "worktree", systemImage: "square.stack.3d.up") }
            } else if port.containerName != nil {
                Chip(text: "container", systemImage: "shippingbox")
            } else {
                Text(port.processName).font(.caption).foregroundStyle(.secondary)
            }
            if !port.isLocalOnly && !isCompact {
                Chip(text: "exposed", systemImage: "network")
            }
            if let conflict = store.serverHealth.conflicts[port.id] {
                Chip(text: isCompact ? "conflict" : conflict.summary, systemImage: "exclamationmark.triangle").foregroundStyle(theme.warning).help(conflict.summary)
            }
        }
        .foregroundStyle(.secondary)
    }

    private var portChip: some View {
        Text(":\(String(port.port))")
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(theme.primary)
            .background(theme.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
    }

    private var actions: some View {
        HStack(spacing: 2) {
            IconButton(systemImage: "safari", help: "Open in browser") { store.openInBrowser(port: port.port) }
            if let path = port.project?.rootPath ?? port.workingDirectory {
                IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open in editor") { store.openInEditor(path) }
                if !isCompact {
                    IconButton(systemImage: "terminal", help: "Open in terminal") { store.openInTerminal(path) }
                    IconButton(systemImage: "folder", help: "Reveal in Finder") { store.revealInFinder(path) }
                }
            }
            if !isCompact, let id = port.serverIdentity, store.serverHealth.hasLog(for: id) { ServerLogButton(id: id) }
            if store.canRestart(port) {
                IconButton(systemImage: "arrow.clockwise.circle", help: "Restart in terminal") { isConfirmingRestart = true }
            }
            IconButton(systemImage: "stop.circle", help: "Stop process") { isConfirmingStop = true }
        }
    }
}

struct IconButton: View {
    var systemImage: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
