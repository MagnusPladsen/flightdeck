import MonitorCore
import SwiftUI

/// The quiet hours schedule, what happens to alerts during it, and any pause set from the bell.
struct QuietHoursSettings: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        @Bindable var settings = store.settings
        Section {
            Toggle("Keep alerts quiet on a schedule", isOn: $settings.quietHours.isEnabled)
            Group {
                DatePicker("From", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                LabeledContent("On") { weekdayToggles }
            }
            .disabled(!settings.quietHours.isEnabled)
            Picker("Alerts while quiet", selection: $settings.quietAlertHandling) {
                Text("Send one summary afterwards").tag(QuietAlertHandling.summarize)
                Text("Don't send them").tag(QuietAlertHandling.drop)
            }
            pauseRow
        } header: {
            Text("Quiet hours")
        } footer: {
            Text("A schedule that ends before it starts runs past midnight. Pause alerts for a while from the bell in the menu bar panel. During a macOS Focus, macOS itself holds Flightdeck's banners unless you allow Flightdeck in that Focus.")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var pauseRow: some View {
        if let pausedUntil = store.settings.alertsPausedUntil, store.settings.isAlertPaused() {
            LabeledContent("Paused \(AlertPauseText.until(pausedUntil))") {
                Button("Resume") { store.resumeAlerts() }
            }
        }
    }

    private var weekdayToggles: some View {
        HStack(spacing: 4) {
            ForEach(Self.orderedWeekdays, id: \.self) { weekday in
                weekdayChip(weekday)
            }
        }
    }

    /// Weekday numbers starting from the user's first day of the week.
    private static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private func weekdayChip(_ weekday: Int) -> some View {
        let isSelected = store.settings.quietHours.weekdays.contains(weekday)
        return Button {
            if isSelected { store.settings.quietHours.weekdays.remove(weekday) } else { store.settings.quietHours.weekdays.insert(weekday) }
        } label: {
            Text(Calendar.current.shortWeekdaySymbols[weekday - 1])
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 36, height: 22)
                .foregroundStyle(isSelected ? theme.background : theme.muted)
                .background(isSelected ? theme.primary : theme.overlay, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Shows minutes after midnight as a time today, which is what `DatePicker` edits.
    private func timeBinding(_ keyPath: WritableKeyPath<QuietHours, Int>) -> Binding<Date> {
        let calendar = Calendar.current
        return Binding(
            get: {
                let minutes = store.settings.quietHours[keyPath: keyPath]
                return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                store.settings.quietHours[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

/// "until 14:30" or "until 08:00 tomorrow", for a pause set from the bell.
enum AlertPauseText {
    static func until(_ date: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "until \(time)" }
        if calendar.isDateInTomorrow(date) { return "until \(time) tomorrow" }
        return "until \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
