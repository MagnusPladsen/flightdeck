import Foundation
import MonitorCore

/// Demo last messages, task lists and change peeks for the agent cards.
extension DemoData {
    private static let lastMessages: [Int32: String] = [
        4101: "Wants to run bun run db:migrate",
        4102: "Should I open it against main, or stack it on fix/session-expiry?",
        4103: "I moved the four draft guides into one folder. Should they live under /learn or /docs?",
    ]

    private static let plans: [Int32: AgentPlan] = [
        4104: plan(done: ["Read the search code", "Add a results hook"], current: "Rework SearchResults.tsx", pending: ["Add tests", "Run the test suite"]),
        4101: plan(done: ["Add the sessions table", "Create sessions at checkout"], current: "Run the migration", pending: ["Test checkout end to end"]),
        4109: plan(done: ["Find the export bug"], current: "Fix the CSV encoding", pending: ["Rerun the export tests"]),
    ]

    private static func plan(done: [String], current: String, pending: [String]) -> AgentPlan {
        AgentPlan(steps: done.map { AgentPlan.Step(title: $0, status: .completed) } + [AgentPlan.Step(title: current, status: .inProgress)]
            + pending.map { AgentPlan.Step(title: $0, status: .pending) })
    }

    /// Share of the context used, for Claude sessions.
    private static let contextFractions: [Int32: Double] = [4101: 0.42, 4109: 0.63, 4102: 0.31, 4104: 0.88, 4107: 0.12]

    static func withDemoMessage(_ agent: AgentSession) -> AgentSession {
        var agent = agent
        agent.lastMessage = lastMessages[agent.pid]
        agent.plan = plans[agent.pid]
        agent.context = contextFractions[agent.pid].map { ContextUsage(usedTokens: Int(368_000 * $0), compactsAtTokens: 368_000, isMeasured: true) }
        return agent
    }

    private static func changes(_ folder: String, _ files: [FileChange]) -> AgentChanges {
        AgentChanges(baseline: ChangeBaseline(repositoryRoot: "/Users/alex/code/\(folder)", commit: "4f9c2e1"), files: files)
    }

    static var agentChanges: [Int32: AgentChanges] {
        [
            4101: changes("storefront", [
                FileChange(path: "db/migrations/0042_checkout_sessions.sql", added: 38, removed: 0, isUntracked: true),
                FileChange(path: "src/checkout/session.ts", added: 54, removed: 11),
                FileChange(path: "src/checkout/session.test.ts", added: 26, removed: 5),
                FileChange(path: "package.json", added: 2, removed: 2),
            ]),
            4102: changes("payments-api", [
                FileChange(path: "app/auth/refresh.py", added: 121, removed: 47),
                FileChange(path: "app/auth/tokens.py", added: 33, removed: 9),
                FileChange(path: "tests/test_refresh.py", added: 60, removed: 7),
            ]),
            4103: changes("docs-site", [FileChange(path: "guides/getting-started.md", added: 142, removed: 0, isUntracked: true), FileChange(path: "guides/deploy.md", added: 96, removed: 0, isUntracked: true)]),
            4106: changes("storefront", [FileChange(path: "src/checkout/session.ts", added: 9, removed: 3)]),
            4104: changes("storefront/.claude/worktrees/search", [FileChange(path: "src/search/SearchResults.tsx", added: 71, removed: 12), FileChange(path: "src/search/useSearch.ts", added: 17, removed: 0)]),
        ]
    }

    static let agentDiff = """
    diff --git a/src/checkout/session.ts b/src/checkout/session.ts
    index 3b1f0a2..9e4c7d1 100644
    --- a/src/checkout/session.ts
    +++ b/src/checkout/session.ts
    @@ -12,9 +12,14 @@ import { db } from "../db"
     export async function createSession(cart: Cart) {
    -  const id = crypto.randomUUID()
    -  await db.insert("sessions", { id, cart })
    +  const id = crypto.randomUUID()
    +  const expiresAt = Date.now() + SESSION_TTL
    +  await db.insert("checkout_sessions", { id, cartId: cart.id, expiresAt })
    +  return { id, expiresAt }
    +}
    +
    +export const SESSION_TTL = 30 * 60 * 1000
    diff --git a/package.json b/package.json
    index 77a1c2e..8d0b5f3 100644
    --- a/package.json
    +++ b/package.json
    @@ -8,7 +8,7 @@
         "dev": "next dev",
    -    "db:migrate": "drizzle-kit push",
    +    "db:migrate": "drizzle-kit migrate",
         "test": "vitest"
    diff --git a/db/migrations/0042_checkout_sessions.sql b/db/migrations/0042_checkout_sessions.sql
    new file (untracked)
    --- /dev/null
    +++ b/db/migrations/0042_checkout_sessions.sql
    @@ -0,0 +1,5 @@
    +CREATE TABLE checkout_sessions (
    +  id uuid PRIMARY KEY,
    +  cart_id uuid NOT NULL REFERENCES carts(id),
    +  expires_at timestamptz NOT NULL
    +);
    """
}
