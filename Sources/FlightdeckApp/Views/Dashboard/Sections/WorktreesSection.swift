import MonitorCore
import SwiftUI

/// Every worktree of the repositories Flightdeck knows, grouped by repository, with a clean-up for stale ones.
struct WorktreesSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var pendingCleanup: [Worktree] = []
    @State private var newAgentRequest: NewAgentRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Worktrees", count: overview.worktrees.count) {
                staleAfterStepper
                cleanUpButton
                Button { newAgentRequest = NewAgentRequest() } label: { Label("New agent", systemImage: "play.circle") }
                    .disabled(overview.repositoryRoots.isEmpty)
            }
            if let summary = overview.cleanupSummary {
                Text(summary).font(.caption).foregroundStyle(theme.muted).padding(.bottom, 6)
            }
            if overview.worktrees.isEmpty {
                HairlineRows(items: overview.worktrees, emptyText: emptyText) { _ in EmptyView() }
            }
            ForEach(overview.repositoryRoots, id: \.self) { root in
                WorktreeRepositoryGroup(worktrees: overview.worktrees.filter { $0.repositoryRoot == root }, agents: agents, stalePaths: stalePaths,
                                        cacheUsage: overview.cacheUsage) { newAgentRequest = $0 }
            }
        }
        .newAgentSheet($newAgentRequest)
        .confirmationDialog(cleanupTitle, isPresented: isConfirmingCleanup) {
            Button("Remove \(pendingCleanup.count) worktree\(pendingCleanup.count == 1 ? "" : "s")", role: .destructive) { cleanUp() }
        } message: {
            Text(cleanupMessage)
        }
    }

    private var overview: WorktreeOverview { store.worktreeOverview }
    private var agents: [String: [AgentSession]] { overview.agentsByWorktree(store.agents) }
    private var stalePaths: Set<String> { Set(store.staleWorktrees.map(\.path)) }

    private var emptyText: String {
        overview.hasLoaded ? "No repositories yet. They appear once a dev server or agent runs in one." : "Looking for worktrees…"
    }

    private var staleAfterStepper: some View {
        @Bindable var settings = store.settings
        return Stepper("Stale after \(settings.staleWorktreeDays) days", value: $settings.staleWorktreeDays, in: 1...365)
            .font(.system(size: 13))
            .help("Clean, merged or never opened as a pull request, and no commit for this many days")
    }

    private var cleanUpButton: some View {
        Button {
            pendingCleanup = store.staleWorktrees
        } label: {
            Label(overview.isCleaningUp ? "Cleaning up…" : "Clean up \(store.staleWorktrees.count)\(freedText(store.staleWorktrees))", systemImage: "trash")
        }
        .disabled(store.staleWorktrees.isEmpty || overview.isCleaningUp)
        .help("Remove the worktrees marked stale. Their branches are kept.")
    }

    /// " · 3.2 GB" when the worktrees hold build caches.
    private func freedText(_ worktrees: [Worktree]) -> String {
        let bytes = overview.cacheBytes(of: worktrees)
        return bytes == 0 ? "" : " · \(Formatters.bytes(bytes))"
    }

    private var isConfirmingCleanup: Binding<Bool> {
        Binding(get: { !pendingCleanup.isEmpty }, set: { if !$0 { pendingCleanup = [] } })
    }

    private var cleanupTitle: String {
        "Remove \(pendingCleanup.count) stale worktree\(pendingCleanup.count == 1 ? "" : "s")?"
    }

    private var cleanupMessage: String {
        let names = pendingCleanup.prefix(8).map { "\($0.repositoryName)/\($0.folderName)" }
        let more = pendingCleanup.count > names.count ? "\nand \(pendingCleanup.count - names.count) more" : ""
        let bytes = overview.cacheBytes(of: pendingCleanup)
        let freed = bytes == 0 ? "" : "\n\nFrees \(Formatters.bytes(bytes)) of build caches (node_modules, .build and the like)."
        return names.joined(separator: "\n") + more + freed + "\n\nRuns git worktree remove. Branches and commits are kept; worktrees with changes are skipped."
    }

    private func cleanUp() {
        let targets = pendingCleanup
        pendingCleanup = []
        Task { await store.cleanUpWorktrees(targets) }
    }
}

/// One repository's worktrees under its name.
private struct WorktreeRepositoryGroup: View {
    @Environment(\.theme) private var theme
    var worktrees: [Worktree]
    var agents: [String: [AgentSession]]
    var stalePaths: Set<String>
    var cacheUsage: [String: BuildCacheUsage]
    var onNewAgent: (NewAgentRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(theme.muted)
                Text(worktrees.first?.repositoryName ?? "").font(.system(size: 13, weight: .bold))
                Text("\(worktrees.count)").font(.system(size: 13)).foregroundStyle(theme.muted)
                IconButton(systemImage: "plus.circle", help: "Start an agent in a new worktree") {
                    onNewAgent(NewAgentRequest(repositoryRoot: worktrees.first?.repositoryRoot))
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 6)
            HairlineRows(items: worktrees, emptyText: "") { worktree in
                WorktreeRow(worktree: worktree, agents: agents[worktree.path] ?? [], isStale: stalePaths.contains(worktree.path),
                            cacheUsage: cacheUsage[worktree.path]) {
                    onNewAgent(NewAgentRequest(repositoryRoot: worktree.repositoryRoot, folder: worktree.path))
                }
            }
        }
    }
}
