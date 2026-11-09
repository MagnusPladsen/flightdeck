import Foundation
import MonitorCore
import Observation

/// What the dashboard window shows: one of the layout pages, the office, or the settings page.
enum DashboardDestination: Hashable {
    case page(DashboardPage)
    case office
    case settings
}

/// The dashboard's current destination, shared so the menu bar panel and app menu can jump to a page.
@MainActor
@Observable
final class DashboardNavigation {
    var destination: DashboardDestination = DashboardNavigation.demoStartPage.map(DashboardDestination.page) ?? .page(.overview)

    /// `FLIGHTDECK_PAGE=agents` with `FLIGHTDECK_DEMO=1` opens the dashboard on that page, for screenshots.
    private static var demoStartPage: DashboardPage? {
        guard DemoData.isEnabled else { return nil }
        return ProcessInfo.processInfo.environment["FLIGHTDECK_PAGE"].flatMap(DashboardPage.init(rawValue:))
    }

    func show(_ page: DashboardPage) {
        destination = .page(page)
    }

    func showOffice() {
        destination = .office
    }

    func showSettings() {
        destination = .settings
    }
}
