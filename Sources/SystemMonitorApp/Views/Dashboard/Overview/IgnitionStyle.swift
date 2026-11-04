import MonitorCore
import SwiftUI

extension Theme {
    var muted: Color { foreground.opacity(0.5) }
    /// Colour of everything that is waiting on the user.
    var attention: Color { AgentState.yourTurn.color(in: self) }
}

/// Rounded pill button: solid for the main action, outlined otherwise.
struct PillButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    var isProminent = false
    var size: CGFloat = 13

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .bold))
            .padding(.horizontal, size * 1.4)
            .padding(.vertical, size * 0.62)
            .foregroundStyle(isProminent ? theme.background : theme.foreground)
            .background(isProminent ? theme.foreground : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isProminent ? .clear : theme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// Small text link such as "See all 5 →".
struct SeeAllLink: View {
    @Environment(\.theme) private var theme
    var title: String
    var color: Color?
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color ?? theme.muted)
    }
}

/// One-pixel line in the theme's border colour.
struct Hairline: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle().fill(theme.border).frame(height: 1)
    }
}

/// Checkbox list used by the Customize popovers.
struct OptionChecklist<Option: Identifiable>: View {
    var title: String
    var options: [Option]
    var label: (Option) -> String
    var isOn: (Option) -> Bool
    var setOn: (Option, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(options) { option in
                Toggle(label(option), isOn: Binding(get: { isOn(option) }, set: { setOn(option, $0) }))
            }
        }
        .toggleStyle(.checkbox)
    }
}
