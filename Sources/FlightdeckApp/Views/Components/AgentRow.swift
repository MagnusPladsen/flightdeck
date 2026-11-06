import MonitorCore
import SwiftUI

struct AgentRow: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession
    var isCompact = false

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(color: agent.state.color(in: theme), isPulsing: agent.state == .working || agent.state == .needsApproval)
            Image(systemName: agent.tool.symbolName)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(agent.project?.name ?? folderName).fontWeight(.medium).lineLimit(1)
                    if let project = agent.project, project.isWorktree {
                        Chip(text: project.worktreeName ?? "worktree", systemImage: "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Text(agent.state.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(agent.state.color(in: theme))
                .help(agent.stuckReason?.summary ?? "")
            AgentControlButtons(agent: agent, confirmsInline: isCompact)
            if !isCompact {
                IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open folder in editor") { store.openInEditor(agent.workingDirectory) }
            }
        }
        .padding(.vertical, 3)
    }

    private var folderName: String {
        URL(fileURLWithPath: agent.workingDirectory).lastPathComponent
    }

    private var subtitle: String {
        var parts = [agent.tool.displayName]
        if let branch = agent.project?.branch { parts.append(branch) }
        if !isCompact { parts.append(abbreviatedPath) }
        if let activity = agent.lastActivity { parts.append(Formatters.relative(activity)) }
        return parts.joined(separator: " · ")
    }

    private var abbreviatedPath: String {
        (agent.workingDirectory as NSString).abbreviatingWithTildeInPath
    }
}
