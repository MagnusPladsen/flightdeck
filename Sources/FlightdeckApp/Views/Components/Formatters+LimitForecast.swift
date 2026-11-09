import Foundation
import MonitorCore

extension Formatters {
    static func forecast(_ forecast: LimitForecast, now: Date = Date()) -> String {
        switch forecast {
        case .lastsUntilReset: "Lasts until reset"
        case .reachesLimit(let date): "Limit at \(clockTime(date, now: now))"
        }
    }

    static func forecastSentence(_ forecast: LimitForecast, now: Date = Date()) -> String {
        switch forecast {
        case .lastsUntilReset: "At this pace it lasts until reset"
        case .reachesLimit(let date): "At this pace: limit at \(clockTime(date, now: now))"
        }
    }

    private static func clockTime(_ date: Date, now: Date) -> String {
        let isToday = Calendar.current.isDate(date, inSameDayAs: now)
        return isToday ? date.formatted(date: .omitted, time: .shortened) : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
