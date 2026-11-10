import MonitorCore
import SwiftUI

/// Narrow page list of icons, for layouts that give the whole window to their sections.
struct RailSidebar: View {
    @Environment(\.theme) private var theme
    @Binding var selection: DashboardDestination
    var count: (DashboardPage) -> Int

    var body: some View {
        VStack(spacing: 6) {
            FormationMark(lead: theme.accent, wingmen: theme.foreground)
                .frame(width: 22, height: 22)
                .padding(.bottom, 16)
            ForEach(DashboardPage.allCases) { page in
                RailButton(symbolName: page.symbolName, title: page.title, count: count(page), isSelected: selection == .page(page)) { selection = .page(page) }
            }
            Spacer()
            RailButton(symbolName: "gamecontroller", title: "Office", count: 0, isSelected: selection == .office) { selection = .office }
            RailButton(symbolName: "trophy", title: "Achievements", count: 0, isSelected: selection == .achievements) { selection = .achievements }
            RailButton(symbolName: "gearshape", title: "Settings", count: 0, isSelected: selection == .settings) { selection = .settings }
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
    var symbolName: String
    var title: String
    var count: Int
    var isSelected: Bool
    var select: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .modifier(SelectedBeat(isSelected: isSelected))
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
        .help(title)
    }
}
