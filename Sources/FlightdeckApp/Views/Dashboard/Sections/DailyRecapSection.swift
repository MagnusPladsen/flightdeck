import MonitorCore
import SwiftUI

/// Today's agent hours, waits on you and turns per project, with yesterday alongside. Counted locally from
/// Flightdeck's own polls; the spend column and figure only appear while spend tracking is on.
struct DailyRecapSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let today = store.dailyRecap.today
        VStack(alignment: .leading, spacing: 0) {
            ConceptHeading(title: "Today")
            if today.isEmpty {
                Hairline()
                Text("No agent activity yet today. Time is counted while Flightdeck runs.")
                    .font(.system(size: 13)).foregroundStyle(theme.muted).padding(.vertical, 14)
            } else {
                RecapFigures(today: today, yesterday: store.dailyRecap.yesterday, spend: store.spend)
                RecapProjectTable(lines: today.projects, spend: store.spend?.today)
            }
        }
    }
}

/// The day's totals, each with yesterday's figure underneath.
private struct RecapFigures: View {
    var today: DailyRecap
    var yesterday: DailyRecap
    var spend: SpendReport?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 16, alignment: .topLeading)], alignment: .leading, spacing: 14) {
            RecapFigure(label: "Agent time", value: Formatters.duration(today.workingSeconds), previous: Formatters.duration(yesterday.workingSeconds))
            RecapFigure(label: "Waited on you", value: Formatters.duration(today.waitingSeconds),
                        detail: "longest \(Formatters.duration(today.longestWaitSeconds))", previous: Formatters.duration(yesterday.waitingSeconds))
            RecapFigure(label: "Turns", value: "\(today.turns)", detail: "\(today.sessions) sessions", previous: "\(yesterday.turns)")
            if let spend, let todaySpend = spend.today {
                RecapFigure(label: "Est. spend", value: "≈ " + Formatters.dollars(todaySpend.estimatedCost),
                            previous: spend.days.dropFirst().first.map { Formatters.dollars($0.estimatedCost) } ?? "—")
            }
        }
        .padding(.vertical, 10)
    }
}

private struct RecapFigure: View {
    @Environment(\.theme) private var theme
    var label: String
    var value: String
    var detail: String?
    var previous: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(theme.muted).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 24, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(1) }
            }
            Text("Yesterday \(previous)").font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(1)
        }
    }
}

/// A row per project: agent time, waits on you, turns and, with spend tracking on, the estimate.
private struct RecapProjectTable: View {
    @Environment(\.theme) private var theme
    var lines: [RecapLine]
    var spend: DaySpend?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HairlineRows(items: lines, emptyText: "No agent activity yet today") { row($0) }
        }
        .padding(.top, 6)
    }

    private var columns: [String] {
        ["Agents", "Waited", "Turns"] + (spend == nil ? [] : ["Spend"])
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Projects").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(columns, id: \.self) { Text($0).frame(width: 64, alignment: .trailing) }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(theme.muted)
        .padding(.bottom, 4)
    }

    private func row(_ line: RecapLine) -> some View {
        HStack(spacing: 12) {
            Text(line.project).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
            numberCell(Formatters.duration(line.workingSeconds))
            numberCell(Formatters.duration(line.waitingSeconds))
                .help("Longest wait \(Formatters.duration(line.longestWaitSeconds)) · \(line.sessions) sessions")
            numberCell("\(line.turns)")
            if let spend { numberCell(spendText(for: line.project, in: spend)) }
        }
        .font(.system(size: 13))
    }

    private func spendText(for project: String, in spend: DaySpend) -> String {
        spend.projects.first { $0.name == project }?.estimatedCost.map { "≈ " + Formatters.dollars($0) } ?? "—"
    }

    private func numberCell(_ text: String) -> some View {
        Text(text).monospacedDigit().frame(width: 64, alignment: .trailing).lineLimit(1)
    }
}
