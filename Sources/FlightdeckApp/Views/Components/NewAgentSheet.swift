import MonitorCore
import SwiftUI

/// Picks a repository, an existing or new worktree, an agent and a first prompt, then opens a terminal running it.
struct NewAgentSheet: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NewAgentDraft
    @State private var isLaunching = false
    @State private var launchError: AgentLaunchError?

    init(request: NewAgentRequest, repositoryRoots: [String], defaultAgent: AgentTool) {
        _draft = State(initialValue: NewAgentDraft(request: request, repositoryRoots: repositoryRoots, defaultAgent: defaultAgent))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New agent").font(.title3.weight(.bold)).padding([.top, .horizontal], 20)
            Form {
                NewAgentWhereFields(draft: $draft, worktrees: worktrees, repositoryRoots: store.worktreeOverview.repositoryRoots, plan: plan)
                Section {
                    Picker("Agent", selection: $draft.tool) {
                        ForEach(AgentLaunchCommand.launchableTools, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    TextField("First prompt", text: $draft.prompt, prompt: Text("Optional"), axis: .vertical).lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            footer.padding([.bottom, .horizontal], 20)
        }
        .frame(width: 500)
    }

    private var worktrees: [Worktree] { store.worktreeOverview.worktrees }

    private var plan: Result<AgentLaunchPlan, AgentLaunchError> {
        draft.plan(worktrees: worktrees, location: store.settings.newWorktreeLocation)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(launchError?.message ?? "Opens in \(store.settings.launchTerminal.title.lowercased()).")
                .font(.caption).foregroundStyle(launchError == nil ? theme.muted : theme.error).lineLimit(3)
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button(isLaunching ? "Starting…" : "Start") { start() }
                .keyboardShortcut(.defaultAction)
                .disabled(isLaunching || (try? plan.get()) == nil)
        }
    }

    private func start() {
        guard let plan = try? plan.get() else { return }
        isLaunching = true
        Task {
            launchError = await store.launchAgent(plan)
            isLaunching = false
            if launchError == nil { dismiss() }
        }
    }
}

/// Presents `NewAgentSheet` for a request, carrying the store and theme into the sheet.
private struct NewAgentSheetPresenter: ViewModifier {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Binding var request: NewAgentRequest?

    func body(content: Content) -> some View {
        content.sheet(item: $request) { request in
            NewAgentSheet(request: request, repositoryRoots: store.worktreeOverview.repositoryRoots, defaultAgent: store.settings.defaultAgent)
                .environment(store)
                .environment(\.theme, theme)
        }
    }
}

extension View {
    func newAgentSheet(_ request: Binding<NewAgentRequest?>) -> some View {
        modifier(NewAgentSheetPresenter(request: request))
    }
}

/// The repository and worktree pickers, and the branch for a new worktree with where it will go.
private struct NewAgentWhereFields: View {
    @Environment(\.theme) private var theme
    @Binding var draft: NewAgentDraft
    var worktrees: [Worktree]
    var repositoryRoots: [String]
    var plan: Result<AgentLaunchPlan, AgentLaunchError>

    var body: some View {
        Section {
            Picker("Repository", selection: $draft.repositoryRoot) {
                ForEach(repositoryRoots, id: \.self) { Text(($0 as NSString).lastPathComponent).tag($0) }
            }
            .onChange(of: draft.repositoryRoot) { draft.folder = nil }
            Picker("Run in", selection: $draft.folder) {
                Text("New worktree…").tag(String?.none)
                ForEach(worktrees.filter { $0.repositoryRoot == draft.repositoryRoot }) { Text(label(for: $0)).tag(Optional($0.path)) }
            }
            if draft.isNewWorktree {
                TextField("Branch", text: $draft.branch, prompt: Text("feat/my-change"))
            }
        } footer: {
            Text(hint).font(.caption).foregroundStyle(isProblem ? theme.error : theme.muted)
        }
    }

    private func label(for worktree: Worktree) -> String {
        let name = worktree.branch ?? worktree.folderName
        return worktree.isMain ? "\(name) (main checkout)" : name
    }

    private var isProblem: Bool {
        draft.isNewWorktree && !draft.branch.isEmpty && (try? plan.get()) == nil
    }

    private var hint: String {
        switch plan {
        case .failure(let error): draft.branch.isEmpty && draft.isNewWorktree ? "Type a branch; an existing one is checked out, a new one starts from the main checkout." : error.message
        case .success(let plan): "Runs in \((plan.folder as NSString).abbreviatingWithTildeInPath)" + (draft.isNewWorktree ? ", a new worktree." : ".")
        }
    }
}
