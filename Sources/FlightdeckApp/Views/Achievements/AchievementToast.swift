import MonitorCore
import SwiftUI

/// A card in the dashboard's corner for achievements that just unlocked; it leaves after a few seconds.
struct AchievementToast: View {
    @Environment(MonitorStore.self) private var store
    @Environment(DashboardNavigation.self) private var navigation
    @Environment(\.theme) private var theme

    var body: some View {
        let unlocks = store.achievements.recentUnlocks
        Group {
            if let first = unlocks.first {
                Button {
                    navigation.destination = .achievements
                    store.achievements.dismissRecentUnlocks()
                } label: {
                    HStack(spacing: 12) {
                        AchievementBadge(symbol: first.symbol, isUnlocked: true).frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unlocks.count == 1 ? "Achievement unlocked" : "\(unlocks.count) achievements unlocked")
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(AchievementBadge.gold)
                            Text(unlocks.map(\.title).joined(separator: ", ")).font(.system(size: 14, weight: .bold)).lineLimit(1)
                            Text(first.detail).font(.system(size: 12)).foregroundStyle(theme.muted).lineLimit(1)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: 340, alignment: .leading)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AchievementBadge.gold.opacity(0.6)) }
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: unlocks.map(\.id)) {
                    try? await Task.sleep(for: .seconds(6))
                    store.achievements.dismissRecentUnlocks()
                }
            }
        }
        .animation(.spring(duration: 0.4), value: unlocks.map(\.id))
    }
}
