import MonitorCore
import UserNotifications

/// Dev server crash alerts. They carry no folder, so clicking one opens the dashboard where the stopped server is listed.
extension AgentNotifier {
    func postServerCrashes(_ crashes: [CrashedServer], playsSound: Bool) {
        guard isAvailable, let first = crashes.first else { return }
        let content = UNMutableNotificationContent()
        if crashes.count == 1 {
            content.title = "\(first.server.title) stopped"
            content.body = [":\(first.id.port)", first.server.framework?.displayName, first.server.project?.branch].compactMap { $0 }.joined(separator: " · ")
        } else {
            content.title = "\(crashes.count) dev servers stopped"
            content.body = crashes.map { "\($0.server.title) :\($0.id.port)" }.joined(separator: ", ")
        }
        content.sound = playsSound ? .default : nil
        content.interruptionLevel = .active
        let identifier = "server-crash:\(first.id.folder):\(first.id.port)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
}
