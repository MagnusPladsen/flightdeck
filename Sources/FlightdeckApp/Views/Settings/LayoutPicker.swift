import SwiftUI

/// The dashboard layouts, each shown with the theme it was designed in. Picking one switches to that theme too.
struct LayoutPicker: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Layout").font(.headline)
                Text("How the dashboard is arranged. Picking a layout also picks the theme it was designed in; change the theme below whenever you like.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(DashboardLayout.allCases) { layout in
                    option(layout)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func option(_ layout: DashboardLayout) -> some View {
        let isSelected = store.settings.dashboardLayout == layout
        let designTheme = Theme.resolve(id: layout.defaultThemeID, systemScheme: .dark)
        return Button { store.settings.selectLayout(layout) } label: {
            HStack(spacing: 10) {
                LayoutThumbnail(layout: layout, theme: designTheme)
                VStack(alignment: .leading, spacing: 2) {
                    Text(layout.title).fontWeight(.medium)
                    Text(layout.summary).font(.caption).opacity(0.6).lineLimit(2)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.primary)
                }
            }
            .padding(8)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? theme.primary : theme.border, lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A tiny sketch of a layout in its design theme: the sidebar kind and the overview's section blocks.
private struct LayoutThumbnail: View {
    var layout: DashboardLayout
    var theme: Theme

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(theme.overlay)
                .frame(width: layout.style.navigation == .list ? 10 : 4)
            VStack(spacing: 3) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 3) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, block in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(block.isAttention ? theme.warning : theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(theme.border, lineWidth: 0.5))
                                .frame(width: CGFloat(block.span) * 3.2)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .frame(width: 42, alignment: .top)
        }
        .padding(4)
        .frame(width: 60, height: 40, alignment: .topLeading)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var rows: [[(span: Int, isAttention: Bool)]] {
        var rows: [[(span: Int, isAttention: Bool)]] = [[]]
        var used = 0
        for placement in layout.defaultPages.placements(on: .overview) {
            if used + placement.span > 12 {
                rows.append([])
                used = 0
            }
            rows[rows.count - 1].append((placement.span, placement.kind == .needsYou || placement.kind == .yourTurn))
            used += placement.span
        }
        return Array(rows.prefix(5))
    }
}
