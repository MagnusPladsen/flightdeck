import Foundation
import Testing
@testable import MonitorCore

struct ContextUsageTests {
    private func reply(model: String = "claude-opus-5-5", input: Int, cacheRead: Int, sidechain: Bool = false) -> String {
        #"{"type":"assistant","isSidechain":\#(sidechain),"message":{"model":"\#(model)","usage":{"input_tokens":\#(input),"cache_read_input_tokens":\#(cacheRead),"cache_creation_input_tokens":0,"output_tokens":0}}}"#
    }

    private func compaction(before: Int, after: Int) -> String {
        #"{"type":"system","subtype":"compact_boundary","compactMetadata":{"trigger":"auto","preTokens":\#(before),"postTokens":\#(after)}}"#
    }

    private func usage(_ lines: [String]) -> ContextUsage? {
        var replay = ContextReplay()
        ContextUsageReader.apply(lines: lines.joined(separator: "\n"), to: &replay)
        return replay.usage
    }

    @Test func usesTheNewestReply() {
        let context = usage([reply(input: 10, cacheRead: 1000), reply(input: 20, cacheRead: 2000)])
        #expect(context?.usedTokens == 2020)
    }

    @Test func ignoresSubagentReplies() {
        let context = usage([reply(input: 0, cacheRead: 5000), reply(input: 0, cacheRead: 90, sidechain: true)])
        #expect(context?.usedTokens == 5000)
    }

    @Test func measuresAgainstAnEarlierCompaction() {
        let context = usage([compaction(before: 360_000, after: 20_000), reply(input: 0, cacheRead: 324_000)])
        #expect(context?.compactsAtTokens == 360_000)
        #expect(context?.isMeasured == true)
        #expect(context?.isNearlyFull == true)
    }

    @Test func estimatesFromTheModelWithoutACompaction() {
        #expect(usage([reply(input: 0, cacheRead: 100_000)])?.compactsAtTokens == 368_000)
        #expect(usage([reply(model: "claude-haiku-4-5", input: 0, cacheRead: 100_000)])?.compactsAtTokens == 184_000)
    }

    @Test func assumesTheLargeWindowOncePastTheNormalOne() {
        let context = usage([reply(input: 0, cacheRead: 500_000)])
        #expect(context?.compactsAtTokens == 920_000)
        #expect(context?.isNearlyFull == false)
    }
}
