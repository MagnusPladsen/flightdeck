import Foundation

/// Recognises coding-agent CLIs from a process's arguments.
public enum AgentDetector {
    /// Node-hosted CLIs show up as `node /…/<package>/cli.js`.
    private static let packageMarkers: [(String, AgentTool)] = [
        ("@anthropic-ai/claude-code", .claude),
        ("@openai/codex", .codex),
        ("@google/gemini-cli", .gemini),
        ("opencode-ai", .opencode),
    ]

    private static let executableNames: [String: AgentTool] = [
        "claude": .claude,
        "codex": .codex,
        "gemini": .gemini,
        "cursor-agent": .cursor,
        "opencode": .opencode,
        "aider": .aider,
    ]

    /// Background engines (e.g. the Codex desktop app server) are not user sessions.
    private static let ignoredSubcommands: Set<String> = ["app-server", "mcp", "mcp-server", "proto"]

    public static func tool(forArguments arguments: [String]) -> AgentTool? {
        guard let executable = arguments.first.map({ ($0 as NSString).lastPathComponent }) else { return nil }
        if arguments.dropFirst().first.map(ignoredSubcommands.contains) == true { return nil }
        if let tool = executableNames[executable] { return tool }

        let isScriptHost = ["node", "bun", "python", "python3"].contains(executable)
        guard isScriptHost else { return nil }
        let script = arguments.dropFirst().first ?? ""
        if let marker = packageMarkers.first(where: { script.contains($0.0) }) { return marker.1 }
        if script.hasSuffix("/aider") { return .aider }
        return nil
    }
}
