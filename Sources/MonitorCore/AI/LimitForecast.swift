import Foundation

public struct UsageSample: Sendable, Hashable {
    public var time: Date
    public var usedPercent: Double

    public init(time: Date, usedPercent: Double) {
        self.time = time
        self.usedPercent = usedPercent
    }
}

/// When a usage window runs out at the recent burn rate, or that it outlasts its reset.
public enum LimitForecast: Sendable, Hashable {
    case reachesLimit(at: Date)
    case lastsUntilReset

    public static let span: TimeInterval = 45 * 60
    public static let minimumSpan: TimeInterval = 5 * 60

    public static func project(_ samples: [UsageSample], resetsAt: Date?) -> LimitForecast? {
        guard let latest = samples.last, latest.usedPercent < 100 else { return nil }
        if let resetsAt, resetsAt <= latest.time { return nil }
        guard let percentPerSecond = burnRate(samples) else { return nil }
        guard percentPerSecond > 0 else { return resetsAt == nil ? nil : .lastsUntilReset }
        let limitAt = latest.time.addingTimeInterval((100 - latest.usedPercent) / percentPerSecond)
        if let resetsAt, limitAt >= resetsAt { return .lastsUntilReset }
        return .reachesLimit(at: limitAt)
    }

    static func burnRate(_ samples: [UsageSample]) -> Double? {
        guard let latest = samples.last,
              let earliest = samples.first(where: { latest.time.timeIntervalSince($0.time) <= span }) else { return nil }
        let elapsed = latest.time.timeIntervalSince(earliest.time)
        guard elapsed >= minimumSpan else { return nil }
        return (latest.usedPercent - earliest.usedPercent) / elapsed
    }
}
