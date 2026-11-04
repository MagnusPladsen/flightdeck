import MonitorCore
import SwiftUI

/// Shows the overview in the layout of the current theme.
struct OverviewSection: View {
    @Environment(\.theme) private var theme
    var navigate: (DashboardPage) -> Void

    var body: some View {
        switch theme.layout {
        case .ignition: IgnitionOverview(navigate: navigate)
        }
    }
}
