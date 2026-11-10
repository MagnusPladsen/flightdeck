import Foundation

/// What a transcript says so far beyond its newest lines: the agent's plan and how full its context is.
public struct TranscriptProgress: Sendable {
    public var plan: AgentPlan?
    public var context: ContextUsage?
}

/// Follows each transcript as it grows, reading only what was appended since the last poll,
/// so a plan set long before the newest lines is still known.
public final class TranscriptTracker: @unchecked Sendable {
    /// How far back the first read of a transcript looks.
    static let firstReadBytes: UInt64 = 4 * 1024 * 1024
    private static let maxTranscripts = 200

    private struct Entry {
        var offset: UInt64
        var plan = PlanReplay()
        var context = ContextReplay()
    }

    private var entries: [String: Entry] = [:]
    private let lock = NSLock()

    public init() {}

    public func progress(ofTranscript path: String) -> TranscriptProgress? {
        lock.withLock {
            guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            var entry = entries[path] ?? Self.freshEntry(size: size)
            if size < entry.offset { entry = Self.freshEntry(size: size) }
            if size > entry.offset {
                try? handle.seek(toOffset: entry.offset)
                let data = handle.readData(ofLength: Int(size - entry.offset))
                if let lastNewline = data.lastIndex(of: 0x0A) {
                    let lines = String(decoding: data[data.startIndex..<lastNewline], as: UTF8.self)
                    AgentPlanReader.apply(lines: lines, to: &entry.plan)
                    ContextUsageReader.apply(lines: lines, to: &entry.context)
                    entry.offset += UInt64(lastNewline - data.startIndex + 1)
                }
            }
            if entries[path] == nil, entries.count >= Self.maxTranscripts { entries.removeAll() }
            entries[path] = entry
            return TranscriptProgress(plan: entry.plan.plan, context: entry.context.usage)
        }
    }

    private static func freshEntry(size: UInt64) -> Entry {
        Entry(offset: size > firstReadBytes ? size - firstReadBytes : 0)
    }
}
