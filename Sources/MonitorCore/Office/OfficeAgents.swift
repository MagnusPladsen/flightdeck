import Foundation

/// How an agent looks in the office.
public enum OfficePose: Sendable, Hashable {
    /// Working: at the desk, typing.
    case typing
    /// Your turn: leaning back.
    case relaxed
    /// Needs approval: standing, tapping a foot.
    case impatient
    /// Possibly stuck: standing, scratching its head.
    case puzzled
    /// Idle: scrolling its phone.
    case phone

    public init(state: AgentState) {
        switch state {
        case .working: self = .typing
        case .yourTurn: self = .relaxed
        case .needsApproval: self = .impatient
        case .possiblyStuck: self = .puzzled
        case .idle: self = .phone
        }
    }

    public var isStanding: Bool { self == .impatient || self == .puzzled }
}

/// What idle agents think about while scrolling short videos.
public enum IdleThoughts {
    public static let secondsPerLine = 8.0

    public static let lines = [
        "one more video…",
        "a cat learned to open doors?!",
        "why am I watching a man fix a lawnmower",
        "5 desk stretches. doing 0 of them",
        "this soup recipe has 40 steps",
        "the algorithm knows me too well",
        "a dog skateboarding. again. yes.",
        "how is it 3 o'clock",
        "tiny house tour #12",
        "someone ranked every sandwich",
        "wait, go back, the duck",
        "satisfying pressure washing…",
        "a raccoon stole a whole pizza",
        "learning to juggle (watching only)",
    ]

    /// Each agent starts at its own line and moves on every few seconds.
    public static func line(for pid: Int32, at date: Date) -> String {
        let step = Int(date.timeIntervalSinceReferenceDate / secondsPerLine)
        let index = (Int(pid.magnitude) + step) % lines.count
        return lines[index]
    }
}

/// Agents that get a "Needs you" post: those paused for approval and those that look stuck.
public enum NeedsYouFeed {
    public static func needsPost(_ state: AgentState) -> Bool {
        state == .needsApproval || state == .possiblyStuck
    }

    /// Most recently active first.
    public static func agents(in agents: [AgentSession]) -> [AgentSession] {
        agents.filter { needsPost($0.state) }.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }
}
