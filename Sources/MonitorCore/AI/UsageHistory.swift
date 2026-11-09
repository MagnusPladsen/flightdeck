import Foundation

/// Recent usage samples per agent and limit window. A window starts over when its
/// usage drops or its reset time moves on.
public struct UsageHistory: Sendable {
    static let resetShift: TimeInterval = 30 * 60

    private struct Track: Sendable {
        var samples: [UsageSample] = []
        var resetsAt: Date?
    }

    private var tracks: [String: Track] = [:]
    private var recordedReadings: [AgentTool: Date] = [:]

    public init() {}

    /// Records each reading once, stamped with when it was read; a provider without that time is stamped `now`.
    public mutating func record(_ usage: [ProviderUsage], now: Date) {
        for provider in usage where isNewReading(provider) {
            for window in provider.windows { record(window, tool: provider.tool, at: provider.updatedAt ?? now) }
        }
    }

    private mutating func isNewReading(_ provider: ProviderUsage) -> Bool {
        guard let updatedAt = provider.updatedAt else { return true }
        guard recordedReadings[provider.tool] != updatedAt else { return false }
        recordedReadings[provider.tool] = updatedAt
        return true
    }

    public mutating func record(_ window: UsageWindow, tool: AgentTool, at time: Date) {
        let key = Self.key(tool: tool, label: window.label)
        var track = tracks[key] ?? Track()
        if Self.hasReset(track, to: window) { track = Track() }
        track.resetsAt = window.resetsAt
        track.samples.append(UsageSample(time: time, usedPercent: window.usedPercent))
        track.samples.removeAll { time.timeIntervalSince($0.time) > LimitForecast.span }
        tracks[key] = track
    }

    public func samples(tool: AgentTool, label: String) -> [UsageSample] {
        tracks[Self.key(tool: tool, label: label)]?.samples ?? []
    }

    public func forecast(tool: AgentTool, window: UsageWindow) -> LimitForecast? {
        LimitForecast.project(samples(tool: tool, label: window.label), resetsAt: window.resetsAt)
    }

    private static func hasReset(_ track: Track, to window: UsageWindow) -> Bool {
        if let last = track.samples.last, window.usedPercent < last.usedPercent { return true }
        guard let previous = track.resetsAt, let next = window.resetsAt else { return false }
        return next.timeIntervalSince(previous) > resetShift
    }

    private static func key(tool: AgentTool, label: String) -> String {
        "\(tool.rawValue)-\(label)"
    }
}
