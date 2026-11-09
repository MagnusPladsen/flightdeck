import MonitorCore
import SwiftUI

/// The big headline: the one agent that needs you most, or a calm "All clear".
struct NeedsYouHero: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession?
    /// Other folders with agents waiting on you, for "X and 2 others need you."
    var othersCount = 0
    var snooze: (AgentSession) -> Void
    @State private var isConfirmingStop = false

    var body: some View {
        if let agent {
            waiting(agent)
        } else {
            allClear
        }
    }

    private func waiting(_ agent: AgentSession) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            (Text(agent.displayName + othersSuffix + " ") + Text(othersCount == 0 ? "needs you." : "need you.").foregroundStyle(theme.attention))
                .font(.system(size: 60, weight: .heavy))
                .tracking(-2.4)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                actionText(agent.actionLine)
                    .lineLimit(1)
                Text(meta(for: agent))
                    .font(.system(size: 14))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            AgentWaitingMessage(agent: agent, size: 17)
            AgentChangesPeek(agent: agent, size: 14)
            HStack(spacing: 12) {
                Button("Go to terminal") { store.openTerminal(for: agent) }
                    .buttonStyle(PillButtonStyle(isProminent: true, size: 15))
                Button("Later") { snooze(agent) }
                    .buttonStyle(PillButtonStyle(size: 15))
                Button("Stop") { isConfirmingStop = true }
                    .buttonStyle(PillButtonStyle(size: 15))
                    .help("Stop this agent")
            }
        }
        .confirmingStop(of: agent, isPresented: $isConfirmingStop)
    }

    private var othersSuffix: String {
        switch othersCount {
        case 0: ""
        case 1: " and 1 other"
        default: " and \(othersCount) others"
        }
    }

    private var allClear: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All clear.")
                .font(.system(size: 60, weight: .heavy))
                .tracking(-2.4)
            Text(summary).font(.system(size: 15)).foregroundStyle(theme.muted)
        }
    }

    /// Commands read best in monospace; messages in the normal font.
    private func actionText(_ action: AgentAction) -> some View {
        let detail = Text(action.detail.isEmpty ? "" : " " + action.detail)
            .font(.system(size: 15, design: action.verb == "Running" ? .monospaced : .default))
        return (Text(action.verb).font(.system(size: 15, weight: .bold)).foregroundStyle(theme.attention) + detail)
    }

    private func meta(for agent: AgentSession) -> String {
        var parts = [agent.tool.displayName, agent.abbreviatedPath]
        if let checkout = agent.checkoutLabel { parts.append(checkout) }
        let age = agent.ageText()
        parts.append(age == "now" ? "waiting since just now" : "waiting \(age)")
        return parts.joined(separator: " · ")
    }

    private var summary: String {
        let working = store.agents.filter { $0.state == .working }.count
        let servers = store.devServers.count
        return "\(working) agent\(working == 1 ? "" : "s") working · \(servers) dev server\(servers == 1 ? "" : "s") up"
    }
}
