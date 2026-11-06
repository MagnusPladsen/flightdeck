import MonitorCore
import SwiftUI

/// Ignition page list: large bold labels on black, a pill behind the current page, counts in muted text.
/// While the layout is unlocked, each page also takes dropped sections.
struct PageListSidebar: View {
    @Environment(MonitorStore.self) private var store
    @Environment(LayoutEditor.self) private var editor
    @Environment(\.theme) private var theme
    @Binding var selection: DashboardDestination
    var count: (DashboardPage) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label { Text("Flightdeck").font(.system(size: 15, weight: .heavy)) } icon: {
                FormationMark(lead: theme.accent, wingmen: theme.foreground).frame(width: 20, height: 20)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
            ForEach(DashboardPage.allCases) { page in
                PageButton(page: page, count: count(page), isSelected: selection == .page(page)) { selection = .page(page) }
            }
            Spacer()
            FooterButton(title: "Office", systemImage: "gamecontroller", isSelected: selection == .office) { selection = .office }
            FooterButton(title: "Settings", systemImage: "gearshape", isSelected: selection == .settings) { selection = .settings }
        }
        .padding(.top, 44)
        .padding(.bottom, 18)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
        .overlay(alignment: .trailing) { Rectangle().fill(theme.border).frame(width: 1) }
    }
}

private struct PageButton: View {
    @Environment(LayoutEditor.self) private var editor
    @Environment(\.theme) private var theme
    var page: DashboardPage
    var count: Int
    var isSelected: Bool
    var select: () -> Void
    @State private var isHovering = false
    @State private var isDropTarget = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                SidebarIcon(systemName: page.symbolName)
                Text(page.title).font(.system(size: 16, weight: isSelected ? .heavy : .medium)).lineLimit(1).fixedSize()
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(theme.muted).fixedSize()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background, in: Capsule())
            .overlay { if isDropTarget { Capsule().strokeBorder(theme.attention, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])) } }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? theme.foreground : theme.foreground.opacity(0.75))
        .onHover { isHovering = $0 }
        .dropDestination(for: String.self) { tokens, _ in
            guard editor.isEditing, let kind = tokens.first.flatMap(SectionKind.init(token:)) else { return false }
            editor.update { $0.move(kind, to: page) }
            return true
        } isTargeted: { isDropTarget = $0 && editor.isEditing }
    }

    private var background: Color {
        if isSelected { return theme.overlay }
        return isHovering ? theme.surface : .clear
    }
}

/// A destination pinned under the page list, like Office and Settings.
private struct FooterButton: View {
    @Environment(\.theme) private var theme
    var title: String
    var systemImage: String
    var isSelected: Bool
    var select: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                SidebarIcon(systemName: systemImage)
                Text(title).lineLimit(1)
            }
                .font(.system(size: 15, weight: isSelected ? .heavy : .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? theme.overlay : (isHovering ? theme.surface : .clear), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? theme.foreground : theme.muted)
        .onHover { isHovering = $0 }
    }
}

/// A page-list icon in a fixed-width slot, so every item's icon and label start at the same x.
private struct SidebarIcon: View {
    var systemName: String

    var body: some View {
        Image(systemName: systemName).frame(width: 22, alignment: .center)
    }
}
