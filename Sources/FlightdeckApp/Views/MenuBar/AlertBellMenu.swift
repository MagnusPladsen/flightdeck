import MonitorCore
import SwiftUI

/// The menu bar panel's bell: turns alerts on and off, and pauses them for a while.
struct AlertBellMenu: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Button(settings.alertsEnabled ? "Turn Alerts Off" : "Turn Alerts On") { store.setAlertsEnabled(!settings.alertsEnabled) }
            if settings.alertsEnabled { pauseItems }
        } label: {
            Image(systemName: symbolName).frame(width: 18, height: 18)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(helpText)
        .accessibilityLabel("Alerts")
        .tint(settings.alertsEnabled ? theme.foreground : theme.muted)
    }

    @ViewBuilder
    private var pauseItems: some View {
        Divider()
        if let pausedUntil = settings.alertsPausedUntil, settings.isAlertPaused() {
            Text("Paused \(AlertPauseText.until(pausedUntil))")
            Button("Resume Alerts") { store.resumeAlerts() }
        }
        Button("Pause for 1 Hour") { store.pauseAlerts(until: AlertPause.forOneHour(from: Date())) }
        Button("Pause Until Tomorrow, \(Self.tomorrowMorning)") { store.pauseAlerts(until: AlertPause.untilTomorrow(from: Date())) }
    }

    private static var tomorrowMorning: String {
        AlertPause.untilTomorrow(from: Date()).formatted(date: .omitted, time: .shortened)
    }

    private var settings: AppSettings { store.settings }

    private var symbolName: String {
        if !settings.alertsEnabled { return "bell.slash" }
        return store.alertQuietReason == nil ? "bell.fill" : "moon.fill"
    }

    private var helpText: String {
        if !settings.alertsEnabled { return "Alerts off" }
        switch store.alertQuietReason {
        case .paused: return settings.alertsPausedUntil.map { "Alerts paused \(AlertPauseText.until($0))" } ?? "Alerts paused"
        case .schedule: return "Quiet hours"
        case .focus: return "Quiet during Focus"
        case nil: return "Alerts on"
        }
    }
}
