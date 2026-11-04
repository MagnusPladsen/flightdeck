import SwiftUI

/// Applies the chosen theme to a window's root view: palette, colour scheme, tint and text colour.
struct ThemedRoot: ViewModifier {
    var settings: AppSettings
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let theme = Theme.resolve(id: settings.themeID, systemScheme: systemScheme)
        content
            .environment(\.theme, theme)
            .tint(theme.primary)
            .foregroundStyle(theme.foreground)
            .background(theme.background)
            .preferredColorScheme(settings.themeID == Theme.systemID ? nil : (theme.isDark ? .dark : .light))
    }
}

/// Swaps the system background of List, Form and Table for the theme's.
struct ThemedScrollBackground: ViewModifier {
    @Environment(\.theme) private var theme
    var useSurface = false

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(useSurface ? theme.surface : theme.background)
    }
}

extension View {
    func themedRoot(_ settings: AppSettings) -> some View {
        modifier(ThemedRoot(settings: settings))
    }

    func themedScrollBackground(useSurface: Bool = false) -> some View {
        modifier(ThemedScrollBackground(useSurface: useSurface))
    }
}
