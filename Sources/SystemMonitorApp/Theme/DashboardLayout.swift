/// How the overview is arranged. Each theme picks a layout as well as its colours.
enum DashboardLayout: String, CaseIterable, Identifiable {
    /// Needs-you headline, a resource strip, the agent board and projects by git checkout.
    case ignition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ignition: "Ignition"
        }
    }
}
