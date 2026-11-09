import Foundation

/// The shell command that starts an agent CLI, optionally with a first prompt.
public enum AgentLaunchCommand {
    public static let launchableTools: [AgentTool] = [.claude, .codex]

    public static func executable(for tool: AgentTool) -> String? {
        switch tool {
        case .claude: "claude"
        case .codex: "codex"
        default: nil
        }
    }

    /// `claude 'fix the login test'`. A prompt starting with `-` follows `--` so it isn't read as a flag.
    public static func command(for tool: AgentTool, prompt: String?) -> String? {
        guard let executable = executable(for: tool) else { return nil }
        guard let prompt = cleanedPrompt(prompt) else { return executable }
        let separator = prompt.hasPrefix("-") ? " --" : ""
        return "\(executable)\(separator) \(ShellQuoting.quote(prompt))"
    }

    /// `cd '/path' && claude`, for terminals that can only type into a fresh shell.
    public static func inFolder(_ folder: String, run command: String) -> String {
        "cd \(ShellQuoting.quote(folder)) && \(command)"
    }

    /// Nil for a prompt that is empty once trimmed; control characters become spaces.
    static func cleanedPrompt(_ prompt: String?) -> String? {
        let cleaned = ShellQuoting.singleLine(prompt ?? "").trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }
}
