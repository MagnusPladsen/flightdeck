import MonitorCore
import SwiftUI

/// Search field with the default-agent picker, then the greeting. Return asks Claude about what the app shows.
struct OverviewHeader: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Binding var searchText: String
    @Environment(ClaudeAsker.self) private var asker

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.muted)
                TextField("Search, or press Return to ask Claude (⌘K)", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit(askClaude)
                if !searchText.isEmpty {
                    IconButton(systemImage: "xmark.circle.fill", help: "Clear search") { searchText = "" }
                        .foregroundStyle(theme.muted)
                }
                DefaultAgentMenu()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.border))
            HStack {
                Text(greeting)
                Spacer()
                KeepAwakePill()
                StatusDot(color: theme.success, size: 6)
                Text("Live")
            }
            .font(.system(size: 13))
            .foregroundStyle(theme.muted)
        }
    }

    /// The question moves into the answer palette, so it stops filtering the sections below.
    private func askClaude() {
        asker.ask(searchText, store: store)
        searchText = ""
    }

    private var greeting: String {
        let firstName = DemoData.isEnabled ? DemoData.userName : NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
        let hour = Calendar.current.component(.hour, from: Date())
        let partOfDay = switch hour {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
        return "\(partOfDay), \(firstName)"
    }
}

/// Picks the agent whose usage the overview shows. Claude Code and Codex are always offered;
/// other agents appear once they are running.
private struct DefaultAgentMenu: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    private static let recommended: [AgentTool] = [.claude, .codex]

    var body: some View {
        Menu {
            Section("Default agent") {
                ForEach(choices, id: \.self) { tool in
                    Button {
                        store.settings.defaultAgent = tool
                    } label: {
                        if tool == store.settings.defaultAgent {
                            Label(title(for: tool), systemImage: "checkmark")
                        } else {
                            Text(title(for: tool))
                        }
                    }
                }
            }
        } label: {
            Text(store.settings.defaultAgent.displayName)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(theme.muted)
    }

    private var choices: [AgentTool] {
        let running = Set(store.agents.map(\.tool))
        return AgentTool.allCases.filter { Self.recommended.contains($0) || running.contains($0) || $0 == store.settings.defaultAgent }
    }

    private func title(for tool: AgentTool) -> String {
        Self.recommended.contains(tool) ? "\(tool.displayName) (recommended)" : "\(tool.displayName) (running)"
    }
}
