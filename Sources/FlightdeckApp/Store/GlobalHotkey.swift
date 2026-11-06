import AppKit
import Carbon.HIToolbox
import MonitorCore

/// One system-wide shortcut through Carbon's hot key API, which needs no Accessibility permission.
@MainActor
final class GlobalHotkey {
    private static let signature: OSType = 0x46_44_4B_59 // "FDKY"
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: () -> Void = {}

    /// Replaces any earlier registration. Returns false when another app already owns the shortcut.
    @discardableResult
    func register(_ shortcut: HotkeyShortcut?, action: @escaping () -> Void) -> Bool {
        unregister()
        guard let shortcut, shortcut.isUsable else { return true }
        self.action = action
        installHandlerIfNeeded()
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, Self.carbonModifiers(shortcut.modifiers), identifier, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { hotkey.action() }
            return noErr
        }, 1, &eventType, context, &handlerRef)
    }

    static func carbonModifiers(_ modifiers: HotkeyShortcut.Modifiers) -> UInt32 {
        var carbon = 0
        if modifiers.contains(.control) { carbon |= controlKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        if modifiers.contains(.shift) { carbon |= shiftKey }
        if modifiers.contains(.command) { carbon |= cmdKey }
        return UInt32(carbon)
    }
}

extension HotkeyShortcut {
    /// Builds a shortcut from a key press in the recorder; nil for bare modifier presses.
    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        var modifiers: Modifiers = []
        let flags = event.modifierFlags
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: Self.label(for: event))
    }

    private static func label(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        default: return (event.charactersIgnoringModifiers ?? "").uppercased()
        }
    }
}
