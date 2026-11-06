import MonitorCore
import SwiftUI

/// Tokens per project and estimated API-equivalent cost per model. Only placed while spend tracking is on.
struct SpendSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Token spend") {
                Text("Estimated API-equivalent cost, not a bill").font(.system(size: 12)).foregroundStyle(theme.muted)
            }
            if let report = store.spend, let today = report.today {
                SpendSummary(today: today, budget: store.settings.dailySpendBudget, week: report.days)
                SpendTable(title: "Projects today", lines: today.projects, showsTool: false)
                SpendTable(title: "Models today", lines: today.models, showsTool: true)
                footnote(today)
            } else {
                Hairline()
                Text("Reading local agent logs…").font(.system(size: 13)).foregroundStyle(theme.muted).padding(.vertical, 14)
            }
        }
    }

    private func footnote(_ today: DaySpend) -> some View {
        let unpriced = today.unpricedTokens > 0 ? " \(Formatters.tokens(today.unpricedTokens)) tokens from unknown models are not priced." : ""
        return Text("From Claude Code and Codex logs on this Mac, priced at public API list rates (reviewed \(PriceTable.reviewedOn)). Subscriptions are billed differently.\(unpriced)")
            .font(.system(size: 11))
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }
}

/// Today's estimate, the budget bar and a bar per day of the past week.
private struct SpendSummary: View {
    @Environment(\.theme) private var theme
    var today: DaySpend
    var budget: Double
    var week: [DaySpend]

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(theme.muted)
                Text("≈ \(Formatters.dollars(today.estimatedCost))").font(.system(size: 30, weight: .bold).monospacedDigit())
                Text("\(Formatters.tokens(today.tokens.total)) tokens").font(.system(size: 12)).foregroundStyle(theme.muted)
                if let fraction = SpendBudget.fractionUsed(todayCost: today.estimatedCost, budget: budget) {
                    budgetBar(fraction: fraction)
                }
            }
            Spacer(minLength: 12)
            WeekBars(days: week)
        }
        .padding(.vertical, 10)
    }

    private func budgetBar(fraction: Double) -> some View {
        let color = UsageLevel.color(forPercent: fraction * 100, in: theme)
        return VStack(alignment: .leading, spacing: 3) {
            ProgressBar(fraction: fraction, color: color).frame(width: 160)
            Text("\(Formatters.percent(fraction)) of \(Formatters.dollars(budget)) daily budget").font(.system(size: 11)).foregroundStyle(color)
        }
        .padding(.top, 4)
    }
}

private struct WeekBars: View {
    @Environment(\.theme) private var theme
    var days: [DaySpend]

    var body: some View {
        let oldestFirst = Array(days.reversed())
        let highest = max(oldestFirst.map(\.estimatedCost).max() ?? 0, 0.01)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(oldestFirst) { day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(day.id == days.first?.id ? theme.primary : theme.primary.opacity(0.45))
                        .frame(width: 16, height: max(2, 56 * day.estimatedCost / highest))
                    Text(day.day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 10)).foregroundStyle(theme.muted)
                }
                .help("\(day.day.formatted(date: .abbreviated, time: .omitted)): ≈ \(Formatters.dollars(day.estimatedCost)), \(Formatters.tokens(day.tokens.total)) tokens")
            }
        }
    }
}

/// Input, output and cache tokens with the estimate for each line.
private struct SpendTable: View {
    @Environment(\.theme) private var theme
    var title: String
    var lines: [SpendLine]
    var showsTool: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 13, weight: .bold)).padding(.top, 14).padding(.bottom, 6)
            header
            HairlineRows(items: lines, emptyText: "No tokens used today") { row($0) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(["Input", "Output", "Cache", "Cost"], id: \.self) { Text($0).frame(width: 64, alignment: .trailing) }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(theme.muted)
        .padding(.bottom, 4)
    }

    private func row(_ line: SpendLine) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if showsTool, let tool = line.tool { Image(systemName: tool.symbolName).foregroundStyle(theme.muted) }
                Text(line.name).lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            numberCell(Formatters.tokens(line.tokens.input))
            numberCell(Formatters.tokens(line.tokens.output))
            numberCell(Formatters.tokens(line.tokens.cacheRead + line.tokens.cacheWrite))
            numberCell(line.estimatedCost.map { "≈ " + Formatters.dollars($0) } ?? "not priced")
                .foregroundStyle(line.estimatedCost == nil ? theme.muted : theme.foreground)
        }
        .font(.system(size: 13))
    }

    private func numberCell(_ text: String) -> some View {
        Text(text).monospacedDigit().frame(width: 64, alignment: .trailing).lineLimit(1)
    }
}
