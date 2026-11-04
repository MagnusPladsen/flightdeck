import AppKit

/// A code editor that can open a project folder.
struct EditorApp: Identifiable, Hashable {
    var id: String { bundleID }
    let bundleID: String
    let name: String

    static let known: [EditorApp] = [
        EditorApp(bundleID: "dev.zed.Zed", name: "Zed"),
        EditorApp(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
        EditorApp(bundleID: "com.microsoft.VSCode", name: "VS Code"),
        EditorApp(bundleID: "com.exafunction.windsurf", name: "Windsurf"),
        EditorApp(bundleID: "com.apple.dt.Xcode", name: "Xcode"),
        EditorApp(bundleID: "com.jetbrains.intellij", name: "IntelliJ IDEA"),
        EditorApp(bundleID: "com.jetbrains.rider", name: "Rider"),
        EditorApp(bundleID: "com.sublimetext.4", name: "Sublime Text"),
        EditorApp(bundleID: "com.panic.Nova", name: "Nova"),
    ]

    static func installed() -> [EditorApp] {
        known.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }
}
