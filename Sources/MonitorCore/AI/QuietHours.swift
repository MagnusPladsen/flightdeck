import Foundation

/// A weekly schedule of hours when alerts stay quiet, such as 22:00–07:00 on weekdays.
/// A window that ends at or before its start crosses midnight and belongs to the day it starts on,
/// so Friday 22:00–07:00 keeps Saturday morning quiet too. Equal start and end mean the whole day.
public struct QuietHours: Codable, Equatable, Sendable {
    public static let minutesPerDay = 24 * 60

    public var isEnabled: Bool
    /// Minutes after midnight.
    public var startMinute: Int
    /// Minutes after midnight.
    public var endMinute: Int
    /// `Calendar` weekday numbers, 1 is Sunday.
    public var weekdays: Set<Int>

    public init(isEnabled: Bool = false, startMinute: Int = 22 * 60, endMinute: Int = 7 * 60, weekdays: Set<Int> = Set(1...7)) {
        self.isEnabled = isEnabled
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    public var crossesMidnight: Bool { endMinute <= startMinute }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }
        let minuteOfDay = hour * 60 + minute
        if !crossesMidnight { return weekdays.contains(weekday) && minuteOfDay >= startMinute && minuteOfDay < endMinute }
        let startedToday = weekdays.contains(weekday) && minuteOfDay >= startMinute
        let startedYesterday = weekdays.contains(Self.weekday(before: weekday)) && minuteOfDay < endMinute
        return startedToday || startedYesterday
    }

    private static func weekday(before weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }
}

/// What happens to alerts that arrive while it's quiet.
public enum QuietAlertHandling: String, CaseIterable, Codable, Sendable {
    /// Hold them and post one summary when the quiet period ends.
    case summarize
    /// Throw them away.
    case drop
}

/// The ways to pause alerts from the menu bar.
public enum AlertPause {
    public static let tomorrowMorningHour = 8

    public static func forOneHour(from now: Date) -> Date {
        now.addingTimeInterval(60 * 60)
    }

    /// 08:00 on the next calendar day.
    public static func untilTomorrow(from now: Date, calendar: Calendar = .current) -> Date {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: tomorrowMorningHour, minute: 0, second: 0, of: startOfTomorrow) ?? startOfTomorrow
    }

    public static func isPaused(until pausedUntil: Date?, at now: Date) -> Bool {
        pausedUntil.map { now < $0 } ?? false
    }
}

/// The alerts to post on one poll: each on its own, and those held through a quiet period, as one summary.
public struct AlertDelivery: Equatable, Sendable {
    public var individual: [AgentSession]
    public var summary: [AgentSession]

    public init(individual: [AgentSession], summary: [AgentSession]) {
        self.individual = individual
        self.summary = summary
    }

    public static let none = AlertDelivery(individual: [], summary: [])
}

/// Holds alerts back while it's quiet and releases them as a summary once it isn't.
public struct AlertBatcher: Sendable {
    public private(set) var held: [AgentSession] = []

    public init() {}

    public mutating func deliver(_ newAlerts: [AgentSession], current: [AgentSession], isQuiet: Bool, handling: QuietAlertHandling) -> AlertDelivery {
        if isQuiet {
            handling == .summarize ? hold(newAlerts) : discard()
            return .none
        }
        let summary = flush(stillWaiting: current)
        let summarizedFolders = Set(summary.map(\.workingDirectory))
        return AlertDelivery(individual: newAlerts.filter { !summarizedFolders.contains($0.workingDirectory) }, summary: summary)
    }

    public mutating func discard() {
        held = []
    }

    /// Keeps the latest alert per folder.
    private mutating func hold(_ alerts: [AgentSession]) {
        let folders = Set(alerts.map(\.workingDirectory))
        held = held.filter { !folders.contains($0.workingDirectory) } + alerts
    }

    /// The held alerts whose folder still has an agent waiting, since the rest no longer need you.
    private mutating func flush(stillWaiting current: [AgentSession]) -> [AgentSession] {
        let waitingFolders = Set(current.filter { AgentAlerts.waitingStates.contains($0.state) }.map(\.workingDirectory))
        defer { held = [] }
        return held.filter { waitingFolders.contains($0.workingDirectory) }
    }
}
