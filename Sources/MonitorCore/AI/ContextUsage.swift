import Foundation

/// How full a Claude session's context is, measured against the point where Claude Code compacts it.
public struct ContextUsage: Sendable, Hashable {
    public static let nearlyFullFraction = 0.85

    public var usedTokens: Int
    /// Tokens at which the session auto-compacts: seen in the transcript, or estimated from the model.
    public var compactsAtTokens: Int
    /// False when `compactsAtTokens` was estimated rather than seen in this transcript.
    public var isMeasured: Bool

    public init(usedTokens: Int, compactsAtTokens: Int, isMeasured: Bool) {
        self.usedTokens = usedTokens
        self.compactsAtTokens = compactsAtTokens
        self.isMeasured = isMeasured
    }

    public var fraction: Double { min(1, Double(usedTokens) / Double(max(compactsAtTokens, 1))) }
    public var isNearlyFull: Bool { fraction >= Self.nearlyFullFraction }
}

/// Reads the token usage Claude Code logs on each assistant reply and the compactions it records.
public enum ContextUsageReader {
    /// Claude Code compacts a little before the window is full.
    static let compactionShare = 0.92
    static let defaultWindow = 200_000
    static let largeWindow = 1_000_000

    static func apply(lines text: String, to replay: inout ContextReplay) {
        for line in text.split(separator: "\n") {
            if line.contains(#""type":"assistant""#), line.contains(#""usage""#), !line.contains(#""isSidechain":true"#) {
                applyAssistant(line, to: &replay)
            } else if line.contains(#""compact_boundary""#) {
                applyCompaction(line, to: &replay)
            }
        }
    }

    private static func applyAssistant(_ line: Substring, to replay: inout ContextReplay) {
        guard let entry = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let message = entry["message"] as? [String: Any], let usage = message["usage"] as? [String: Any] else { return }
        let used = ["input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens", "output_tokens"].reduce(0) { $0 + (usage[$1] as? Int ?? 0) }
        guard used > 0 else { return }
        replay.usedTokens = used
        if let model = message["model"] as? String, model.hasPrefix("claude-") { replay.model = model }
    }

    private static func applyCompaction(_ line: Substring, to replay: inout ContextReplay) {
        guard let entry = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let metadata = entry["compactMetadata"] as? [String: Any] else { return }
        if metadata["trigger"] as? String == "auto", let before = metadata["preTokens"] as? Int { replay.compactedAtTokens = before }
        if let after = metadata["postTokens"] as? Int { replay.usedTokens = after }
    }

    /// The window for models that do not say: current Claude models have 400k, older ones 200k,
    /// and a session already past that runs with the 1M window.
    static func estimatedCompactionPoint(model: String?, usedTokens: Int) -> Int {
        let window = model.map(window(ofModel:)) ?? defaultWindow
        let point = Int(Double(window) * compactionShare)
        return usedTokens > point ? Int(Double(largeWindow) * compactionShare) : point
    }

    private static func window(ofModel model: String) -> Int {
        let isCurrentGeneration = ["opus-5", "sonnet-5", "fable-5"].contains { model.contains($0) }
        return isCurrentGeneration ? 400_000 : defaultWindow
    }
}

struct ContextReplay {
    var usedTokens: Int?
    var model: String?
    var compactedAtTokens: Int?

    var usage: ContextUsage? {
        guard let usedTokens else { return nil }
        if let compactedAtTokens, usedTokens <= compactedAtTokens {
            return ContextUsage(usedTokens: usedTokens, compactsAtTokens: compactedAtTokens, isMeasured: true)
        }
        return ContextUsage(usedTokens: usedTokens, compactsAtTokens: ContextUsageReader.estimatedCompactionPoint(model: model, usedTokens: usedTokens), isMeasured: false)
    }
}
