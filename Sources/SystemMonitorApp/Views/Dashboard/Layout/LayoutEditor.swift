import MonitorCore
import Observation

/// Edit mode for the dashboard window. While unlocked, changes go to a draft that is saved on lock.
@MainActor
@Observable
final class LayoutEditor {
    private(set) var isEditing = false
    private var draft: PageLayouts?

    func layouts(settings: AppSettings, layout: DashboardLayout) -> PageLayouts {
        draft ?? settings.pageLayouts(for: layout)
    }

    func unlock(settings: AppSettings, layout: DashboardLayout) {
        draft = settings.pageLayouts(for: layout)
        isEditing = true
    }

    /// Saves the draft as the layout's custom version, or drops it when nothing differs from the original.
    func lock(settings: AppSettings, layout: DashboardLayout) {
        if let draft {
            let original = layout.defaultPages.sanitized(available: settings.availableSections)
            if draft == original {
                settings.resetLayout(layout)
            } else if draft != settings.pageLayouts(for: layout) {
                settings.saveCustomLayout(draft, for: layout)
            }
        }
        draft = nil
        isEditing = false
    }

    func update(_ change: (inout PageLayouts) -> Void) {
        guard var current = draft else { return }
        change(&current)
        draft = current
    }
}
