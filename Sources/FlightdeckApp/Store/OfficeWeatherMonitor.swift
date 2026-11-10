import Foundation
import MonitorCore
import Observation

/// Looks up the weather and the sun times for the city in Settings on Open-Meteo, at most every 30 minutes.
@MainActor
@Observable
final class OfficeWeatherMonitor {
    private static let refreshInterval: TimeInterval = 30 * 60

    private(set) var placeName: String?
    private(set) var condition: OfficeWeatherCondition = .clear
    private(set) var sunrise: Date?
    private(set) var sunset: Date?
    private(set) var didFail = false
    @ObservationIgnored private var place: OpenMeteo.Place?
    @ObservationIgnored private var placeCity: String?
    @ObservationIgnored private var fetchedAt: Date?
    @ObservationIgnored private var isFetching = false

    func refresh(city: String, force: Bool = false) {
        let city = city.trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty, !isFetching else { return }
        if !force, placeCity == city, let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.refreshInterval { return }
        isFetching = true
        Task {
            defer { isFetching = false }
            await fetch(city: city)
        }
    }

    func showDemo(_ condition: OfficeWeatherCondition) {
        placeName = "Demo"
        self.condition = condition
    }

    private func fetch(city: String) async {
        fetchedAt = Date()
        if placeCity != city {
            place = await Self.data(from: OpenMeteo.geocodingURL(city: city)).flatMap(OpenMeteo.place(from:))
            placeCity = city
        }
        guard let place, let weather = await Self.data(from: OpenMeteo.forecastURL(for: place)).flatMap(OpenMeteo.weather(from:)) else {
            didFail = true
            placeName = nil
            return
        }
        didFail = false
        placeName = place.name
        condition = weather.condition
        sunrise = weather.sunrise
        sunset = weather.sunset
    }

    private nonisolated static func data(from url: URL?) async -> Data? {
        guard let url else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }
}
