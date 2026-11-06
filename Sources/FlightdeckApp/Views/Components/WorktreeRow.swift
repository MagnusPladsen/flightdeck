import AppKit
import MonitorCore
import SwiftUI

/// A worktree's branch, changes, upstream, pull request, agent and last commit on one line.
struct WorktreeRow: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var worktree: Worktree
    var agents: [AgentSession]
    var isStale: Bool

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(color: worktree.status.isDirty ? theme.warning : theme.success)
            VStack(alignment: .leading, spacing: 2) {
                title
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if let agent = agents.first { agentLabel(agent) }
            pullRequestBadge
            Text(syncText).font(.caption.monospacedDigit()).foregroundStyle(theme.muted).frame(width: 64, alignment: .trailing)
            changesText.frame(width: 76, alignment: .trailing)
            IconButton(systemImage: "terminal", help: "Open in terminal") { store.openInTerminal(worktree.path) }
            IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open in editor") { store.openInEditor(worktree.path) }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu { contextMenu }
    }

    private var title: some View {
        HStack(spacing: 6) {
            Text(worktree.branch ?? worktree.head.map { String($0.prefix(7)) } ?? "detached").fontWeight(.medium).lineLimit(1)
            if worktree.isMain { Chip(text: "main checkout", systemImage: "house").foregroundStyle(.secondary) }
            if worktree.isLocked { Chip(text: "locked", systemImage: "lock").foregroundStyle(.secondary) }
            if isStale { Chip(text: "stale", systemImage: "clock.badge.xmark").foregroundStyle(theme.warning) }
        }
    }

    private var subtitle: String {
        let folder = worktree.isMain ? (worktree.path as NSString).abbreviatingWithTildeInPath : worktree.folderName
        return "\(folder) · last commit \(Formatters.relative(worktree.lastCommitDate))"
    }

    private func agentLabel(_ agent: AgentSession) -> some View {
        Label(agents.count > 1 ? "\(agent.tool.displayName) +\(agents.count - 1)" : agent.tool.displayName, systemImage: agent.tool.symbolName)
            .font(.caption.weight(.medium))
            .foregroundStyle(agent.state.color(in: theme))
            .help("\(agent.tool.displayName) · \(agent.state.label)")
    }

    @ViewBuilder
    private var pullRequestBadge: some View {
        if let pullRequest = worktree.pullRequest.pullRequest {
            Button { openPullRequest(pullRequest) } label: {
                Text("#\(String(pullRequest.number)) \(pullRequest.state.title)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(pullRequest.state.color(in: theme))
                    .background(pullRequest.state.color(in: theme).opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Open pull request on GitHub")
        }
    }

    private var syncText: String {
        let status = worktree.status
        guard status.upstream != nil else { return worktree.isMain ? "" : "local only" }
        if status.ahead == 0 && status.behind == 0 { return "in sync" }
        return [status.ahead > 0 ? "↑\(status.ahead)" : nil, status.behind > 0 ? "↓\(status.behind)" : nil].compactMap { $0 }.joined(separator: " ")
    }

    private var changesText: some View {
        let count = worktree.status.changedFileCount
        return Text(count == 0 ? "clean" : "\(count) changed")
            .font(.caption.weight(count == 0 ? .regular : .semibold))
            .foregroundStyle(count == 0 ? theme.muted : theme.warning)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Reveal in Finder") { store.revealInFinder(worktree.path) }
        Button("Copy path") { copyPath() }
        if let pullRequest = worktree.pullRequest.pullRequest {
            Button("Open pull request #\(String(pullRequest.number))") { openPullRequest(pullRequest) }
        }
    }

    private func openPullRequest(_ pullRequest: PullRequestInfo) {
        guard let url = URL(string: pullRequest.url) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(worktree.path, forType: .string)
    }
}

extension PullRequestState {
    var title: String {
        switch self {
        case .open: "open"
        case .merged: "merged"
        case .closed: "closed"
        }
    }

    func color(in theme: Theme) -> Color {
        switch self {
        case .open: theme.success
        case .merged: theme.primary
        case .closed: theme.muted
        }
    }
}
