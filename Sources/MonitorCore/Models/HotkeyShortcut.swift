import Foundation

/// A global keyboard shortcut: a virtual key code plus modifiers, with the key's printable label.
public struct HotkeyShortcut: Sendable, Hashable, Codable {
    public struct Modifiers: OptionSet, Sendable, Hashable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers
    /// What the key prints, e.g. "N" or "Space".
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// ⌃⌥N: unused by macOS and the common terminals and editors.
    public static let nextAgentDefault = HotkeyShortcut(keyCode: 45, modifiers: [.control, .option], keyLabel: "N")

    /// A global shortcut without ⌃, ⌥ or ⌘ would swallow ordinary typing.
    public var isUsable: Bool {
        !modifiers.intersection([.control, .option, .command]).isEmpty
    }

    /// Modifier symbols in the order macOS menus use, then the key.
    public var displayString: String {
        let symbols: [(Modifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + keyLabel
    }
}
