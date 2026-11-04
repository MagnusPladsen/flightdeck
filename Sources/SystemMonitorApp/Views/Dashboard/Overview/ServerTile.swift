import MonitorCore
import SwiftUI

/// A dev server as a card: framework colour stripe, project, branch, big port number.
struct ServerTile: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var port: ListeningPort

    @State private var isHovering = false
    @State private var isConfirmingStop = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(stripeColor.gradient).frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(port.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(":\(String(port.port))")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.primary)
                }
                HStack(spacing: 6) {
                    if let framework = port.framework { FrameworkBadge(framework: framework) }
                    subtitle
                }
                .opacity(0.9)
                Spacer(minLength: 0)
                actions.opacity(isHovering ? 1 : 0)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(isHovering ? theme.overlay.opacity(0.6) : theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border.opacity(0.6)))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .confirmationDialog("Stop \(port.processName) (pid \(String(port.pid)))?", isPresented: $isConfirmingStop) {
            Button("Stop process", role: .destructive) { store.stopProcess(port.pid) }
        }
    }

    private var stripeColor: Color {
        port.framework.map { FrameworkBadge(framework: $0).color } ?? theme.success
    }

    @ViewBuilder
    private var subtitle: some View {
        if let project = port.project {
            Label(project.isWorktree ? (project.worktreeName ?? "worktree") : (project.branch ?? "—"), systemImage: project.isWorktree ? "square.stack.3d.up" : "arrow.triangle.branch")
                .font(.system(size: 11))
                .lineLimit(1)
                .opacity(0.6)
        } else if port.containerName != nil {
            Label("container", systemImage: "shippingbox").font(.system(size: 11)).opacity(0.6)
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            IconButton(systemImage: "safari", help: "Open in browser") { store.openInBrowser(port: port.port) }
            if let path = port.project?.rootPath ?? port.workingDirectory {
                IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open in editor") { store.openInEditor(path) }
                IconButton(systemImage: "terminal", help: "Open in terminal") { store.openInTerminal(path) }
            }
            Spacer()
            IconButton(systemImage: "stop.circle", help: "Stop process") { isConfirmingStop = true }
        }
    }
}
