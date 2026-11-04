import SwiftUI

/// Large time and date, readable from across the room. Ticks once a second.
struct ClockSection: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 120, weight: .light).monospacedDigit())
                    .tracking(-3.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
