import Foundation
import MonitorCore
import UserNotifications

extension AgentNotifier {
    /// One notification for the achievements that unlocked at the same poll.
    func postAchievements(_ achievements: [Achievement]) {
        guard isAvailable, let first = achievements.first else { return }
        let content = UNMutableNotificationContent()
        content.title = achievements.count == 1 ? "Achievement unlocked: \(first.title)" : "\(achievements.count) achievements unlocked"
        content.body = achievements.count == 1 ? first.detail : achievements.map(\.title).joined(separator: ", ")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "achievement-\(first.id)", content: content, trigger: nil))
    }
}
