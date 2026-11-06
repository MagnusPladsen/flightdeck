import MonitorCore
import SwiftUI

/// One colour of a theme the user can replace with their own.
enum ThemeColorRole: String, CaseIterable, Identifiable {
    case background, foreground, surface, overlay, border, primary, secondary, accent, success, warning, error, info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .background: "Background"
        case .foreground: "Text"
        case .surface: "Cards"
        case .overlay: "Selected and raised"
        case .border: "Lines and borders"
        case .primary: "Buttons and links"
        case .secondary: "Secondary"
        case .accent: "Accent"
        case .success: "Working and healthy"
        case .warning: "Needs you"
        case .error: "Errors"
        case .info: "Info and ports"
        }
    }
}

extension Theme {
    subscript(role: ThemeColorRole) -> Color {
        get {
            switch role {
            case .background: background
            case .foreground: foreground
            case .surface: surface
            case .overlay: overlay
            case .border: border
            case .primary: primary
            case .secondary: secondary
            case .accent: accent
            case .success: success
            case .warning: warning
            case .error: error
            case .info: info
            }
        }
        set {
            switch role {
            case .background: background = newValue
            case .foreground: foreground = newValue
            case .surface: surface = newValue
            case .overlay: overlay = newValue
            case .border: border = newValue
            case .primary: primary = newValue
            case .secondary: secondary = newValue
            case .accent: accent = newValue
            case .success: success = newValue
            case .warning: warning = newValue
            case .error: error = newValue
            case .info: info = newValue
            }
        }
    }

    /// The theme with the user's own colours, keyed by role raw value as "#RRGGBB", laid over it.
    func applying(_ customColors: [String: String]) -> Theme {
        var theme = self
        for role in ThemeColorRole.allCases {
            if let color = customColors[role.rawValue].flatMap(Color.init(hexString:)) { theme[role] = color }
        }
        return theme
    }

    var palette: CustomThemePalette {
        CustomThemePalette(name: name, colors: Dictionary(uniqueKeysWithValues: ThemeColorRole.allCases.map { ($0.rawValue, self[$0].hexString) }))
    }

    /// This built-in theme with a custom theme's name, id and colours.
    func customized(as custom: CustomTheme) -> Theme {
        var theme = applying(custom.colors)
        theme.id = custom.id
        theme.name = custom.name
        return theme
    }
}
