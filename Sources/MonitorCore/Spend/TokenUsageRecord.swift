import Foundation

/// One model reply read from an agent's local log: when, which model, in which folder, and its tokens.
public struct TokenUsageRecord: Sendable, Hashable {
    public var tool: AgentTool
    public var timestamp: Date
    public var model: String?
    public var workingDirectory: String?
    public var tokens: TokenTotals

    public init(tool: AgentTool, timestamp: Date, model: String?, workingDirectory: String?, tokens: TokenTotals) {
        self.tool = tool
        self.timestamp = timestamp
        self.model = model
        self.workingDirectory = workingDirectory
        self.tokens = tokens
    }
}
