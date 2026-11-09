import MonitorCore
import UserNotifications

/// "CI failing" notifications; clicking one opens the terminal of the agent working on the branch.
extension AgentNotifier {
    func postCIFailure(_ alert: CIFailureAlert, playsSound: Bool) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "CI failing on \(alert.branch)"
        content.subtitle = "\(alert.worktree.repositoryName) · pull request #\(alert.pullRequest.number)"
        content.body = "\(alert.agent.tool.displayName) is working in this worktree."
        content.threadIdentifier = alert.worktree.path
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [Self.folderKey: alert.agent.workingDirectory, Self.pidKey: Int(alert.agent.pid)]
        content.sound = playsSound ? .default : nil
        content.interruptionLevel = .active
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ci:\(alert.worktree.path)", content: content, trigger: nil))
    }

    /// One alert for the failures held through quiet hours or a pause; a single one gets its usual alert.
    func postCIFailureSummary(of alerts: [CIFailureAlert], playsSound: Bool) {
        guard isAvailable, let first = alerts.first else { return }
        guard alerts.count > 1 else { return postCIFailure(first, playsSound: playsSound) }
        let content = UNMutableNotificationContent()
        content.title = "CI failing on \(alerts.count) branches"
        content.body = alerts.map { "\($0.worktree.repositoryName)/\($0.branch)" }.joined(separator: ", ")
        content.sound = playsSound ? .default : nil
        content.interruptionLevel = .active
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ci-summary", content: content, trigger: nil))
    }
}
