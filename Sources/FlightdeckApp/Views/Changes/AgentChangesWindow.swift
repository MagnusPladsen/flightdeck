import AppKit
import MonitorCore
import SwiftUI

/// Every file an agent changed since it started, with the unified diff beside it.
struct AgentChangesWindow: View {
    static let windowID = "agent-changes"
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var pid: Int32
    @State private var lines: [DiffLine] = []
    @State private var isLoading = true
    @State private var selectedPath: String?

    private var agent: AgentSession? { store.agents.first { $0.pid == pid } }
    private var changes: AgentChanges? { store.agentChanges.changesByPID[pid] }

    var body: some View {
        Group {
            if let agent, let changes {
                content(agent: agent, changes: changes)
            } else {
                ContentUnavailableView("No changes to show", systemImage: "doc.text.magnifyingglass",
                                       description: Text("The agent has stopped, or its folder isn't a git repository."))
            }
        }
        .frame(minWidth: 760, minHeight: 460)
        .background(theme.background)
        .onAppear { NSApp.activate() }
        .task(id: changes) { await loadDiff() }
    }

    private func content(agent: AgentSession, changes: AgentChanges) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(agent: agent, changes: changes)
            Divider()
            HSplitView {
                ChangedFileList(changes: changes, selectedPath: $selectedPath)
                    .frame(minWidth: 220, idealWidth: 280, maxWidth: 420)
                DiffView(lines: lines, isLoading: isLoading, selectedPath: selectedPath)
                    .frame(minWidth: 420)
            }
        }
        .navigationTitle("Changes · \(agent.displayName)")
    }

    private func header(agent: AgentSession, changes: AgentChanges) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(agent.displayName).font(.system(size: 17, weight: .bold))
            ChangeSummaryText(summary: changes.summary, size: 13)
            Spacer()
            Text("since \(String(changes.baseline.commit.prefix(7)))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.muted)
                .help("The last commit before \(agent.tool.displayName) started")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadDiff() async {
        guard let agent else { return }
        isLoading = true
        lines = await store.agentChanges.diffLines(for: agent)
        isLoading = false
    }
}

private struct ChangedFileList: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var changes: AgentChanges
    @Binding var selectedPath: String?

    var body: some View {
        List(changes.files, selection: $selectedPath) { file in
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text((file.path as NSString).lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(file.path).font(.system(size: 10)).foregroundStyle(theme.muted).lineLimit(1).truncationMode(.head)
                }
                Spacer(minLength: 4)
                counts(file)
                IconButton(systemImage: "chevron.left.forwardslash.chevron.right", help: "Open in editor") {
                    store.openInEditor(changes.baseline.repositoryRoot + "/" + file.path)
                }
            }
            .tag(file.path)
        }
    }

    @ViewBuilder
    private func counts(_ file: FileChange) -> some View {
        if let added = file.added, let removed = file.removed {
            ChangeSummaryText(summary: ChangeSummary(fileCount: 1, added: added, removed: removed), size: 11, showsFiles: false)
        } else {
            Text("binary").font(.system(size: 11)).foregroundStyle(theme.muted)
        }
    }
}

private struct DiffView: View {
    @Environment(\.theme) private var theme
    var lines: [DiffLine]
    var isLoading: Bool
    var selectedPath: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(color(of: line.kind))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(background(of: line.kind))
                            .id(line.id)
                    }
                }
                .padding(10)
                .textSelection(.enabled)
            }
            .overlay { if isLoading && lines.isEmpty { ProgressView() } }
            .onChange(of: selectedPath) { _, path in
                if let id = path.flatMap(firstLineID(of:)) { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    private func firstLineID(of path: String) -> Int? {
        lines.first { $0.kind == .fileHeader && $0.text.hasPrefix("diff --git") && $0.text.hasSuffix(" b/" + path) }?.id
    }

    private func color(of kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added: theme.success
        case .removed: theme.error
        case .hunk: theme.info
        case .fileHeader: theme.muted
        case .context: theme.foreground
        }
    }

    private func background(of kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added: theme.success.opacity(0.1)
        case .removed: theme.error.opacity(0.1)
        default: .clear
        }
    }
}
