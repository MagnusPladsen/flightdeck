import Foundation
import Testing
@testable import MonitorCore

struct ListeningSocketParserTests {
    @Test func lsofMergesIPv4AndIPv6AndKeepsWildcardAsPublic() {
        let output = "p17876\ncnode\nf16\nn*:3000\np17877\ncBooking.A\nf441\nn127.0.0.1:7233\nf442\nn[::1]:7233\n"
        let sockets = LsofListeningSocketScanner.parse(output)
        #expect(sockets == [
            RawListeningSocket(pid: 17876, processName: "node", port: 3000, isLocalOnly: false),
            RawListeningSocket(pid: 17877, processName: "Booking.A", port: 7233, isLocalOnly: true),
        ])
    }

    @Test func ssParsesProcessAndPort() {
        let output = #"LISTEN 0 511 127.0.0.1:5173 0.0.0.0:* users:(("node",pid=4242,fd=20))"#
        #expect(LinuxListeningSocketScanner.parse(output) == [RawListeningSocket(pid: 4242, processName: "node", port: 5173, isLocalOnly: true)])
    }

    @Test func dockerPortsMapToContainerNames() {
        let output = "db\t0.0.0.0:5432->5432/tcp, :::5432->5432/tcp\nweb\t0.0.0.0:8080->80/tcp\n"
        #expect(DockerContainerLookup.parse(output) == [5432: "db", 8080: "web"])
    }
}

struct ProcessParserTests {
    @Test func procArgsSkipsExecPathAndPadding() {
        var buffer: [UInt8] = []
        withUnsafeBytes(of: Int32(2)) { buffer.append(contentsOf: $0) }
        buffer += Array("/usr/bin/node".utf8) + [0, 0, 0]
        buffer += Array("node".utf8) + [0] + Array("server.js".utf8) + [0]
        buffer += Array("PATH=/bin".utf8) + [0]
        #expect(DarwinProcessInspector.parseProcArgs(buffer) == ["node", "server.js"])
    }

    @Test func appBundleNameFromExecutablePath() {
        #expect(DarwinProcessInspector.appBundleName(fromExecutablePath: "/Applications/Zed.app/Contents/MacOS/zed") == "Zed")
        #expect(DarwinProcessInspector.appBundleName(fromExecutablePath: "/usr/local/bin/node") == nil)
    }

    @Test func linuxStatHandlesSpacesInName() {
        let stat = "123 (Web Content) S 1 123 123 0 -1 4194560 100 0 0 0 250 50 0 0 20 0 1 0 100 1000 2048 18446744073709551615"
        let process = LinuxProcessInspector.parseStat(stat, pid: 123)
        #expect(process?.name == "Web Content")
        #expect(process?.parentPID == 1)
        #expect(process?.cpuTimeNanoseconds == 3_000_000_000)
        #expect(process?.memoryBytes == 2048 * 4096)
    }

    @Test func cpuBusyFractionHandlesCounterReset() {
        #expect(SystemCollector.busyFraction(previous: CPUTicks(busy: 10, total: 100), current: CPUTicks(busy: 60, total: 200)) == 0.5)
        #expect(SystemCollector.busyFraction(previous: CPUTicks(busy: 10, total: 100), current: CPUTicks(busy: 5, total: 50)) == 0)
    }
}

struct DetectionTests {
    @Test(arguments: [
        ("node /Users/me/app/node_modules/.bin/next dev -p 3000", "nextjs"),
        ("node /Users/me/app/node_modules/.bin/vite --port 5173", "vite"),
        ("/Users/me/api/bin/Debug/net9.0/Fraktas.Api", "dotnet"),
        ("python manage.py runserver", "django"),
        ("/opt/homebrew/opt/postgresql@16/bin/postgres -D /data", "postgres"),
    ])
    func frameworkFromCommandLine(commandLine: String, expectedID: String) {
        #expect(FrameworkDetector.detect(commandLine: commandLine, processName: "", projectRoot: nil)?.id == expectedID)
    }

    @Test func genericNodeIsRefinedByPackageDependencies() {
        #expect(FrameworkDetector.frameworkFromDependencies(["react", "next"])?.id == "nextjs")
        #expect(FrameworkDetector.frameworkFromDependencies(["express"]) == nil)
    }

    @Test func agentToolsFromArguments() {
        #expect(AgentDetector.tool(forArguments: ["/Users/me/.local/bin/claude", "--resume"]) == .claude)
        #expect(AgentDetector.tool(forArguments: ["node", "/usr/lib/node_modules/@openai/codex/bin/codex.js"]) == .codex)
        #expect(AgentDetector.tool(forArguments: ["codex", "app-server"]) == nil)
        #expect(AgentDetector.tool(forArguments: ["/Applications/Claude.app/Contents/MacOS/Claude"]) == nil)
        #expect(AgentDetector.tool(forArguments: ["node", "server.js"]) == nil)
    }

