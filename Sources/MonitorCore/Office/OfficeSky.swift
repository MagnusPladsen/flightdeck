import Foundation

/// The weather outside the office windows, from a WMO weather code.
public enum OfficeWeatherCondition: String, Sendable, CaseIterable {
    case clear, cloudy, fog, rain, snow, storm

    public init(weatherCode code: Int) {
        switch code {
        case 0, 1: self = .clear
        case 2, 3: self = .cloudy
        case 45, 48: self = .fog
        case 51...67, 80...82: self = .rain
        case 71...77, 85, 86: self = .snow
        case 95...99: self = .storm
        default: self = .cloudy
        }
    }

    public var title: String {
        switch self {
        case .clear: "clear"
        case .cloudy: "cloudy"
        case .fog: "fog"
        case .rain: "rain"
        case .snow: "snow"
        case .storm: "thunderstorm"
        }
    }

    public var isFalling: Bool { self == .rain || self == .snow || self == .storm }
}

/// How light it is outside: 1 in daylight, 0 at night, easing over twilight around sunrise and sunset.
public enum OfficeSky {
    static let twilight: TimeInterval = 45 * 60

    public static func daylight(at date: Date, sunrise: Date, sunset: Date) -> Double {
        let morning = ramp(date.timeIntervalSince(sunrise))
        let evening = ramp(sunset.timeIntervalSince(date))
        return min(morning, evening)
    }

    /// Sunrise and sunset at 7 and 19 local time, for when no weather is looked up.
    public static func typicalDay(around date: Date, calendar: Calendar = .current) -> (sunrise: Date, sunset: Date) {
        let start = calendar.startOfDay(for: date)
        return (start.addingTimeInterval(7 * 3600), start.addingTimeInterval(19 * 3600))
    }

    /// How warm the sky is: high just around sunrise and sunset.
    public static func sunsetGlow(at date: Date, sunrise: Date, sunset: Date) -> Double {
        let nearest = min(abs(date.timeIntervalSince(sunrise)), abs(date.timeIntervalSince(sunset)))
        return max(0, 1 - nearest / (twilight * 1.5))
    }

    private static func ramp(_ secondsPast: TimeInterval) -> Double {
        let linear = min(max((secondsPast + twilight) / (2 * twilight), 0), 1)
        return linear * linear * (3 - 2 * linear)
    }
}

/// The bits of Open-Meteo's answers the office needs.
public enum OpenMeteo {
    public struct Place: Sendable, Equatable {
        public var name: String
        public var latitude: Double
        public var longitude: Double
    }

    public struct Weather: Sendable, Equatable {
        public var condition: OfficeWeatherCondition
        public var sunrise: Date?
        public var sunset: Date?
    }

    public static func geocodingURL(city: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [URLQueryItem(name: "name", value: city), URLQueryItem(name: "count", value: "1")]
        return components?.url
    }

    public static func forecastURL(for place: Place) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)), URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "weather_code"), URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "timeformat", value: "unixtime"), URLQueryItem(name: "forecast_days", value: "1"), URLQueryItem(name: "timezone", value: "auto"),
        ]
        return components?.url
    }

    public static func place(from data: Data) -> Place? {
        struct Response: Decodable {
            struct Result: Decodable { var name: String; var country: String?; var latitude: Double; var longitude: Double }
            var results: [Result]?
        }
        guard let result = (try? JSONDecoder().decode(Response.self, from: data))?.results?.first else { return nil }
        let name = [result.name, result.country].compactMap { $0 }.joined(separator: ", ")
        return Place(name: name, latitude: result.latitude, longitude: result.longitude)
    }

    public static func weather(from data: Data) -> Weather? {
        struct Response: Decodable {
            struct Current: Decodable { var weather_code: Int }
            struct Daily: Decodable { var sunrise: [Double]; var sunset: [Double] }
            var current: Current
            var daily: Daily?
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        return Weather(condition: OfficeWeatherCondition(weatherCode: response.current.weather_code),
                       sunrise: response.daily?.sunrise.first.map(Date.init(timeIntervalSince1970:)),
                       sunset: response.daily?.sunset.first.map(Date.init(timeIntervalSince1970:)))
    }
}
