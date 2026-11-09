import Foundation
import MonitorCore

/// Made-up projects, agents and readings for screenshots. Start the app with FLIGHTDECK_DEMO=1.
@MainActor
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.environment["FLIGHTDECK_DEMO"] != nil }
    static let userName = "Alex"

    private static let nextJS = Framework(id: "nextjs", displayName: "Next.js")
    private static let vite = Framework(id: "vite", displayName: "Vite")
    private static let fastAPI = Framework(id: "fastapi", displayName: "FastAPI")
    private static let docker = Framework(id: "docker", displayName: "Docker")

    private static func project(_ name: String, branch: String, worktree: String? = nil) -> DevProject {
        DevProject(name: name, rootPath: worktreePath(name, worktree), branch: branch, isWorktree: worktree != nil, worktreeName: worktree)
    }

    private static func worktreePath(_ repository: String, _ worktree: String?) -> String {
        let root = "/Users/alex/code/\(repository)"
        return worktree.map { "\(root)/.claude/worktrees/\($0)" } ?? root
    }

    private static func agent(_ tool: AgentTool, _ pid: Int32, _ project: DevProject, _ state: AgentState, minutesAgo: Double, _ verb: String, _ detail: String,
                              stuckReason: StuckReason? = nil) -> AgentSession {
        AgentSession(tool: tool, pid: pid, workingDirectory: project.rootPath, project: project, state: state, cpuPercent: state == .working ? 38 : 0,
                     lastActivity: Date().addingTimeInterval(-minutesAgo * 60), lastAction: AgentAction(verb: verb, detail: detail),
                     stuckReason: stuckReason, resources: resources(pid: pid, state: state))
    }

    private static func resources(pid: Int32, state: AgentState) -> ProcessTreeUsage {
        let spread = Double(pid % 7)
        guard state == .working else { return ProcessTreeUsage(cpuPercent: 0.3 * spread, memoryBytes: UInt64(260 + 20 * spread) << 20, processCount: 2) }
        return ProcessTreeUsage(cpuPercent: 90 + 25 * spread, memoryBytes: UInt64(900 + 150 * spread) << 20, processCount: 4 + Int(spread))
    }

    static var agents: [AgentSession] {
        [
            agent(.claude, 4101, project("storefront", branch: "feat/checkout"), .needsApproval, minutesAgo: 1, "Running", "bun run db:migrate"),
            agent(.claude, 4109, project("analytics", branch: "feat/export"), .possiblyStuck, minutesAgo: 2, "Running", "pytest tests/test_export.py",
                  stuckReason: .repeatingTool(name: "Bash", times: 4)),
            agent(.claude, 4102, project("payments-api", branch: "fix/token-refresh", worktree: "token-refresh"), .yourTurn, minutesAgo: 4, "Said", "Token refresh is fixed and all 212 tests pass. Want me to open a PR?"),
            agent(.codex, 4103, project("docs-site", branch: "main"), .yourTurn, minutesAgo: 12, "Asked", "Should the new guides go under /learn or /docs?"),
            agent(.claude, 4104, project("storefront", branch: "feat/search", worktree: "search"), .working, minutesAgo: 0, "Editing", "SearchResults.tsx"),
            agent(.codex, 4105, project("mobile-app", branch: "release/2.4"), .working, minutesAgo: 0, "Running", "pnpm test --filter checkout"),
            agent(.gemini, 4106, project("infra", branch: "main"), .working, minutesAgo: 1, "Reading", "main.tf"),
            agent(.claude, 4107, project("blog", branch: "main"), .idle, minutesAgo: 95, "Said", "Published the draft."),
            agent(.aider, 4108, project("scripts", branch: "main"), .idle, minutesAgo: 240, "Said", "Done."),
        ].map(withDemoMessage)
    }

    private static func worktree(_ repository: String, _ folder: String?, branch: String, changes: Int = 0, ahead: Int = 0, behind: Int = 0,
                                 isPushed: Bool = true, daysAgo: Double, pullRequest: PullRequestLookup = .none) -> Worktree {
        let root = worktreePath(repository, nil)
        return Worktree(repositoryName: repository, repositoryRoot: root, path: worktreePath(repository, folder), branch: branch, isMain: folder == nil,
                        status: GitStatusSummary(upstream: isPushed ? "origin/\(branch)" : nil, ahead: ahead, behind: behind, changedFileCount: changes),
                        lastCommitDate: Date().addingTimeInterval(-daysAgo * 86_400), pullRequest: pullRequest)
    }

    private static func pullRequest(_ number: Int, _ state: PullRequestState, checks: CheckStatus? = nil, review: ReviewState? = nil, isDraft: Bool = false) -> PullRequestLookup {
        .found(PullRequestInfo(number: number, state: state, url: "https://github.com/alex/storefront/pull/\(number)", isDraft: isDraft, checks: checks, review: review))
    }

    static var worktrees: [Worktree] {
        [
            worktree("storefront", nil, branch: "feat/checkout", changes: 2, ahead: 1, daysAgo: 0.1, pullRequest: pullRequest(479, .open, checks: .passing, review: .approved)),
            worktree("storefront", "search", branch: "feat/search", changes: 4, ahead: 2, daysAgo: 0.02, pullRequest: pullRequest(482, .open, checks: .failing, review: .changesRequested)),
            worktree("storefront", "cart-totals", branch: "fix/cart-totals", ahead: 1, daysAgo: 0.2, pullRequest: pullRequest(484, .open, checks: .pending, review: .reviewRequired, isDraft: true)),
            worktree("storefront", "brave-turing-1a2b3c", branch: "claude/brave-turing", daysAgo: 23, pullRequest: pullRequest(451, .merged)),
            worktree("storefront", "holiday-banner", branch: "feat/holiday-banner", isPushed: false, daysAgo: 41),
            worktree("payments-api", nil, branch: "main", behind: 3, daysAgo: 2),
            worktree("payments-api", "token-refresh", branch: "fix/token-refresh", ahead: 5, daysAgo: 0.05),
            worktree("payments-api", "spike-grpc", branch: "spike/grpc", changes: 7, isPushed: false, daysAgo: 60),
            worktree("payments-api", "webhook-retry", branch: "fix/webhook-retry", daysAgo: 30, pullRequest: pullRequest(97, .closed)),
            worktree("payments-api", "rate-limits", branch: "feat/rate-limits", daysAgo: 19, pullRequest: pullRequest(88, .merged)),
        ]
    }

    static var ports: [ListeningPort] {
        [
            ListeningPort(port: 3000, pid: 5101, processName: "node", isLocalOnly: true, project: project("storefront", branch: "feat/checkout"), framework: nextJS),
            ListeningPort(port: 3001, pid: 5102, processName: "node", isLocalOnly: true, project: project("storefront", branch: "feat/search", worktree: "search"), framework: nextJS),
            ListeningPort(port: 5173, pid: 5103, processName: "node", isLocalOnly: true, project: project("docs-site", branch: "main"), framework: vite),
            ListeningPort(port: 8000, pid: 5104, processName: "python3", isLocalOnly: true, project: project("payments-api", branch: "fix/token-refresh", worktree: "token-refresh"), framework: fastAPI),
            ListeningPort(port: 5432, pid: 5105, processName: "com.docker.backend", isLocalOnly: false, framework: docker, containerName: "storefront-postgres-1"),
            ListeningPort(port: 6379, pid: 5106, processName: "com.docker.backend", isLocalOnly: false, framework: docker, containerName: "storefront-redis-1"),
            ListeningPort(port: 3002, pid: 5107, processName: "node", isLocalOnly: true, commandLine: "node node_modules/.bin/next dev", project: project("admin", branch: "main"), framework: nextJS),
        ]
    }

    private static var crashedAnalytics: ListeningPort {
        let arguments = ["uvicorn", "app.main:app", "--reload", "--port", "8010"]
        return ListeningPort(port: 8010, pid: 5108, processName: "python3", isLocalOnly: true, commandLine: arguments.joined(separator: " "), arguments: arguments,
                             workingDirectory: worktreePath("analytics", nil), project: project("analytics", branch: "feat/export"), framework: fastAPI)
    }

    static var crashedServers: [CrashedServer] {
        [CrashedServer(id: ServerIdentity(folder: worktreePath("analytics", nil), port: 8010), server: crashedAnalytics, stoppedAt: Date().addingTimeInterval(-3 * 60))]
    }

    static var serverLogs: [ServerIdentity: [String]] {
        [ServerIdentity(folder: worktreePath("analytics", nil), port: 8010): [
            "INFO:     Application startup complete.",
            "INFO:     127.0.0.1:52114 - \"GET /export?format=csv HTTP/1.1\" 200 OK",
            "WARNING:  WatchFiles detected changes in 'app/export.py'. Reloading...",
            "  File \"/Users/alex/code/analytics/app/export.py\", line 41",
            "SyntaxError: unexpected indent",
        ]]
    }

    static var usage: [ProviderUsage] {
        let hour: TimeInterval = 3600
        return [
            ProviderUsage(tool: .claude, plan: "Max", windows: [
                UsageWindow(label: "5h", usedPercent: 42, resetsAt: Date().addingTimeInterval(2.4 * hour)),
                UsageWindow(label: "Weekly", usedPercent: 63, resetsAt: Date().addingTimeInterval(52 * hour)),
            ], tokensToday: TokenTotals(input: 1_200_000, output: 380_000, cacheRead: 9_400_000)),
            ProviderUsage(tool: .codex, plan: "Pro", windows: [
                UsageWindow(label: "5h", usedPercent: 18, resetsAt: Date().addingTimeInterval(3.1 * hour)),
                UsageWindow(label: "Weekly", usedPercent: 35, resetsAt: Date().addingTimeInterval(70 * hour)),
            ]),
        ]
    }

    /// A week of made-up replies across a few projects and models.
    static var spend: SpendReport {
        let usage: [(project: String, tool: AgentTool, model: String, tokens: TokenTotals)] = [
            ("storefront", .claude, "claude-opus-5-5", TokenTotals(input: 42_000, output: 310_000, cacheRead: 6_100_000, cacheWrite: 480_000)),
            ("payments-api", .claude, "claude-sonnet-5-5", TokenTotals(input: 18_000, output: 140_000, cacheRead: 2_900_000, cacheWrite: 220_000)),
            ("mobile-app", .codex, "gpt-5.2-codex", TokenTotals(input: 380_000, output: 90_000, cacheRead: 1_700_000)),
            ("docs-site", .codex, "gpt-5.2-codex", TokenTotals(input: 120_000, output: 26_000, cacheRead: 640_000)),
            ("blog", .claude, "claude-haiku-5-5", TokenTotals(input: 9_000, output: 30_000, cacheRead: 400_000, cacheWrite: 60_000)),
        ]
        let weekShape = [1.0, 0.7, 1.3, 0.4, 0.9, 1.1, 0.6]
        let records = weekShape.enumerated().flatMap { dayOffset, scale in
            usage.map { item in
                TokenUsageRecord(tool: item.tool, timestamp: Date().addingTimeInterval(-Double(dayOffset) * 86_400), model: item.model,
                                 workingDirectory: "/Users/alex/code/\(item.project)", tokens: scaled(item.tokens, by: scale))
            }
        }
        return SpendReport.make(records: records, days: weekShape.count) { ($0 as NSString?)?.lastPathComponent ?? "Unknown folder" }
    }

    private static func scaled(_ tokens: TokenTotals, by scale: Double) -> TokenTotals {
        TokenTotals(input: Int(Double(tokens.input) * scale), output: Int(Double(tokens.output) * scale),
                    cacheRead: Int(Double(tokens.cacheRead) * scale), cacheWrite: Int(Double(tokens.cacheWrite) * scale))
    }

    /// Today and yesterday of agent hours, waits and turns for the Today section.
    static var recap: RecapLedger {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        return RecapLedger(days: [
            RecapDay(day: today, projects: [
                "storefront": recapTally(hours: 3.4, waitMinutes: 41, longest: 14, turns: 17, sessions: [4101, 4104]),
                "payments-api": recapTally(hours: 1.6, waitMinutes: 22, longest: 9, turns: 8, sessions: [4102]),
                "mobile-app": recapTally(hours: 1.1, waitMinutes: 6, longest: 4, turns: 5, sessions: [4105]),
                "docs-site": recapTally(hours: 0.5, waitMinutes: 18, longest: 12, turns: 4, sessions: [4103]),
                "analytics": recapTally(hours: 0.4, waitMinutes: 3, longest: 2, turns: 2, sessions: [4109]),
            ]),
            RecapDay(day: yesterday, projects: [
                "storefront": recapTally(hours: 2.8, waitMinutes: 55, longest: 21, turns: 15, sessions: [3901, 3902]),
                "payments-api": recapTally(hours: 2.1, waitMinutes: 30, longest: 11, turns: 11, sessions: [3903, 3904]),
                "infra": recapTally(hours: 0.7, waitMinutes: 8, longest: 5, turns: 3, sessions: [3905]),
            ]),
        ])
    }

    private static func recapTally(hours: Double, waitMinutes: Double, longest: Double, turns: Int, sessions: Set<Int32>) -> RecapTally {
        RecapTally(workingSeconds: hours * 3600, waitingSeconds: waitMinutes * 60, longestWaitSeconds: longest * 60, turns: turns, sessionIDs: sessions)
    }

    static var nowPlaying: NowPlayingTrack {
        NowPlayingTrack(title: "Midnight Commute", artist: "Low Orbit", album: "Night Shift Tapes", isPlaying: true,
                        sourceBundleID: "com.apple.Music", sourceName: "Music", duration: 227, elapsed: 83, reportedAt: Date(), identifier: "demo")
    }

    static var snapshot: SystemSnapshot {
        let gigabyte: UInt64 = 1 << 30
        return SystemSnapshot(
            timestamp: Date(), hostName: "Alex's MacBook Pro", uptime: 3 * 86400 + 5 * 3600, loadAverage: [4.2, 3.9, 3.5],
            cpu: CPUUsage(total: 0.34, perCore: Array(repeating: 0.34, count: 12)),
            memory: MemoryUsage(totalBytes: 36 * gigabyte, usedBytes: 22 * gigabyte, wiredBytes: 4 * gigabyte, compressedBytes: 2 * gigabyte, swapUsedBytes: 0, pressure: .normal),
            disks: [DiskUsage(name: "Macintosh HD", mountPath: "/", totalBytes: 1000 * gigabyte, availableBytes: 412 * gigabyte)],
            network: NetworkThroughput(bytesInPerSecond: 1_800_000, bytesOutPerSecond: 240_000),
            battery: nil,
            processes: [
                ProcessSample(pid: 4104, parentPID: 1, name: "claude", cpuPercent: 38.2, memoryBytes: 610 << 20),
                ProcessSample(pid: 5101, parentPID: 1, name: "node", cpuPercent: 21.5, memoryBytes: 1_100 << 20),
                ProcessSample(pid: 4105, parentPID: 1, name: "codex", cpuPercent: 17.9, memoryBytes: 420 << 20),
                ProcessSample(pid: 5104, parentPID: 1, name: "python3", cpuPercent: 6.4, memoryBytes: 310 << 20),
                ProcessSample(pid: 5105, parentPID: 1, name: "com.docker.backend", cpuPercent: 4.1, memoryBytes: 2_300 << 20),
            ])
    }

    /// A gently wandering history so sparklines have a shape.
    static func history(around value: Double, swing: Double) -> [Double] {
        (0..<MonitorStore.historyLength).map { value + swing * sin(Double($0) / 6) * cos(Double($0) / 17) }
    }
}
