import SwiftUI

extension View {
    /// Opens a card with `detail` shortly after the pointer rests on the view, and closes it when the pointer leaves.
    func hoverDetail(_ detail: ResourceDetail?) -> some View {
        modifier(HoverDetailModifier(detail: detail))
    }
}

private struct HoverDetailModifier: ViewModifier {
    static let delay: Duration = .milliseconds(350)
    var detail: ResourceDetail?
    @State private var isShown = false
    @State private var pendingShow: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover(perform: hover)
            .popover(isPresented: $isShown, arrowEdge: .bottom) {
                if let detail { ResourceHoverCard(detail: detail) }
            }
    }

    private func hover(_ isInside: Bool) {
        pendingShow?.cancel()
        guard isInside, detail != nil else { return isShown = false }
        pendingShow = Task {
            try? await Task.sleep(for: Self.delay)
            if !Task.isCancelled { isShown = true }
        }
    }
}

/// A title, ranked rows with bars, and short notes.
struct ResourceHoverCard: View {
    @Environment(\.theme) private var theme
    var detail: ResourceDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.muted)
            ForEach(detail.rows) { row in
                HStack(spacing: 8) {
                    Text(row.name).lineLimit(1).truncationMode(.middle)
                    if row.processCount > 1 { Text("\(row.processCount)").font(.caption2.monospacedDigit()).foregroundStyle(theme.muted) }
                    Spacer(minLength: 12)
                    ThinBar(fraction: row.fraction, color: theme.info, height: 3).frame(width: 54)
                    Text(row.value).monospacedDigit().frame(minWidth: 58, alignment: .trailing)
                }
                .font(.system(size: 13))
            }
            ForEach(Array(detail.notes.enumerated()), id: \.offset) { index, note in
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(detail.isWarning && index == detail.notes.count - 1 ? theme.warning : theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }
}
