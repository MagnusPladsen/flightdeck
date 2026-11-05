import MonitorCore
import SwiftUI

/// The changelog entries over the dashboard, newest first, shown after an update.
struct WhatsNewCard: View {
    @Environment(\.theme) private var theme
    var whatsNew: WhatsNew

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55)
                .contentShape(Rectangle())
                .onTapGesture { whatsNew.dismiss() }
            card
                .frame(maxWidth: 560)
                .padding(.horizontal, 24)
                .padding(.top, 96)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(theme.border).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(whatsNew.entries, id: \.version) { release($0) }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 420)
            .fixedSize(horizontal: false, vertical: true)
            footer
        }
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(theme.border))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .onExitCommand { whatsNew.dismiss() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FormationMark(lead: theme.accent, wingmen: theme.foreground).frame(width: 22, height: 22)
            Text("What's new").font(.system(size: 22, weight: .black))
            Spacer()
            Button("Done") { whatsNew.dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func release(_ entry: ChangelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.version).font(.system(size: 15, weight: .bold)).foregroundStyle(theme.accent)
                Text(entry.date).font(.system(size: 12)).foregroundStyle(theme.muted)
            }
            ForEach(entry.items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").foregroundStyle(theme.muted)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 14))
            }
        }
    }

    private var footer: some View {
        Text("Return or esc closes")
            .font(.system(size: 11))
            .foregroundStyle(theme.muted)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
    }
}
