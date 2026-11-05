import Foundation

/// Decides when to ask Anthropic for Claude limits again, and keeps the last good answer.
/// The usage endpoint rate-limits hard, so a failed or limited request keeps showing the
/// previous values and waits longer before the next try.
public struct ClaudeLimitsSchedule: Sendable {
    public static let refreshInterval: TimeInterval = 5 * 60
    public static let maximumBackoff: TimeInterval = 30 * 60

    public private(set) var lastUsage: ProviderUsage?
    public private(set) var nextFetch: Date = .distantPast
    private var failures = 0

    public init() {}

    public func isDue(at now: Date) -> Bool {
        now >= nextFetch
    }

    public mutating func record(_ result: ClaudeLimitsClient.FetchResult, at now: Date) {
        switch result {
        case .usage(let usage):
            lastUsage = usage
            failures = 0
            nextFetch = now + Self.refreshInterval
        case .rateLimited(let retryAfter):
            failures += 1
            nextFetch = now + max(retryAfter ?? 0, backoff())
        case .failed:
            failures += 1
            nextFetch = now + backoff()
        }
    }

    private func backoff() -> TimeInterval {
        min(Self.refreshInterval * pow(2, Double(failures - 1)), Self.maximumBackoff)
    }
}
