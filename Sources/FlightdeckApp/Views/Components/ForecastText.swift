import MonitorCore
import SwiftUI

/// "Limit at 15:40" in the warning colour, or a muted "Lasts until reset". Callers set the font.
struct ForecastText: View {
    @Environment(\.theme) private var theme
    var forecast: LimitForecast
    var isUppercased = false

    var body: some View {
        let text = Formatters.forecast(forecast)
        Text(isUppercased ? text.uppercased() : text)
            .foregroundStyle(isLimitReached ? theme.warning : theme.muted)
            .lineLimit(1)
            .help(Formatters.forecastSentence(forecast))
    }

    private var isLimitReached: Bool {
        if case .reachesLimit = forecast { return true }
        return false
    }
}
