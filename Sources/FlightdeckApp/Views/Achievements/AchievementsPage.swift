import AppKit
import MonitorCore
import SwiftUI

/// Every achievement there is, grouped by category: unlocked ones in gold with their date, the rest with progress.
struct AchievementsPage: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", unlocked = "Unlocked", locked = "Locked"
        var id: String { rawValue }
    }

    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var filter = Filter.all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                summary
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    let achievements = visible(in: category)
                    if !achievements.isEmpty { section(category, achievements) }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
    }

    private var ledger: AchievementLedger { store.achievements.ledger }

    private var summary: some View {
        let total = AchievementCatalog.all.count
        let unlocked = store.achievements.unlockedCount
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(unlocked) of \(total) unlocked").font(.system(size: 26, weight: .heavy)).tracking(-0.4)
                Spacer()
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
            ThinBar(fraction: Double(unlocked) / Double(max(total, 1)), color: AchievementBadge.gold, height: 6)
            Text("Flightdeck counts these on this Mac as you work: agents, music, the office and the dashboard.")
                .font(.callout).foregroundStyle(theme.muted)
        }
    }

    private func visible(in category: AchievementCategory) -> [Achievement] {
        AchievementCatalog.all.filter { achievement in
            guard achievement.category == category else { return false }
            switch filter {
            case .all: return true
            case .unlocked: return ledger.isUnlocked(achievement)
            case .locked: return !ledger.isUnlocked(achievement)
            }
        }
    }

    private func section(_ category: AchievementCategory, _ achievements: [Achievement]) -> some View {
        let unlocked = achievements.filter(ledger.isUnlocked).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(category.rawValue).font(.system(size: 15, weight: .bold))
                Text("\(unlocked)/\(achievements.count)").font(.system(size: 13).monospacedDigit()).foregroundStyle(theme.muted)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                ForEach(achievements) { achievement in
                    AchievementCard(achievement: achievement, value: ledger.value(of: achievement.metric), unlockedAt: ledger.unlocked[achievement.id])
                }
            }
        }
    }
}

private struct AchievementCard: View {
    @Environment(\.theme) private var theme
    var achievement: Achievement
    var value: Double
    var unlockedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AchievementBadge(symbol: achievement.symbol, isUnlocked: unlockedAt != nil).frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                Text(achievement.detail).font(.system(size: 12)).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                footer.padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(unlockedAt != nil ? AchievementBadge.gold.opacity(0.55) : theme.border)
        }
        .opacity(unlockedAt != nil ? 1 : 0.82)
    }

    @ViewBuilder
    private var footer: some View {
        if let unlockedAt {
            Text("Unlocked \(unlockedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(AchievementBadge.gold)
        } else {
            HStack(spacing: 8) {
                ThinBar(fraction: achievement.progress(value), color: theme.accent, height: 3)
                Text("\(AchievementFormat.value(value, of: achievement.metric)) / \(AchievementFormat.value(achievement.goal, of: achievement.metric))")
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(theme.muted).fixedSize()
            }
        }
    }
}

/// A round medal: gold with the symbol when unlocked, a dim outline when not.
struct AchievementBadge: View {
    static let gold = Color(red: 0.96, green: 0.76, blue: 0.26)
    @Environment(\.theme) private var theme
    var symbol: String
    var isUnlocked: Bool

    var body: some View {
        ZStack {
            if isUnlocked {
                Circle().fill(LinearGradient(colors: [Self.gold, Color(red: 0.85, green: 0.5, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5).padding(3)
            } else {
                Circle().fill(theme.overlay)
                Circle().strokeBorder(theme.border, lineWidth: 1)
            }
            Image(systemName: Self.resolvedSymbol(symbol))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isUnlocked ? Color.white : theme.muted)
        }
    }

    /// Falls back to a trophy for symbols this macOS doesn't have.
    private static func resolvedSymbol(_ name: String) -> String {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil ? "trophy.fill" : name
    }
}

enum AchievementFormat {
    static func value(_ value: Double, of metric: AchievementMetric) -> String {
        switch metric {
        case .agentHours, .musicHours: "\(compact(value)) h"
        case .cacheGigabytesCleaned: "\(compact(value)) GB"
        case .peakDailyMillionTokens: "\(compact(value))M"
        case .partyMinutes: "\(compact(value)) min"
        default: compact(value)
        }
    }

    private static func compact(_ value: Double) -> String {
        if value > 0, value < 10, value.rounded() != value { return String(format: "%.1f", value) }
        return Int(value.rounded(.down)).formatted()
    }
}
