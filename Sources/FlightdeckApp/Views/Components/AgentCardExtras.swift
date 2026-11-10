import MonitorCore
import SwiftUI

extension AgentSession {
    /// What the agent said last or is asking for, while it waits on you and the action line doesn't already say it.
    var waitingMessage: String? {
        guard state.needsYou, let lastMessage, !lastMessage.isEmpty else { return nil }
        let detail = actionLine.detail
        if lastMessage == detail { return nil }
        if state != .needsApproval, !detail.isEmpty, lastMessage.hasSuffix(detail) { return nil }
        return lastMessage
    }
}

/// The agent's last message or pending request, quoted under its action line. Hidden when there is none.
struct AgentWaitingMessage: View {
    @Environment(\.theme) private var theme
    var agent: AgentSession
    var size: CGFloat = 13

    var body: some View {
        if let message = agent.waitingMessage {
            Text(message)
                .font(.system(size: size))
                .foregroundStyle(theme.foreground.opacity(0.85))
                .lineLimit(2)
                .truncationMode(.tail)
                .padding(.leading, 8)
                .overlay(alignment: .leading) { Rectangle().fill(agent.state.color(in: theme).opacity(0.6)).frame(width: 2) }
                .help(message)
        }
    }
}

/// "4 files · +120 −18" and a Diff button, for agents that changed something since they started.
struct AgentChangesPeek: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.openWindow) private var openWindow
    var agent: AgentSession
    var size: CGFloat = 12

    var body: some View {
        if let summary = store.agentChanges.summary(for: agent) {
            HStack(spacing: 8) {
                ChangeSummaryText(summary: summary, size: size)
                Button("Diff") { openWindow(id: AgentChangesWindow.windowID, value: agent.pid) }
                    .buttonStyle(.borderless)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .help("Show what this agent changed since it started")
            }
        }
    }
}

struct ChangeSummaryText: View {
    @Environment(\.theme) private var theme
    var summary: ChangeSummary
    var size: CGFloat = 12
    var showsFiles = true

    var body: some View {
        (Text(showsFiles ? summary.filesText + " · " : "").foregroundStyle(theme.muted)
            + Text("+\(summary.added)").foregroundStyle(theme.success)
            + Text(" −\(summary.removed)").foregroundStyle(theme.error))
            .font(.system(size: size).monospacedDigit())
            .lineLimit(1)
    }
}

/// A "Show changes…" menu item for agents that changed something since they started.
struct ShowChangesButton: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    var agent: AgentSession

    var body: some View {
        if let summary = store.agentChanges.summary(for: agent) {
            Button("Show Changes (\(summary.text))…") { openWindow(id: AgentChangesWindow.windowID, value: agent.pid) }
        }
    }
}

extension AgentSession {
    /// The task-list step the agent is on, while it isn't idle.
    var currentPlanStep: (number: Int, step: AgentPlan.Step, total: Int)? {
        guard state != .idle, let plan, let current = plan.current else { return nil }
        return (current.number, current.step, plan.steps.count)
    }
}

/// "Step 3 of 6 · Run the tests" with a bar of one segment per step, from the agent's task list.
struct AgentPlanProgress: View {
    private static let maxSegments = 12
    @Environment(\.theme) private var theme
    var agent: AgentSession
    var size: CGFloat = 12

    var body: some View {
        if let current = agent.currentPlanStep, let plan = agent.plan {
            HStack(spacing: 8) {
                segments(plan, current: current.number)
                (Text("Step \(current.number) of \(current.total)").fontWeight(.semibold).foregroundStyle(theme.foreground.opacity(0.85))
                    + Text(" · " + current.step.title).foregroundStyle(theme.muted))
                    .font(.system(size: size))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .help(Self.checklist(plan))
        }
    }

    @ViewBuilder
    private func segments(_ plan: AgentPlan, current: Int) -> some View {
        let color = agent.state.color(in: theme)
        if plan.steps.count <= Self.maxSegments {
            HStack(spacing: 2) {
                ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                    Capsule()
                        .fill(step.status == .completed ? color : (index + 1 == current ? color.opacity(0.5) : theme.border))
                        .frame(width: 7, height: 4)
                }
            }
        } else {
            ProgressView(value: Double(plan.completedCount), total: Double(plan.steps.count))
                .progressViewStyle(.linear)
                .tint(color)
                .frame(width: 60)
        }
    }

    private static func checklist(_ plan: AgentPlan) -> String {
        plan.steps.map { step in
            switch step.status {
            case .completed: "✓ " + step.title
            case .inProgress: "→ " + step.title
            case .pending: "· " + step.title
            }
        }
        .joined(separator: "\n")
    }
}
