import MonitorCore
import SwiftUI

/// Claude's answer in a command palette over the dashboard, with a field for follow-ups and the
/// agents the answer names, each one click from its terminal.
struct AskPalette: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var asker: ClaudeAsker
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool
    private static let agentLimit = 5

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55)
                .contentShape(Rectangle())
                .onTapGesture { asker.dismiss() }
            card
                .frame(maxWidth: 640)
                .padding(.horizontal, 24)
                .padding(.top, 96)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            field
            if asker.status != nil {
                Rectangle().fill(theme.border).frame(height: 1)
                conversation
            }
            footer
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(theme.border))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
    }

    private var conversation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(asker.question).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.muted)
                answer
                mentionedAgents
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var field: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle").foregroundStyle(theme.accent).font(.system(size: 15, weight: .bold))
            TextField(asker.status == nil ? "Ask Claude about your agents, ports and usage" : "Ask a follow-up", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused($isFieldFocused)
                .onSubmit(askFollowUp)
                .onExitCommand { asker.dismiss() }
            Text("esc").font(.system(size: 11)).foregroundStyle(theme.muted)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(theme.border))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .onAppear { isFieldFocused = true }
    }

    @ViewBuilder
    private var answer: some View {
        switch asker.status {
        case .asking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking Claude…").foregroundStyle(theme.muted)
            }
            .font(.system(size: 14))
        case .answered(let text):
            Text(Self.markdown(text))
                .font(.system(size: 14))
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(let message):
            Text(message).font(.system(size: 14)).foregroundStyle(theme.error)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var mentionedAgents: some View {
        let agents = agentsNamedInAnswer
        if !agents.isEmpty {
            VStack(spacing: 2) {
                ForEach(agents) { agent in
                    Button { store.openInTerminal(agent.workingDirectory) } label: { agentRow(agent) }
                        .buttonStyle(.plain)
                        .help("Open \(agent.displayName) in the terminal")
                }
            }
        }
    }

    private func agentRow(_ agent: AgentSession) -> some View {
        HStack(spacing: 10) {
            StatusDot(color: agent.state.color(in: theme), size: 7)
            Text(agent.displayName).font(.system(size: 13, weight: .bold))
            Text(agent.actionLine.detail.isEmpty ? agent.state.label : agent.actionLine.detail)
                .font(.system(size: 13)).foregroundStyle(theme.muted).lineLimit(1)
            Spacer()
            Text(agent.ageText()).font(.system(size: 12)).foregroundStyle(theme.muted)
            Image(systemName: "terminal").font(.system(size: 11)).foregroundStyle(theme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }

    private var footer: some View {
        Text(asker.status == nil ? "Return asks · esc closes" : "Return asks a follow-up · click an agent to open its terminal")
            .font(.system(size: 11))
            .foregroundStyle(theme.muted)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
    }

    /// One agent per folder, for the agents whose name the answer mentions.
    private var agentsNamedInAnswer: [AgentSession] {
        guard case .answered(let text) = asker.status else { return [] }
        var seenFolders = Set<String>()
        return store.agents.filter { agent in
            text.localizedCaseInsensitiveContains(agent.displayName) && seenFolders.insert(agent.workingDirectory).inserted
        }
        .prefix(Self.agentLimit)
        .map { $0 }
    }

    private func askFollowUp() {
        asker.ask(draft, store: store, continuing: asker.status != nil)
        draft = ""
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
