import Foundation

/// A built-in theme's name and colours, keyed by role raw value as "#RRGGBB".
public struct CustomThemePalette: Sendable {
    public var name: String
    public var colors: [String: String]

    public init(name: String, colors: [String: String]) {
        self.name = name
        self.colors = colors
    }
}

/// A user-made theme: a copy of a built-in theme whose colours the user can change.
/// Built-in themes themselves are read-only.
public struct CustomTheme: Codable, Identifiable, Hashable, Sendable {
    public static let idPrefix = "custom-"

    public let id: String
    public var name: String
    /// The built-in theme it was copied from; gives light or dark and the colours to reset to.
    public let baseThemeID: String
    public var colors: [String: String]

    public init(id: String = CustomTheme.idPrefix + UUID().uuidString, name: String, baseThemeID: String, colors: [String: String]) {
        self.id = id
        self.name = name
        self.baseThemeID = baseThemeID
        self.colors = colors
    }

    public static func copy(of baseThemeID: String, palette: CustomThemePalette, existingNames: [String]) -> CustomTheme {
        CustomTheme(name: uniqueName("\(palette.name) copy", existing: existingNames), baseThemeID: baseThemeID, colors: palette.colors)
    }

    /// "Nord copy", then "Nord copy 2", "Nord copy 3" when taken.
    public static func uniqueName(_ wanted: String, existing: [String]) -> String {
        guard existing.contains(wanted) else { return wanted }
        var number = 2
        while existing.contains("\(wanted) \(number)") { number += 1 }
        return "\(wanted) \(number)"
    }

    /// Turns 1.1 colour overrides on built-in themes into custom themes named "Nord (custom)".
    /// `replacesThemeID` is the built-in theme to swap for the new one if it was selected.
    public static func migrating(legacyOverrides: [String: [String: String]], palettes: [String: CustomThemePalette]) -> [(theme: CustomTheme, replacesThemeID: String)] {
        legacyOverrides.keys.sorted().compactMap { themeID in
            guard let overrides = legacyOverrides[themeID], !overrides.isEmpty, let palette = palettes[themeID] else { return nil }
            let colors = palette.colors.merging(overrides) { _, override in override }
            return (CustomTheme(name: "\(palette.name) (custom)", baseThemeID: themeID, colors: colors), themeID)
        }
    }
}
