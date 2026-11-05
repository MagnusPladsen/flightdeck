import MonitorCore
import SwiftUI

/// Narrow page list of icons, for layouts that give the whole window to their sections.
struct RailSidebar: View {
    @Environment(\.theme) private var theme
    @Binding var selection: DashboardPage
    var count: (DashboardPage) -> Int

    var body: some View {
        VStack(spacing: 6) {
            FormationMark(lead: theme.accent, wingmen: theme.foreground)
                .frame(width: 22, height: 22)
                .padding(.bottom, 16)
            ForEach(DashboardPage.allCases) { page in
                RailButton(page: page, count: count(page), isSelected: page == selection) { selection = page }
            }
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape").font(.system(size: 16)).frame(width: 44, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.muted)
            .help("Settings")
        }
        .padding(.top, 44)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.background)
        .overlay(alignment: .trailing) { Rectangle().fill(theme.border).frame(width: 1) }
    }
}

private struct RailButton: View {
    @Environment(\.theme) private var theme
    var page: DashboardPage
    var count: Int
    var isSelected: Bool
    var select: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            Image(systemName: page.symbolName)
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .frame(width: 44, height: 40)
                .background(isSelected ? theme.overlay : (isHovering ? theme.surface : .clear), in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(count)").font(.system(size: 9, weight: .bold).monospacedDigit()).foregroundStyle(theme.muted).offset(x: 2, y: -2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? theme.foreground : theme.foreground.opacity(0.7))
        .onHover { isHovering = $0 }
        .help(page.title)
    }
}