    @Test func agentStateFromActivity() {
        let now = Date()
        let quiet = { (seconds: TimeInterval, turn: SessionActivity.LastTurn) in SessionActivity(lastWrite: now.addingTimeInterval(-seconds), lastTurn: turn) }
        #expect(AgentCollector.state(cpuPercent: 40, activity: nil, now: now) == .working)
        #expect(AgentCollector.state(cpuPercent: 0, activity: quiet(20, .waitingOnTool), now: now) == .needsApproval)
        #expect(AgentCollector.state(cpuPercent: 0, activity: quiet(20, .finished), now: now) == .yourTurn)
        #expect(AgentCollector.state(cpuPercent: 0, activity: quiet(20, .waitingOnModel), now: now) == .working)
        #expect(AgentCollector.state(cpuPercent: 0, activity: quiet(3600, .finished), now: now) == .idle)
    }
}

struct AgentLogTests {
    @Test func claudeDirectoryEncoding() {
        #expect(ClaudeSessionLogs.encodedDirectoryName(for: "/Users/me/git/app/.claude/worktrees/x") == "-Users-me-git-app--claude-worktrees-x")
    }

    @Test func claudeLastTurnReadsNewestMessage() {
        let tail = """
        {"type":"user","message":{"role":"user"}}
        {"type":"assistant","message":{"stop_reason":"tool_use"}}
        {"type":"system","subtype":"hook"}
        """
        #expect(ClaudeSessionLogs.lastTurn(inTranscriptTail: tail) == .waitingOnTool)
        #expect(ClaudeSessionLogs.lastTurn(inTranscriptTail: #"{"type":"assistant","message":{"stop_reason":"end_turn"}}"#) == .finished)
    }

    @Test func claudeLastActionDescribesNewestToolCallOrText() {
        let tail = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"Done."}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Running the tests."},{"type":"tool_use","name":"Bash","input":{"command":"swift test\\nwait","timeout":120000}}]}}
        {"type":"user","message":{"content":"ok"}}
        """
        #expect(ClaudeSessionLogs.lastAction(inTranscriptTail: tail) == AgentAction(verb: "Running", detail: "swift test"))
        let edit = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/repo/Sources/Theme.swift"}}]}}"#
        #expect(ClaudeSessionLogs.lastAction(inTranscriptTail: edit) == AgentAction(verb: "Editing", detail: "Theme.swift"))
        let question = #"{"type":"assistant","message":{"content":[{"type":"text","text":"Keep the old API?\nIt is used twice."}]}}"#
        #expect(ClaudeSessionLogs.lastAction(inTranscriptTail: question) == AgentAction(verb: "Asked", detail: "Keep the old API?"))
        let markdown = #"{"type":"assistant","message":{"content":[{"type":"text","text":"**Merged** as [#16](https://github.com/x/y/pull/16), see `main`."}]}}"#
        #expect(ClaudeSessionLogs.lastAction(inTranscriptTail: markdown) == AgentAction(verb: "Said", detail: "Merged as #16, see main."))
    }

    @Test func claudeUsageRecordParsesTokens() throws {
        let line: Substring = #"{"type":"assistant","timestamp":"2026-11-03T14:33:17.034Z","requestId":"req_1","message":{"id":"msg_1","usage":{"input_tokens":2,"output_tokens":490,"cache_read_input_tokens":88546,"cache_creation_input_tokens":2389}}}"#
        let record = try #require(ClaudeTokenTracker.parseUsageRecord(line))
        #expect(record.id == "msg_1:req_1")
        #expect(record.tokens == TokenTotals(input: 2, output: 490, cacheRead: 88546, cacheWrite: 2389))
    }

    @Test func codexTokenCountParsesWindows() throws {
        let line: Substring = #"{"timestamp":"2026-04-24T14:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":800,"output_tokens":50}},"rate_limits":{"primary":{"used_percent":9.0,"window_minutes":300,"resets_at":1777073391},"secondary":{"used_percent":13.0,"window_minutes":10080,"resets_at":1777450336},"plan_type":"pro"}}}"#
        let event = try #require(CodexUsageReader.parseTokenCount(line))
        #expect(event.planType == "pro")
        #expect(event.windows.map(\.label) == ["5h", "Weekly"])
        #expect(event.windows.first?.usedPercent == 9)
        #expect(event.totals == TokenTotals(input: 200, output: 50, cacheRead: 800))
    }

    @Test func claudeLimitsParsesKnownWindows() {
        let body = #"{"five_hour":{"utilization":42.0,"resets_at":"2026-11-03T18:00:00Z"},"seven_day":{"utilization":7.5,"resets_at":null},"seven_day_opus":null}"#
        let windows = ClaudeLimitsClient.parseWindows(Data(body.utf8))
        #expect(windows.map(\.label) == ["5h", "Weekly"])
        #expect(windows.first?.resetsAt != nil)
    }
}
