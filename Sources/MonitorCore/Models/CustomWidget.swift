import Foundation

/// A user-defined dashboard tile backed by a shell command.
public struct CustomWidget: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var command: String
    public var intervalSeconds: Double
    /// Shows a warning colour when the output parses as a number above this.
    public var warnAbove: Double?

    public init(id: UUID = UUID(), title: String, command: String, intervalSeconds: Double = 30, warnAbove: Double? = nil) {
        self.id = id
        self.title = title
        self.command = command
        self.intervalSeconds = intervalSeconds
        self.warnAbove = warnAbove
    }

    public static let examples: [CustomWidget] = [
        CustomWidget(title: "Docker containers", command: "docker ps -q 2>/dev/null | wc -l | tr -d ' '", intervalSeconds: 30),
        CustomWidget(title: "Dirty repos in ~/git", command: "for d in ~/git/*/; do git -C \"$d\" status --porcelain 2>/dev/null | grep -q . && echo x; done | wc -l | tr -d ' '", intervalSeconds: 120),
        CustomWidget(title: "Public IP", command: "curl -s --max-time 3 https://api.ipify.org", intervalSeconds: 600),
    ]
}

public struct CustomWidgetResult: Sendable, Equatable {
    public var output: String
    public var isError: Bool
    public var updatedAt: Date

    public init(output: String, isError: Bool, updatedAt: Date) {
        self.output = output
        self.isError = isError
        self.updatedAt = updatedAt
    }

    public var numericValue: Double? {
        Double(output.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: ""))
    }

    public static func run(_ widget: CustomWidget) -> CustomWidgetResult {
        let result = CommandRunner.runShell(widget.command)
        let output = result.didTimeOut ? "Timed out" : result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return CustomWidgetResult(output: output, isError: result.exitCode != 0 || result.didTimeOut, updatedAt: Date())
    }
}
