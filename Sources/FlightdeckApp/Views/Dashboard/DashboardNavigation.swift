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
    var destination: DashboardDestination = DashboardNavigation.demoStart ?? .page(.overview)

    /// `FLIGHTDECK_PAGE=agents` (or `office`) with `FLIGHTDECK_DEMO=1` opens the dashboard there, for screenshots.
    private static var demoStart: DashboardDestination? {
        guard DemoData.isEnabled, let name = ProcessInfo.processInfo.environment["FLIGHTDECK_PAGE"] else { return nil }
        if name == "office" { return .office }
        return DashboardPage(rawValue: name).map(DashboardDestination.page)
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
