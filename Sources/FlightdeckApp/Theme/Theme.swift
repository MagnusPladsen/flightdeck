import AppKit
import SwiftUI

/// A colour palette for the whole app. Roles follow the sexy-claude theme format.
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let isDark: Bool
    var background: Color
    var foreground: Color
    var surface: Color
    var overlay: Color
    var primary: Color
    var secondary: Color
    var accent: Color
    var success: Color
    var warning: Color
    var error: Color
    var info: Color
    var border: Color

    init(id: String, name: String, isDark: Bool, background: UInt32, foreground: UInt32, surface: UInt32, overlay: UInt32, primary: UInt32, secondary: UInt32, accent: UInt32, success: UInt32, warning: UInt32, error: UInt32, info: UInt32, border: UInt32) {
        self.id = id
        self.name = name
        self.isDark = isDark
        self.background = Color(hex: background)
        self.foreground = Color(hex: foreground)
        self.surface = Color(hex: surface)
        self.overlay = Color(hex: overlay)
        self.primary = Color(hex: primary)
        self.secondary = Color(hex: secondary)
        self.accent = Color(hex: accent)
        self.success = Color(hex: success)
        self.warning = Color(hex: warning)
        self.error = Color(hex: error)
        self.info = Color(hex: info)
        self.border = Color(hex: border)
    }
}

extension Theme {
    /// Pseudo theme id: Clean Dark or Clean Light, following the macOS appearance.
    static let systemID = "system"

    static let all: [Theme] = [ignition, cleanDark, cleanLight, macOS, terminal, glass, bento, cockpit, editorial, neon, mission, timeline, tokyoNight, catppuccinMocha, dracula, oneDark, nord, gruvboxDark, monokaiPro, rosePine, kanagawa, solarizedDark]

    static func resolve(id: String, systemScheme: ColorScheme) -> Theme {
        if id == systemID { return systemScheme == .dark ? cleanDark : cleanLight }
        return all.first { $0.id == id } ?? cleanDark
    }

    /// The default: near-black, hairline borders, orange for anything that needs you.
    static let ignition = Theme(
        id: "ignition", name: "Ignition", isDark: true,
        background: 0x000000,
        foreground: 0xe7e9ea,
        surface: 0x16181c,
        overlay: 0x202327,
        primary: 0x1d9bf0,
        secondary: 0x7856ff,
        accent: 0xff7a1a,
        success: 0x00ba7c,
        warning: 0xff7a1a,
        error: 0xf4212e,
        info: 0x1d9bf0,
        border: 0x2f3336
    )

    static let cleanDark = Theme(
        id: "clean-dark", name: "Clean Dark", isDark: true,
        background: 0x111113,
        foreground: 0xededf0,
        surface: 0x1b1b1f,
        overlay: 0x2a2a30,
        primary: 0x6ea8fe,
        secondary: 0xa78bfa,
        accent: 0x22d3ee,
        success: 0x4ade80,
        warning: 0xfacc15,
        error: 0xf87171,
        info: 0x38bdf8,
        border: 0x2e2e34
    )

    static let cleanLight = Theme(
        id: "clean-light", name: "Clean Light", isDark: false,
        background: 0xf7f7f8,
        foreground: 0x18181b,
        surface: 0xffffff,
        overlay: 0xeeeef1,
        primary: 0x2563eb,
        secondary: 0x7c3aed,
        accent: 0x0891b2,
        success: 0x16a34a,
        warning: 0xca8a04,
        error: 0xdc2626,
        info: 0x0284c7,
        border: 0xe2e2e6
    )

    // Palettes below come from github.com/MagnusPladsen/sexy-claude-themes.

    /// Credit: enkia/tokyo-night-vscode-theme
    static let tokyoNight = Theme(
        id: "tokyo-night", name: "Tokyo Night", isDark: true,
        background: 0x1a1b26,
        foreground: 0xc0caf5,
        surface: 0x24283b,
        overlay: 0x414868,
        primary: 0x7aa2f7,
        secondary: 0xbb9af7,
        accent: 0x7dcfff,
        success: 0x9ece6a,
        warning: 0xe0af68,
        error: 0xf7768e,
        info: 0x2ac3de,
        border: 0x3b4261
    )

    static let catppuccinMocha = Theme(
        id: "catppuccin-mocha", name: "Catppuccin Mocha", isDark: true,
        background: 0x1e1e2e,
        foreground: 0xcdd6f4,
        surface: 0x313244,
        overlay: 0x45475a,
        primary: 0xcba6f7,
        secondary: 0x89b4fa,
        accent: 0xf5c2e7,
        success: 0xa6e3a1,
        warning: 0xf9e2af,
        error: 0xf38ba8,
        info: 0x89dceb,
        border: 0x585b70
    )

