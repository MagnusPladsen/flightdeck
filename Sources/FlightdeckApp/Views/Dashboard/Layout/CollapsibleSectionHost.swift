import MonitorCore
import SwiftUI

/// Lets the heading inside a section fold the section down to that heading.
struct SectionCollapse {
    var isCollapsed: Bool
    var toggle: () -> Void
}

extension EnvironmentValues {
    @Entry var sectionCollapse: SectionCollapse?
}

/// Shows a section, or only its heading while the user has it collapsed. The section's own
/// `ConceptHeading` picks up the toggle from the environment.
struct CollapsibleSectionHost<Content: View>: View {
    @Environment(MonitorStore.self) private var store
    var section: CollapsibleSection
    var title: String
    /// Shown beside the title while collapsed, such as the playing track.
    var collapsedDetail: String?
    @ViewBuilder var content: Content

    var body: some View {
        let isCollapsed = store.settings.isCollapsed(section)
        Group {
            if isCollapsed {
                ConceptHeading(title: title, detail: collapsedDetail)
            } else {
                content
            }
        }
        .environment(\.sectionCollapse, SectionCollapse(isCollapsed: isCollapsed, toggle: toggle))
    }

    private func toggle() {
        withAnimation(.smooth(duration: 0.25)) { store.settings.toggleCollapsed(section) }
    }
}
