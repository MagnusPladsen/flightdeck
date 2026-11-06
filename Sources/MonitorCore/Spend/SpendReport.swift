import Foundation

/// Tokens and estimated API-equivalent cost for one slice of a day: a project or a model.
public struct SpendLine: Sendable, Hashable, Identifiable {
    public var id: String { name + "|" + (tool?.rawValue ?? "") }
    public var name: String
    /// Set for model lines, so Claude and Codex models with similar names stay apart.
    public var tool: AgentTool?
    public var tokens: TokenTotals
    /// Nil when none of the tokens could be priced.
    public var estimatedCost: Double?

    public init(name: String, tool: AgentTool? = nil, tokens: TokenTotals, estimatedCost: Double?) {
        self.name = name
        self.tool = tool
        self.tokens = tokens
        self.estimatedCost = estimatedCost
    }
}

public struct DaySpend: Sendable, Hashable, Identifiable {
    public var id: Date { day }
    public var day: Date
    public var tokens: TokenTotals
    public var estimatedCost: Double
    /// Tokens from models missing in `PriceTable`, left out of the cost.
    public var unpricedTokens: Int
    /// Costliest first, then by tokens.
    public var projects: [SpendLine]
    public var models: [SpendLine]
}

/// Token use and estimated cost per day, project and model, built from agent log records.
public struct SpendReport: Sendable, Hashable {
    /// Newest first, one entry per calendar day in the range even when nothing was used.
    public var days: [DaySpend]

    public init(days: [DaySpend]) {
        self.days = days
    }

    public var today: DaySpend? { days.first }

    public static func make(records: [TokenUsageRecord], days: Int, now: Date = Date(), calendar: Calendar = .current,
                            projectName: (String?) -> String) -> SpendReport {
        let byDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.timestamp) }
        let today = calendar.startOfDay(for: now)
        let dayStarts = (0..<max(days, 1)).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        return SpendReport(days: dayStarts.map { day in
            daySpend(day: day, records: byDay[day] ?? [], projectName: projectName)
        })
    }

    private static func daySpend(day: Date, records: [TokenUsageRecord], projectName: (String?) -> String) -> DaySpend {
        let unpriced = records.filter { PriceTable.price(forModel: $0.model) == nil }
        return DaySpend(
            day: day,
            tokens: records.map(\.tokens).reduce(TokenTotals(), +),
            estimatedCost: records.compactMap(estimatedCost).reduce(0, +),
            unpricedTokens: unpriced.map(\.tokens.total).reduce(0, +),
            projects: lines(records, key: { (projectName($0.workingDirectory), nil) }),
            models: lines(records, key: { ($0.model ?? "unknown model", $0.tool) })
        )
    }

    private struct LineKey: Hashable {
        var name: String
        var tool: AgentTool?
    }

    private static func lines(_ records: [TokenUsageRecord], key: (TokenUsageRecord) -> (String, AgentTool?)) -> [SpendLine] {
        let grouped = Dictionary(grouping: records) { record in
            let (name, tool) = key(record)
            return LineKey(name: name, tool: tool)
        }
        return grouped.map { key, group in
            let costs = group.compactMap(estimatedCost)
            return SpendLine(name: key.name, tool: key.tool, tokens: group.map(\.tokens).reduce(TokenTotals(), +),
                             estimatedCost: costs.isEmpty ? nil : costs.reduce(0, +))
        }
        .sorted { ($0.estimatedCost ?? 0, $0.tokens.total, $1.name) > ($1.estimatedCost ?? 0, $1.tokens.total, $0.name) }
    }

    private static func estimatedCost(of record: TokenUsageRecord) -> Double? {
        PriceTable.price(forModel: record.model)?.cost(of: record.tokens)
    }
}

/// Decides when the optional daily budget alert fires: once per day, the first time today's estimate passes it.
public enum SpendBudget {
    public static func shouldAlert(todayCost: Double, budget: Double, lastAlertedDay: Date?, today: Date) -> Bool {
        guard budget > 0, todayCost >= budget else { return false }
        return lastAlertedDay != today
    }

    public static func fractionUsed(todayCost: Double, budget: Double) -> Double? {
        budget > 0 ? todayCost / budget : nil
    }
}
