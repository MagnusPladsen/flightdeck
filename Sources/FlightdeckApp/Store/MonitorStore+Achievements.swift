import Foundation
import MonitorCore

extension MonitorStore {
    /// Sends unlocks to Notification Center while achievement alerts are on and alerts aren't quiet.
    func connectAchievementAlerts() {
        achievements.onUnlock = { [weak self] unlocked in
            guard let self, settings.alertsEnabled, settings.achievementAlertsEnabled, !isQuietForAlerts else { return }
            notifier.postAchievements(unlocked)
        }
    }

    func recordAchievements() {
        let observation = AchievementObservation(
            agents: agents, devServerCount: devServers.count, cpuLoad: snapshot?.cpu.total, memoryPressure: snapshot?.memory.pressure,
            highestLimitPercent: usage.flatMap(\.windows).map(\.usedPercent).max(), tokensToday: usage.compactMap(\.tokensToday?.total).max())
        achievements.observe(observation, track: nowPlaying.isVisible ? nowPlaying.track : nil)
        if settings.officeWeatherEnabled { officeWeather.refresh(city: settings.officeWeatherCity) }
    }
}
