import SwiftUI

/// The office's time of day and weather, and the achievement alerts.
struct OfficeSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        Section {
            Toggle("Office follows the time of day", isOn: $settings.officeFollowsTimeOfDay)
            Toggle("Show the weather in the office windows", isOn: $settings.officeWeatherEnabled)
            if settings.officeWeatherEnabled {
                TextField("City", text: $settings.officeWeatherCity, prompt: Text("e.g. Oslo"))
                    .onSubmit { store.officeWeather.refresh(city: settings.officeWeatherCity, force: true) }
                if let place = store.officeWeather.placeName {
                    Text("Weather for \(place): \(store.officeWeather.condition.title)").font(.caption).foregroundStyle(.secondary)
                } else if !settings.officeWeatherCity.isEmpty, store.officeWeather.didFail {
                    Text("Couldn't find that city.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle("Notify me when I unlock an achievement", isOn: $settings.achievementAlertsEnabled)
        } header: {
            Text("Office & achievements")
        } footer: {
            Text("The office windows show the sky outside: daylight, sunset and a starry night, with desk lamps on after dark. With the weather on, Flightdeck looks up the city you type on Open-Meteo every 30 minutes and shows rain, snow or clouds. Only the city name is sent.")
        }
    }
}
