import MonitorCore
import Observation

/// What the dashboard window shows: one of the layout pages, or the settings page.
enum DashboardDestination: Hashable {
    case page(DashboardPage)
    case settings
}

/// The dashboard's current destination, shared so the menu bar panel and app menu can jump to a page.
@MainActor
@Observable
final class DashboardNavigation {
    var destination: DashboardDestination = .page(.overview)

    func show(_ page: DashboardPage) {
        destination = .page(page)
    }

    func showSettings() {
        destination = .settings
    }
}
