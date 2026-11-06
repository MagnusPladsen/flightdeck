import MonitorCore
import SwiftUI

/// Go-to-terminal and stop, as icon buttons for agent rows and cards.
struct AgentControlButtons: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var agent: AgentSession
    /// The menu bar panel closes when a dialog opens, so it confirms in the row instead.
    var confirmsInline = false
    @State private var isConfirmingStop = false

    var body: some View {
        if confirmsInline && isConfirmingStop {
            inlineConfirmation
        } else {
            HStack(spacing: 2) {
                IconButton(systemImage: "terminal", help: "Go to this agent's terminal") { store.openTerminal(for: agent) }
                IconButton(systemImage: "stop.circle", help: "Stop this agent…") { isConfirmingStop = true }
            }
            .confirmingStop(of: agent, isPresented: confirmsInline ? .constant(false) : $isConfirmingStop)
        }
    }

    private var inlineConfirmation: some View {
        HStack(spacing: 6) {
            Button("Stop") {
                isConfirmingStop = false
                store.stopAgent(agent)
            }
            .foregroundStyle(theme.error)
            .help("Sends Ctrl-C; the agent's session ends")
            Button("Cancel") { isConfirmingStop = false }
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.semibold))
    }
}

extension View {
    /// Asks before interrupting the agent, since its current turn is lost.
    func confirmingStop(of agent: AgentSession, isPresented: Binding<Bool>) -> some View {
        modifier(StopAgentConfirmation(agent: agent, isPresented: isPresented))
    }
}

private struct StopAgentConfirmation: ViewModifier {
    @Environment(MonitorStore.self) private var store
    var agent: AgentSession
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.confirmationDialog("Stop \(agent.tool.displayName) in \(agent.displayName)?", isPresented: $isPresented) {
            Button("Stop Agent", role: .destructive) { store.stopAgent(agent) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Flightdeck sends it Ctrl-C (an interrupt). Whatever it is doing now is cancelled and the session ends.")
        }
    }
}
