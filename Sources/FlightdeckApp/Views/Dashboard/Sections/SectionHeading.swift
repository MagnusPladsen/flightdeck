import SwiftUI

/// Title row of a grid section: name, count and optional trailing controls.
struct SectionHeading<Trailing: View>: View {
    @Environment(\.theme) private var theme
    var title: String
    var count: Int?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 15, weight: .bold))
            if let count {
                Text("\(count)").font(.system(size: 15)).foregroundStyle(theme.muted)
            }
            Spacer()
            trailing
        }
        .padding(.bottom, 6)
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(title: String, count: Int? = nil) {
        self.init(title: title, count: count) { EmptyView() }
    }
}

/// Rows separated by hairlines, with a muted line when there are none.
struct HairlineRows<Item: Identifiable, Row: View>: View {
    @Environment(\.theme) private var theme
    var items: [Item]
    var emptyText: String
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Hairline()
                Text(emptyText).font(.system(size: 13)).foregroundStyle(theme.muted).padding(.vertical, 14)
            }
            ForEach(items) { item in
                Hairline()
                row(item).padding(.vertical, 8)
            }
        }
    }
}
