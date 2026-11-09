import MonitorCore

/// Watches worktree refreshes for pull requests whose CI just started failing under an agent,
/// with the same alert switch, muted agents and quiet handling as agent alerts.
@MainActor
final class CIFailureAlerter {
    private var previous: [Worktree]?
    private var batcher = CIFailureBatcher()

    func check(_ worktrees: [Worktree], agents: [String: [AgentSession]], settings: AppSettings, isQuiet: Bool, notifier: AgentNotifier) {
        defer { previous = worktrees }
        guard settings.alertsEnabled, settings.alertsOnFailingChecks else { return batcher.discard() }
        let alerts = CIFailureAlerts.newlyFailing(previous: previous, current: worktrees, agents: agents)
            .filter { settings.alertTools.contains($0.agent.tool) }
        let delivery = batcher.deliver(alerts, current: worktrees, isQuiet: isQuiet, handling: settings.quietAlertHandling)
        for alert in delivery.individual {
            notifier.postCIFailure(alert, playsSound: settings.alertSound)
        }
        notifier.postCIFailureSummary(of: delivery.summary, playsSound: settings.alertSound)
    }
}
