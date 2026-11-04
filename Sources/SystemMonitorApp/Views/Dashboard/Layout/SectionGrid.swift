import MonitorCore
import SwiftUI

/// Lays sections out on a 12-column grid. Each row is as tall as its tallest section;
/// narrow windows stack every section at full width.
struct SectionGrid: Layout {
    var spans: [Int]
    var columnSpacing: CGFloat = 32
    var rowSpacing: CGFloat = 36
    var stackBelowWidth: CGFloat = 760

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1000
        let frames = frames(width: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in frames(width: bounds.width, subviews: subviews).enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let effectiveSpans = width < stackBelowWidth ? spans.map { _ in GridPacking.columns } : spans
        let columnWidth = (width - columnSpacing * CGFloat(GridPacking.columns - 1)) / CGFloat(GridPacking.columns)
        var frames = Array(repeating: CGRect.zero, count: subviews.count)
        var y: CGFloat = 0
        for row in GridPacking.rows(spans: effectiveSpans) {
            var x: CGFloat = 0
            let widths = row.map { CGFloat(effectiveSpans[$0]) * (columnWidth + columnSpacing) - columnSpacing }
            let height = zip(row, widths).map { subviews[$0].sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
            for (index, itemWidth) in zip(row, widths) {
                frames[index] = CGRect(x: x, y: y, width: itemWidth, height: height)
                x += itemWidth + columnSpacing
            }
            y += height + rowSpacing
        }
        return frames
    }
}
