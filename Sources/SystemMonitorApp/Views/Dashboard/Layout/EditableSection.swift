import MonitorCore
import SwiftUI

/// Edit-mode chrome around a section: dashed outline, drag handle, hide button and a resize edge.
struct EditableSection<Content: View>: View {
    @Environment(MonitorStore.self) private var store
    @Environment(LayoutEditor.self) private var editor
    @Environment(\.theme) private var theme
    var placement: SectionPlacement
    var page: DashboardPage
    @ViewBuilder var content: Content

    @State private var isDropTarget = false
    @State private var width: CGFloat = 0
    @State private var resizeStart: (span: Int, width: CGFloat)?

    var body: some View {
        content
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(14)
            .padding(.top, 22)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay { outline }
            .overlay(alignment: .topLeading) { toolbar }
            .overlay(alignment: .trailing) { resizeHandle }
            .dropDestination(for: String.self) { tokens, _ in
                guard let kind = tokens.first.flatMap(SectionKind.init(token:)) else { return false }
                editor.update { $0.move(kind, to: page, before: placement.kind) }
                return true
            } isTargeted: { isDropTarget = $0 }
    }

    private var outline: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isDropTarget ? theme.attention : theme.border, style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: [6, 4]))
            .background(theme.foreground.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
                .draggable(placement.kind.token) {
                    Text(placement.kind.title(in: store.settings)).padding(8).background(theme.surface, in: Capsule())
                }
                .help("Drag to move")
            Text(placement.kind.title(in: store.settings)).font(.system(size: 11, weight: .semibold))
            Text("\(placement.span)/\(GridPacking.columns)").font(.system(size: 11).monospacedDigit()).foregroundStyle(theme.muted)
            Menu {
                ForEach(DashboardPage.allCases.filter { $0 != page }) { target in
                    Button(target.title) { editor.update { $0.move(placement.kind, to: target) } }
                }
            } label: { Image(systemName: "arrow.up.right.square") }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .tint(theme.foreground.opacity(0.75))
                .fixedSize()
                .help("Move to another page")
            Button { editor.update { $0.hide(placement.kind) } } label: { Image(systemName: "eye.slash") }
                .buttonStyle(.borderless)
                .help("Hide section")
        }
        .foregroundStyle(theme.foreground.opacity(0.75))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var resizeHandle: some View {
        Capsule()
            .fill(resizeStart == nil ? theme.border : theme.attention)
            .frame(width: 5, height: 44)
            .padding(.trailing, 3)
            .contentShape(Rectangle().inset(by: -8))
            .onHover { inside in inside ? NSCursor.resizeLeftRight.push() : NSCursor.pop() }
            .gesture(resizeGesture)
            .help("Drag to resize")
    }

    /// Snaps the span to the column count closest to the dragged width.
    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { drag in
                let start = resizeStart ?? (placement.span, width)
                resizeStart = start
                let columnWidth = start.width / CGFloat(start.span)
                let span = GridPacking.snapped(Int(((start.width + drag.translation.width) / columnWidth).rounded()))
                if span != placement.span { editor.update { $0.resize(placement.kind, span: span) } }
            }
            .onEnded { _ in resizeStart = nil }
    }
}
