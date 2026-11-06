import Foundation
import Testing
@testable import MonitorCore

struct SpendTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ text: String) -> Date {
        ClaudeTokenTracker.parseTimestamp(text)!
    }

    private func record(_ timestamp: String, tool: AgentTool = .claude, model: String?, folder: String?, _ tokens: TokenTotals) -> TokenUsageRecord {
        TokenUsageRecord(tool: tool, timestamp: date(timestamp), model: model, workingDirectory: folder, tokens: tokens)
    }

    @Test func longestPrefixPicksTheModelPrice() throws {
        #expect(PriceTable.price(forModel: "claude-opus-5-5")?.input == 4)
        #expect(PriceTable.price(forModel: "claude-opus-5")?.input == 5)
        #expect(PriceTable.price(forModel: "claude-opus-4-5-20251101")?.input == 5)
        #expect(PriceTable.price(forModel: "claude-opus-4-1-20250805")?.input == 15)
        #expect(PriceTable.price(forModel: "gpt-5.2-codex")?.output == 14)
        #expect(PriceTable.price(forModel: "gpt-5-mini")?.input == 0.25)
        #expect(PriceTable.price(forModel: "mystery-model") == nil)
        #expect(PriceTable.price(forModel: nil) == nil)
    }

    @Test func costCoversEveryTokenKind() {
        let price = ModelPrice(input: 4, output: 20)
        let cost = price.cost(of: TokenTotals(input: 1_000_000, output: 1_000_000, cacheRead: 1_000_000, cacheWrite: 1_000_000))
        #expect(abs(cost - (4 + 20 + 0.4 + 5)) < 0.000_001)
    }

    @Test func reportGroupsByDayProjectAndModel() throws {
        let records = [
            record("2026-11-06T09:00:00Z", model: "claude-opus-5-5", folder: "/code/shop", TokenTotals(input: 1_000_000)),
            record("2026-11-06T10:00:00Z", model: "claude-sonnet-5-5", folder: "/code/shop", TokenTotals(output: 100_000)),
            record("2026-11-06T11:00:00Z", tool: .codex, model: "gpt-5", folder: "/code/docs", TokenTotals(input: 2_000_000)),
            record("2026-11-05T11:00:00Z", model: "claude-opus-5-5", folder: "/code/docs", TokenTotals(output: 50_000)),
        ]
        let report = SpendReport.make(records: records, days: 3, now: date("2026-11-06T12:00:00Z"), calendar: calendar) {
            ($0 as NSString?)?.lastPathComponent ?? "?"
        }
        #expect(report.days.count == 3)
        let today = try #require(report.today)
        #expect(abs(today.estimatedCost - (4 + 1 + 2.5)) < 0.000_001)
        #expect(today.projects.map(\.name) == ["shop", "docs"])
        #expect(today.models.map(\.name) == ["claude-opus-5-5", "gpt-5", "claude-sonnet-5-5"])
        #expect(today.models[1].tool == .codex)
        #expect(abs(report.days[1].estimatedCost - 1) < 0.000_001)
        #expect(report.days[2].tokens == TokenTotals())
    }

    @Test func unknownModelsAreCountedButNotPriced() throws {
        let records = [record("2026-11-06T09:00:00Z", model: "local-llama", folder: nil, TokenTotals(input: 500))]
        let today = try #require(SpendReport.make(records: records, days: 1, now: date("2026-11-06T12:00:00Z"), calendar: calendar) { _ in "x" }.today)
        #expect(today.estimatedCost == 0)
        #expect(today.unpricedTokens == 500)
        #expect(today.models.first?.estimatedCost == nil)
    }

    @Test func budgetAlertsOncePerDay() {
        let today = date("2026-11-06T00:00:00Z")
        #expect(!SpendBudget.shouldAlert(todayCost: 4, budget: 5, lastAlertedDay: nil, today: today))
        #expect(SpendBudget.shouldAlert(todayCost: 5, budget: 5, lastAlertedDay: nil, today: today))
        #expect(!SpendBudget.shouldAlert(todayCost: 9, budget: 5, lastAlertedDay: today, today: today))
        #expect(SpendBudget.shouldAlert(todayCost: 9, budget: 5, lastAlertedDay: date("2026-11-05T00:00:00Z"), today: today))
        #expect(!SpendBudget.shouldAlert(todayCost: 9, budget: 0, lastAlertedDay: nil, today: today))
    }

    @Test func claudeRecordKeepsModelAndFolder() throws {
        let line: Substring = #"{"type":"assistant","cwd":"/code/shop","timestamp":"2026-11-03T14:33:17.034Z","requestId":"req_1","message":{"id":"msg_1","model":"claude-opus-5-5","usage":{"input_tokens":2,"output_tokens":490}}}"#
        let record = try #require(ClaudeTokenTracker.parseUsageRecord(line))
        #expect(record.model == "claude-opus-5-5")
        #expect(record.workingDirectory == "/code/shop")
    }

    @Test func codexTurnsUseTurnContextAndSkipRepeats() {
        let lines: [Substring] = [
            #"{"timestamp":"2026-11-06T08:00:00.000Z","type":"turn_context","payload":{"cwd":"/code/docs","model":"gpt-5.2-codex"}}"#,
            #"{"timestamp":"2026-11-06T08:00:01.000Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{}}}"#,
            #"{"timestamp":"2026-11-06T08:00:02.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1100},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":100}}}}"#,
            #"{"timestamp":"2026-11-06T08:00:03.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1100},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":100}}}}"#,
        ]
        var state = CodexTokenTracker.RolloutState()
        let records = CodexTokenTracker.records(in: lines, state: &state)
        #expect(records.count == 1)
        #expect(records.first?.model == "gpt-5.2-codex")
        #expect(records.first?.workingDirectory == "/code/docs")
        #expect(records.first?.tokens == TokenTotals(input: 200, output: 100, cacheRead: 800))
    }
}
