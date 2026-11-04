import SwiftUI

/// Rounded themed card used across the overview.
struct DashboardCard<Content: View, Accessory: View>: View {
    @Environment(\.theme) private var theme
    var title: String
    var systemImage: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 24, height: 24)
                    .background(theme.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                accessory
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border.opacity(0.7)))
    }
}

extension DashboardCard where Accessory == EmptyView {
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, accessory: { EmptyView() }, content: content)
    }
}

/// Small count capsule for card headers.
struct CountPill: View {
    @Environment(\.theme) private var theme
    var text: String
    var color: Color?

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(color ?? theme.foreground.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((color ?? theme.overlay).opacity(color == nil ? 1 : 0.15), in: Capsule())
    }
}
