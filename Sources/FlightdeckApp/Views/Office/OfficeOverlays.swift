import MonitorCore
import SwiftUI

/// A post-style card for an agent that needs you, with a button that walks you over.
struct NeedsYouPost: View {
    @Environment(\.theme) private var theme
    var agent: AgentSession
    var walk: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OfficeAvatar(agent: agent).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(agent.tool.displayName).font(.callout.weight(.bold))
                    Text("@\(agent.displayName) · \(agent.ageText())").font(.callout).foregroundStyle(theme.muted).lineLimit(1)
                }
                Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button(action: walk) { Label("Walk there", systemImage: "figure.walk") }
                    Spacer(minLength: 0)
                    Text(agent.state.label).foregroundStyle(agent.state.color(in: theme))
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border) }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    private var message: String {
        let action = agent.actionLine
        if agent.state == .possiblyStuck { return "Might be stuck: \(agent.stuckReason?.summary ?? action.detail)" }
        return action.detail.isEmpty ? "Waiting for your approval" : "Waiting for your approval: \(action.detail)"
    }
}

/// The agent's pixel face in a circle.
struct OfficeAvatar: View {
    var agent: AgentSession

    var body: some View {
        OfficeCharacters.face.image(palette: OfficeCharacters.palette(tool: agent.tool, pid: agent.pid))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(hex: 0xE9E3D6))
            .clipShape(Circle())
    }
}

/// Details and controls for the agent the player is next to.
struct OfficeAgentCard: View {
    @Environment(\.theme) private var theme
    var agent: AgentSession
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                OfficeAvatar(agent: agent).frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(agent.tool.displayName).font(.callout.weight(.bold))
                    Text([agent.displayName, agent.checkoutLabel].compactMap { $0 }.joined(separator: "  ")).font(.caption).foregroundStyle(theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                IconButton(systemImage: "xmark", help: "Close (Esc)", action: close)
            }
            Text(agent.state.label).font(.caption.weight(.semibold)).foregroundStyle(agent.state.color(in: theme))
            Text(actionText).font(.callout).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            if let resources = agent.resourceText { Text(resources).font(.caption.monospacedDigit()).foregroundStyle(theme.muted) }
            HStack {
                Text("Space opens the terminal").font(.caption2).foregroundStyle(theme.muted)
                Spacer()
                AgentControlButtons(agent: agent)
            }
        }
        .padding(12)
        .frame(width: 270, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border) }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private var actionText: String {
        let action = agent.actionLine
        return action.detail.isEmpty ? action.verb : "\(action.verb) \(action.detail)"
    }
}

/// A one-line explanation of whatever the pointer is over.
struct OfficeTooltip: View {
    @Environment(\.theme) private var theme
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(theme.overlay, in: RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(theme.border) }
            .fixedSize()
    }
}
