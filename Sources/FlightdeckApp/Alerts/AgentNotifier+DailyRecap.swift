import Foundation
import MonitorCore
import UserNotifications

extension AgentNotifier {
    /// The optional next-day summary of what the agents did.
    func postDailyRecap(_ recap: DailyRecap, estimatedCost: Double?) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(recap.day.formatted(.dateTime.weekday(.wide))) with your agents"
        content.body = Self.recapBody(recap, estimatedCost: estimatedCost)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "daily-recap", content: content, trigger: nil))
    }

    private static func recapBody(_ recap: DailyRecap, estimatedCost: Double?) -> String {
        let projects = recap.projects.count == 1 ? "1 project" : "\(recap.projects.count) projects"
        let busiest = recap.projects.first.map { ", most on \($0.project)" } ?? ""
        let work = "\(Formatters.duration(recap.workingSeconds)) of agent work across \(projects)\(busiest)."
        let waits = "Waited on you \(Formatters.duration(recap.waitingSeconds)), longest \(Formatters.duration(recap.longestWaitSeconds))."
        let turns = "\(recap.turns) turns in \(recap.sessions) sessions."
        let spend = estimatedCost.map { " About \(Formatters.dollars($0)) API-equivalent." } ?? ""
        return [work, waits, turns].joined(separator: " ") + spend
    }
}
