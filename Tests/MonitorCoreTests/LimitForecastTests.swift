import Foundation
@testable import MonitorCore
import Testing

struct LimitForecastTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let minute: TimeInterval = 60

    private func samples(from percent: Double, perMinute: Double, minutes: Int) -> [UsageSample] {
        (0...minutes).map { UsageSample(time: start + Double($0) * minute, usedPercent: percent + perMinute * Double($0)) }
    }

    @Test func steadyBurnReachesTheLimitBeforeReset() {
        let history = samples(from: 40, perMinute: 0.5, minutes: 20)
        let forecast = LimitForecast.project(history, resetsAt: start + 300 * minute)
        #expect(forecast == .reachesLimit(at: start + 20 * minute + 100 * minute))
    }

    @Test func slowBurnLastsUntilReset() {
        let history = samples(from: 10, perMinute: 0.1, minutes: 20)
        #expect(LimitForecast.project(history, resetsAt: start + 60 * minute) == .lastsUntilReset)
    }

    @Test func idleLastsUntilReset() {
        let history = samples(from: 55, perMinute: 0, minutes: 30)
        #expect(LimitForecast.project(history, resetsAt: start + 120 * minute) == .lastsUntilReset)
    }

    @Test func idleWithoutResetTimeHasNoForecast() {
        #expect(LimitForecast.project(samples(from: 55, perMinute: 0, minutes: 30), resetsAt: nil) == nil)
    }

    @Test func burnWithoutResetTimeStillForecasts() {
        let forecast = LimitForecast.project(samples(from: 50, perMinute: 1, minutes: 10), resetsAt: nil)
        #expect(forecast == .reachesLimit(at: start + 50 * minute))
    }

    @Test func tooFewSamplesHaveNoForecast() {
        #expect(LimitForecast.project([], resetsAt: nil) == nil)
        #expect(LimitForecast.project(samples(from: 40, perMinute: 1, minutes: 0), resetsAt: start + 60 * minute) == nil)
    }

    @Test func samplesSpanningUnderFiveMinutesHaveNoForecast() {
        #expect(LimitForecast.project(samples(from: 40, perMinute: 1, minutes: 4), resetsAt: start + 60 * minute) == nil)
    }

    @Test func fullLimitHasNoForecast() {
        #expect(LimitForecast.project(samples(from: 90, perMinute: 1, minutes: 10), resetsAt: start + 60 * minute) == nil)
    }

    @Test func passedResetHasNoForecast() {
        #expect(LimitForecast.project(samples(from: 40, perMinute: 1, minutes: 10), resetsAt: start + 5 * minute) == nil)
    }

    @Test func burnRateOnlyLooksAtTheRecentSpan() {
        let old = samples(from: 0, perMinute: 0, minutes: 60)
        let recent = (1...20).map { UsageSample(time: start + Double(60 + $0) * minute, usedPercent: Double($0)) }
        let rate = LimitForecast.burnRate(old + recent)
        let expected = 20.0 / LimitForecast.span
        #expect(abs((rate ?? 0) - expected) < 0.000_001)
    }
}

struct UsageHistoryTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let minute: TimeInterval = 60

    private func window(_ percent: Double, resetsAt: Date?) -> UsageWindow {
        UsageWindow(label: "5h", usedPercent: percent, resetsAt: resetsAt)
    }

    @Test func steadyBurnForecastsTheLimit() {
        var history = UsageHistory()
        let reset = start + 300 * minute
        for step in 0...10 { history.record(window(50 + Double(step), resetsAt: reset), tool: .claude, at: start + Double(step) * minute) }
        #expect(history.forecast(tool: .claude, window: window(60, resetsAt: reset)) == .reachesLimit(at: start + 50 * minute))
    }

    @Test func droppingUsageStartsOver() {
        var history = UsageHistory()
        for step in 0...10 { history.record(window(80 + Double(step), resetsAt: nil), tool: .codex, at: start + Double(step) * minute) }
        history.record(window(2, resetsAt: nil), tool: .codex, at: start + 11 * minute)
        #expect(history.samples(tool: .codex, label: "5h").map(\.usedPercent) == [2])
    }

    @Test func movedResetTimeStartsOver() {
        var history = UsageHistory()
        history.record(window(10, resetsAt: start + 60 * minute), tool: .claude, at: start)
        history.record(window(10, resetsAt: start + 360 * minute), tool: .claude, at: start + minute)
        #expect(history.samples(tool: .claude, label: "5h").count == 1)
    }

    @Test func slightlyShiftedResetTimeKeepsSamples() {
        var history = UsageHistory()
        history.record(window(10, resetsAt: start + 60 * minute), tool: .claude, at: start)
        history.record(window(11, resetsAt: start + 61 * minute), tool: .claude, at: start + minute)
        #expect(history.samples(tool: .claude, label: "5h").count == 2)
    }

    @Test func oldSamplesAreDropped() {
        var history = UsageHistory()
        for step in 0...90 { history.record(window(1, resetsAt: nil), tool: .claude, at: start + Double(step) * minute) }
        let samples = history.samples(tool: .claude, label: "5h")
        #expect(samples.first.map { (start + 90 * minute).timeIntervalSince($0.time) <= LimitForecast.span } == true)
    }

    @Test func toolsAndWindowsAreTrackedApart() {
        var history = UsageHistory()
        history.record([ProviderUsage(tool: .claude, windows: [window(10, resetsAt: nil)]), ProviderUsage(tool: .codex, windows: [window(70, resetsAt: nil)])], at: start)
        #expect(history.samples(tool: .claude, label: "5h").map(\.usedPercent) == [10])
        #expect(history.samples(tool: .codex, label: "5h").map(\.usedPercent) == [70])
        #expect(history.samples(tool: .claude, label: "Weekly").isEmpty)
    }
}
