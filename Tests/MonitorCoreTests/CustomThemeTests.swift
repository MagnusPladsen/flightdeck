import Testing
@testable import MonitorCore

struct CustomThemeTests {
    private let nord = CustomThemePalette(name: "Nord", colors: ["background": "#2E3440", "primary": "#88C0D0"])

    @Test func copyKeepsTheBasePaletteUnderAFreshName() {
        let copy = CustomTheme.copy(of: "nord", palette: nord, existingNames: [])
        #expect(copy.name == "Nord copy")
        #expect(copy.baseThemeID == "nord")
        #expect(copy.colors == nord.colors)
        #expect(copy.id.hasPrefix(CustomTheme.idPrefix))
    }

    @Test func copyNamesDoNotClash() {
        #expect(CustomTheme.uniqueName("Nord copy", existing: ["Nord copy"]) == "Nord copy 2")
        #expect(CustomTheme.uniqueName("Nord copy", existing: ["Nord copy", "Nord copy 2"]) == "Nord copy 3")
        #expect(CustomTheme.uniqueName("Nord copy", existing: ["Dracula copy"]) == "Nord copy")
    }

    @Test func legacyOverridesBecomeCustomThemes() {
        let migrated = CustomTheme.migrating(
            legacyOverrides: ["nord": ["primary": "#FF0000"], "dracula": [:], "gone": ["primary": "#00FF00"]],
            palettes: ["nord": nord]
        )
        #expect(migrated.count == 1)
        #expect(migrated[0].theme.name == "Nord (custom)")
        #expect(migrated[0].theme.colors == ["background": "#2E3440", "primary": "#FF0000"])
        #expect(migrated[0].replacesThemeID == "nord")
    }
}
