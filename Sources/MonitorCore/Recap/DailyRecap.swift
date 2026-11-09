import Foundation

/// One project's line in a day's recap.
public struct RecapLine: Sendable, Hashable, Identifiable {
    public var id: String { project }
    public var project: String
    public var workingSeconds: TimeInterval
    public var waitingSeconds: TimeInterval
    public var longestWaitSeconds: TimeInterval
    public var turns: Int
    public var sessions: Int
}

/// What the agents did on one day: totals and a line per project, busiest first.
public struct DailyRecap: Sendable, Hashable {
    public var day: Date
    public var projects: [RecapLine]

    public init(day: Date, projects: [RecapLine]) {
        self.day = day
        self.projects = projects
    }

    public init(_ day: RecapDay) {
        let lines = day.projects.map { name, tally in
            RecapLine(project: name, workingSeconds: tally.workingSeconds, waitingSeconds: tally.waitingSeconds,
                      longestWaitSeconds: tally.longestWaitSeconds, turns: tally.turns, sessions: tally.sessionIDs.count)
        }
        self.init(day: day.day, projects: lines.sorted { ($0.workingSeconds, $0.waitingSeconds, $1.project) > ($1.workingSeconds, $1.waitingSeconds, $0.project) })
    }

    public var workingSeconds: TimeInterval { projects.map(\.workingSeconds).reduce(0, +) }
    public var waitingSeconds: TimeInterval { projects.map(\.waitingSeconds).reduce(0, +) }
    public var longestWaitSeconds: TimeInterval { projects.map(\.longestWaitSeconds).max() ?? 0 }
    public var turns: Int { projects.map(\.turns).reduce(0, +) }
    public var sessions: Int { projects.map(\.sessions).reduce(0, +) }
    public var isEmpty: Bool { workingSeconds == 0 && waitingSeconds == 0 && turns == 0 }
}

extension RecapLedger {
    /// The recap for the day `daysAgo` before `now`; empty when nothing was recorded.
    public func recap(daysAgo: Int = 0, now: Date = Date(), calendar: Calendar = .current) -> DailyRecap {
        let today = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return days.first { $0.day == day }.map(DailyRecap.init) ?? DailyRecap(day: day, projects: [])
    }

    /// The latest finished day with agent activity that has not been summarised yet, for the optional
    /// next-day notification.
    public func dayToAnnounce(lastAnnounced: Date?, now: Date = Date(), calendar: Calendar = .current) -> DailyRecap? {
        let today = calendar.startOfDay(for: now)
        guard let day = days.first(where: { $0.day < today }) else { return nil }
        guard lastAnnounced.map({ day.day > $0 }) ?? true else { return nil }
        let recap = DailyRecap(day)
        return recap.isEmpty ? nil : recap
    }

    public static func load(from url: URL) -> RecapLedger {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(RecapLedger.self, from: $0) } ?? RecapLedger()
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
