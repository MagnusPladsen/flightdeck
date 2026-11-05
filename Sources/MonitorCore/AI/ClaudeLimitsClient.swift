import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches Claude subscription limits (5-hour and weekly utilisation) with Claude Code's own login.
/// This is the endpoint Claude Code's `/usage` screen uses; it is not a public API and may change.
/// Opt-in only: it reads the OAuth token Claude Code stored on this machine and sends it nowhere but Anthropic.
public struct ClaudeLimitsClient: Sendable {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    public init() {}

    public enum FetchResult: Sendable {
        case usage(ProviderUsage)
        case rateLimited(retryAfter: TimeInterval?)
        case failed
    }

    public func fetch() async -> FetchResult {
        guard let credentials = Self.loadCredentials() else { return .failed }
        var request = URLRequest(url: Self.usageURL, timeoutInterval: 10)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse else { return .failed }
        if httpResponse.statusCode == 429 {
            return .rateLimited(retryAfter: httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        }
        let windows = httpResponse.statusCode == 200 ? Self.parseWindows(data) : []
        guard !windows.isEmpty else { return .failed }
        return .usage(ProviderUsage(tool: .claude, plan: credentials.plan, windows: windows, updatedAt: Date()))
    }

    static let windowLabels: [(key: String, label: String)] = [
        ("five_hour", "5h"),
        ("seven_day", "Weekly"),
        ("seven_day_opus", "Weekly Opus"),
        ("seven_day_sonnet", "Weekly Sonnet"),
    ]

    static func parseWindows(_ data: Data) -> [UsageWindow] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return windowLabels.compactMap { key, label in
            guard let window = json[key] as? [String: Any], let utilization = window["utilization"] as? Double else { return nil }
            return UsageWindow(label: label, usedPercent: utilization, resetsAt: ClaudeTokenTracker.parseTimestamp(window["resets_at"] as? String))
        }
    }

    struct Credentials {
        let accessToken: String
        let plan: String?
    }

    /// Linux stores credentials in a file; macOS keeps them in the login keychain.
    static func loadCredentials() -> Credentials? {
        let filePath = NSHomeDirectory() + "/.claude/.credentials.json"
        if let data = FileManager.default.contents(atPath: filePath), let credentials = parseCredentials(data) { return credentials }
        #if os(macOS)
        let result = CommandRunner.run("/usr/bin/security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"], timeout: 5)
        guard result.exitCode == 0 else { return nil }
        return parseCredentials(Data(result.output.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
        #else
        return nil
        #endif
    }

    static func parseCredentials(_ data: Data) -> Credentials? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        return Credentials(accessToken: token, plan: oauth["subscriptionType"] as? String)
    }
}
