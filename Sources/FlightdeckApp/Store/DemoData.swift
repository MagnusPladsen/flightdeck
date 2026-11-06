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
        DevProject(name: name, rootPath: "/Users/alex/code/\(name)", branch: branch, isWorktree: worktree != nil, worktreeName: worktree)
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
        ]
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
