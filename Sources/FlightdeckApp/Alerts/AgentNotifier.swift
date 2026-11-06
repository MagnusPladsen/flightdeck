import AppKit
import MonitorCore
import Observation
import UserNotifications

/// Posts a macOS notification when an agent starts waiting on you, and withdraws it once it moves on.
@MainActor
@Observable
final class AgentNotifier: NSObject {
    nonisolated private static let categoryID = "agent"
    nonisolated private static let openTerminalActionID = "openTerminal"
    nonisolated private static let showDashboardActionID = "showDashboard"
    nonisolated private static let folderKey = "folder"

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @ObservationIgnored var openTerminal: (String) -> Void = { _ in }

    /// Notifications need a bundled app; `swift run` has no bundle identifier and would crash.
    let isAvailable = Bundle.main.bundleIdentifier != nil

    override init() {
        super.init()
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [
                UNNotificationAction(identifier: Self.openTerminalActionID, title: "Open Terminal", options: [.foreground]),
                UNNotificationAction(identifier: Self.showDashboardActionID, title: "Show in Flightdeck", options: [.foreground]),
            ],
            intentIdentifiers: []
        )])
        Task { await refreshAuthorization() }
    }

    func requestAuthorization() async {
        guard isAvailable else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorization()
    }

    func refreshAuthorization() async {
        guard isAvailable else { return }
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func post(about agent: AgentSession, playsSound: Bool) {
        guard isAvailable else { return }
        let request = UNNotificationRequest(identifier: Self.identifier(for: agent.workingDirectory), content: content(for: agent, playsSound: playsSound), trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func postBudgetAlert(estimatedCost: Double, budget: Double, playsSound: Bool) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Daily token budget passed"
        content.body = "About \(Formatters.dollars(estimatedCost)) of API-equivalent usage today, over your \(Formatters.dollars(budget)) budget. This is an estimate, not a bill."
        content.sound = playsSound ? .default : nil
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "spend-budget", content: content, trigger: nil))
    }

    func withdraw(folders: Set<String>) {
        guard isAvailable, !folders.isEmpty else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: folders.map(Self.identifier(for:)))
    }

    func sendTest(playsSound: Bool) async {
        await requestAuthorization()
        let sample = AgentSession(tool: .claude, pid: 0, workingDirectory: NSHomeDirectory(), project: nil, state: .needsApproval, cpuPercent: 0, lastActivity: Date(), lastAction: AgentAction(verb: "Running", detail: "swift test"))
        post(about: sample, playsSound: playsSound)
    }

    private func content(for agent: AgentSession, playsSound: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = agent.state == .needsApproval ? "\(agent.displayName) needs your approval" : "\(agent.displayName) needs you"
        content.subtitle = [agent.tool.displayName, agent.checkoutLabel].compactMap { $0 }.joined(separator: " · ")
        let action = agent.actionLine
        content.body = [action.verb, action.detail].filter { !$0.isEmpty }.joined(separator: " ")
        content.threadIdentifier = agent.workingDirectory
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [Self.folderKey: agent.workingDirectory]
        content.sound = playsSound ? .default : nil
        content.interruptionLevel = .active
        return content
    }

    private static func identifier(for folder: String) -> String {
        "agent:\(folder)"
    }
}

extension AgentNotifier: UNUserNotificationCenterDelegate {
    /// Flightdeck is usually in the background, but show the banner even when it isn't.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Clicking the notification opens the agent's terminal; "Show in Flightdeck" opens the dashboard.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let folder = response.notification.request.content.userInfo[Self.folderKey] as? String
        let actionID = response.actionIdentifier
        await MainActor.run {
            if actionID == Self.showDashboardActionID || folder == nil {
                DashboardOpener.open()
            } else if let folder {
                openTerminal(folder)
            }
        }
    }
}
