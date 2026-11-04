import SwiftUI

/// A colour palette for the whole app. Roles follow the sexy-claude theme format.
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let isDark: Bool
    let background: Color
    let foreground: Color
    let surface: Color
    let overlay: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
    let border: Color

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

    static let all: [Theme] = [cleanDark, cleanLight, tokyoNight, catppuccinMocha, dracula, oneDark, nord, gruvboxDark, monokaiPro, rosePine, kanagawa, solarizedDark]

    static func resolve(id: String, systemScheme: ColorScheme) -> Theme {
        if id == systemID { return systemScheme == .dark ? cleanDark : cleanLight }
        return all.first { $0.id == id } ?? cleanDark
    }

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
}

extension Color {
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
}