    /// Credit: dracula/visual-studio-code
    static let dracula = Theme(
        id: "dracula", name: "Dracula", isDark: true,
        background: 0x282a36,
        foreground: 0xf8f8f2,
        surface: 0x343746,
        overlay: 0x44475a,
        primary: 0xbd93f9,
        secondary: 0x8be9fd,
        accent: 0xff79c6,
        success: 0x50fa7b,
        warning: 0xf1fa8c,
        error: 0xff5555,
        info: 0x8be9fd,
        border: 0x6272a4
    )

    /// Credit: Binaryify/OneDark-Pro
    static let oneDark = Theme(
        id: "one-dark", name: "One Dark", isDark: true,
        background: 0x282c34,
        foreground: 0xabb2bf,
        surface: 0x21252b,
        overlay: 0x3e4451,
        primary: 0x61afef,
        secondary: 0xc678dd,
        accent: 0xe06c75,
        success: 0x98c379,
        warning: 0xe5c07b,
        error: 0xe06c75,
        info: 0x56b6c2,
        border: 0x3b4048
    )

    /// Credit: nordtheme/visual-studio-code
    static let nord = Theme(
        id: "nord", name: "Nord", isDark: true,
        background: 0x2e3440,
        foreground: 0xd8dee9,
        surface: 0x3b4252,
        overlay: 0x434c5e,
        primary: 0x88c0d0,
        secondary: 0x81a1c1,
        accent: 0xb48ead,
        success: 0xa3be8c,
        warning: 0xebcb8b,
        error: 0xbf616a,
        info: 0x5e81ac,
        border: 0x4c566a
    )

    /// Credit: morhetz/gruvbox
    static let gruvboxDark = Theme(
        id: "gruvbox-dark", name: "Gruvbox Dark", isDark: true,
        background: 0x282828,
        foreground: 0xebdbb2,
        surface: 0x3c3836,
        overlay: 0x504945,
        primary: 0xfabd2f,
        secondary: 0x83a598,
        accent: 0xd3869b,
        success: 0xb8bb26,
        warning: 0xfabd2f,
        error: 0xfb4934,
        info: 0x83a598,
        border: 0x665c54
    )

    /// Credit: monokai/monokai-pro-vscode
    static let monokaiPro = Theme(
        id: "monokai-pro", name: "Monokai Pro", isDark: true,
        background: 0x222222,
        foreground: 0xf7f1ff,
        surface: 0x2d2a2e,
        overlay: 0x403e41,
        primary: 0xfc9867,
        secondary: 0xab9df2,
        accent: 0xff6188,
        success: 0xa9dc76,
        warning: 0xffd866,
        error: 0xff6188,
        info: 0x78dce8,
        border: 0x5b595c
    )

    /// Credit: rose-pine/vscode
    static let rosePine = Theme(
        id: "rose-pine", name: "Rosé Pine", isDark: true,
        background: 0x191724,
        foreground: 0xe0def4,
        surface: 0x1f1d2e,
        overlay: 0x26233a,
        primary: 0xc4a7e7,
        secondary: 0x9ccfd8,
        accent: 0xebbcba,
        success: 0x31748f,
        warning: 0xf6c177,
        error: 0xeb6f92,
        info: 0x9ccfd8,
        border: 0x403d52
    )

    /// Credit: rebelot/kanagawa.nvim
    static let kanagawa = Theme(
        id: "kanagawa", name: "Kanagawa", isDark: true,
        background: 0x1f1f28,
        foreground: 0xdcd7ba,
        surface: 0x2a2a37,
        overlay: 0x363646,
        primary: 0x7e9cd8,
        secondary: 0x957fb8,
        accent: 0xd27e99,
        success: 0x76946a,
        warning: 0xe6c384,
        error: 0xc34043,
        info: 0x7fb4ca,
        border: 0x54546d
    )

    /// Credit: Ethan Schoonover
    static let solarizedDark = Theme(
        id: "solarized-dark", name: "Solarized Dark", isDark: true,
        background: 0x002b36,
        foreground: 0x839496,
        surface: 0x073642,
        overlay: 0x094856,
        primary: 0x268bd2,
        secondary: 0x2aa198,
        accent: 0xd33682,
        success: 0x859900,
        warning: 0xb58900,
        error: 0xdc322f,
        info: 0x6c71c4,
        border: 0x586e75
    )

    /// Soft graphite with system blue, from the macOS layout.
    static let macOS = Theme(
        id: "macos", name: "macOS", isDark: true,
        background: 0x111113,
        foreground: 0xededf0,
        surface: 0x1b1b1f,
        overlay: 0x23232a,
        primary: 0x6ea8fe,
        secondary: 0xa1a1aa,
        accent: 0x38bdf8,
        success: 0x4ade80,
        warning: 0xfacc15,
        error: 0xf87171,
        info: 0x38bdf8,
        border: 0x2e2e34
    )

