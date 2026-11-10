import Foundation
import Testing
@testable import MonitorCore

struct OfficeSkyTests {
    private let sunrise = Date(timeIntervalSince1970: 1_000_000)
    private var sunset: Date { sunrise.addingTimeInterval(10 * 3600) }

    @Test func daylightIsFullAtNoonAndNoneAtMidnight() {
        #expect(OfficeSky.daylight(at: sunrise.addingTimeInterval(5 * 3600), sunrise: sunrise, sunset: sunset) == 1)
        #expect(OfficeSky.daylight(at: sunset.addingTimeInterval(4 * 3600), sunrise: sunrise, sunset: sunset) == 0)
        #expect(OfficeSky.daylight(at: sunrise, sunrise: sunrise, sunset: sunset) == 0.5)
    }

    @Test func glowPeaksAtSunset() {
        #expect(OfficeSky.sunsetGlow(at: sunset, sunrise: sunrise, sunset: sunset) == 1)
        #expect(OfficeSky.sunsetGlow(at: sunrise.addingTimeInterval(5 * 3600), sunrise: sunrise, sunset: sunset) == 0)
    }

    @Test func mapsWeatherCodes() {
        #expect(OfficeWeatherCondition(weatherCode: 0) == .clear)
        #expect(OfficeWeatherCondition(weatherCode: 61) == .rain)
        #expect(OfficeWeatherCondition(weatherCode: 73) == .snow)
        #expect(OfficeWeatherCondition(weatherCode: 95) == .storm)
    }

    @Test func parsesOpenMeteoAnswers() {
        let place = OpenMeteo.place(from: Data(#"{"results":[{"name":"Oslo","country":"Norway","latitude":59.9,"longitude":10.7}]}"#.utf8))
        #expect(place == OpenMeteo.Place(name: "Oslo, Norway", latitude: 59.9, longitude: 10.7))
        let weather = OpenMeteo.weather(from: Data(#"{"current":{"weather_code":63},"daily":{"sunrise":[1000],"sunset":[2000]}}"#.utf8))
        #expect(weather == OpenMeteo.Weather(condition: .rain, sunrise: Date(timeIntervalSince1970: 1000), sunset: Date(timeIntervalSince1970: 2000)))
        #expect(OpenMeteo.place(from: Data(#"{}"#.utf8)) == nil)
    }
}