    /// Phosphor green on near-black, from the Terminal layout.
    static let terminal = Theme(
        id: "terminal", name: "Terminal", isDark: true,
        background: 0x0b0e0b,
        foreground: 0xc9d1c9,
        surface: 0x111611,
        overlay: 0x263026,
        primary: 0x7ee787,
        secondary: 0x6b7a6b,
        accent: 0xd2a8ff,
        success: 0x7ee787,
        warning: 0xe3b341,
        error: 0xff7b72,
        info: 0x79c0ff,
        border: 0x2d3a2d
    )

    /// Deep violet night with lilac light, from the Glass layout.
    static let glass = Theme(
        id: "glass", name: "Glass", isDark: true,
        background: 0x0d0b14,
        foreground: 0xf4f2fa,
        surface: 0x1d1b25,
        overlay: 0x3a3842,
        primary: 0xc4b5fd,
        secondary: 0xb9b6c2,
        accent: 0xa78bfa,
        success: 0x34d399,
        warning: 0xfbbf24,
        error: 0xfb7185,
        info: 0x38bdf8,
        border: 0x33313b
    )

    /// Warm black with lime, from the Bento layout.
    static let bento = Theme(
        id: "bento", name: "Bento", isDark: true,
        background: 0x0e0e0c,
        foreground: 0xf5f5f0,
        surface: 0x1c1c19,
        overlay: 0x262622,
        primary: 0xd9f99d,
        secondary: 0xa8a89e,
        accent: 0x7dd3fc,
        success: 0xd9f99d,
        warning: 0xfcd34d,
        error: 0xfca5a5,
        info: 0x7dd3fc,
        border: 0x262622
    )

    /// Amber readouts on black, from the Cockpit layout.
    static let cockpit = Theme(
        id: "cockpit", name: "Cockpit", isDark: true,
        background: 0x0a0908,
        foreground: 0xe8dcc8,
        surface: 0x17130c,
        overlay: 0x221c12,
        primary: 0xffb000,
        secondary: 0xa8916a,
        accent: 0xffb000,
        success: 0x7bd88f,
        warning: 0xffb000,
        error: 0xff5f3c,
        info: 0xffd166,
        border: 0x3a2f1c
    )

    /// Newsprint cream with rust ink, from the Editorial layout.
    static let editorial = Theme(
        id: "editorial", name: "Editorial", isDark: false,
        background: 0xf4f1ea,
        foreground: 0x161513,
        surface: 0xebe6da,
        overlay: 0xdcd6c8,
        primary: 0xc2410c,
        secondary: 0x5f5a50,
        accent: 0xc2410c,
        success: 0x15803d,
        warning: 0xc2410c,
        error: 0xb91c1c,
        info: 0x1d4ed8,
        border: 0xcfc9bc
    )

    /// Hot pink and cyan on indigo, from the Neon layout.
    static let neon = Theme(
        id: "neon", name: "Neon", isDark: true,
        background: 0x0b0820,
        foreground: 0xe9e6ff,
        surface: 0x140e30,
        overlay: 0x241b52,
        primary: 0xff2e97,
        secondary: 0xb9b3e6,
        accent: 0x22d3ee,
        success: 0x39ff88,
        warning: 0xfde047,
        error: 0xff2e97,
        info: 0x22d3ee,
        border: 0x3b2d7a
    )

    /// White on deep space, from the Mission control layout.
    static let mission = Theme(
        id: "mission", name: "Mission", isDark: true,
        background: 0x05070b,
        foreground: 0xe6ecf5,
        surface: 0x0b0f16,
        overlay: 0x111827,
        primary: 0xffffff,
        secondary: 0x7d8aa0,
        accent: 0xffffff,
        success: 0x34d399,
        warning: 0xfbbf24,
        error: 0xf87171,
        info: 0x7dd3fc,
        border: 0x1c2433
    )

    /// Black with blue links and amber alerts, from the Timeline layout.
    static let timeline = Theme(
        id: "timeline", name: "Timeline", isDark: true,
        background: 0x000000,
        foreground: 0xe7e9ea,
        surface: 0x16181c,
        overlay: 0x202327,
        primary: 0x1d9bf0,
        secondary: 0x71767b,
        accent: 0xffad1f,
        success: 0x00ba7c,
        warning: 0xffad1f,
        error: 0xf4212e,
        info: 0x1d9bf0,
        border: 0x2f3336
    )
}

extension Color {
    /// "#RRGGBB" or "RRGGBB"; nil for anything else.
    init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(hex: value)
    }

    /// "#RRGGBB" in sRGB, for saving a colour the user picked.
    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let channels = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", min(max($0, 0), 255)) }.joined()
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

extension EnvironmentValues {
    @Entry var theme: Theme = .cleanDark
    @Entry var dashboardLayout: DashboardLayout = .ignition
}
