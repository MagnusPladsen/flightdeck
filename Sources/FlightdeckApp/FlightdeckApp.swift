import AppKit
import SwiftUI

@main
struct FlightdeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: MonitorStore
    @State private var updater = AppUpdater()
    @State private var asker = ClaudeAsker()
    @State private var whatsNew = WhatsNew()

    init() {
        let store = MonitorStore(settings: AppSettings())
        store.start()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environment(store)
                .environment(updater)
                .themedRoot(store.settings)
        } label: {
            MenuBarLabel(store: store)
                .modifier(DashboardOpenerBridge())
        }
        .menuBarExtraStyle(.window)

        Window("Dashboard", id: DashboardView.windowID) {
            DashboardView()
                .environment(store)
                .environment(asker)
                .environment(whatsNew)
                .themedRoot(store.settings)
                .onAppear { DockPresence.dashboardDidOpen() }
                .onDisappear { DockPresence.dashboardDidClose() }
        }
        .defaultSize(width: 1180, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Ask Claude…") {
                    DashboardOpener.open()
                    asker.open()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(updater)
                .environment(whatsNew)
                .themedRoot(store.settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Opening the app again from Finder, Spotlight or the Dock brings the dashboard back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DashboardOpener.open()
        return false
    }
}

/// Lets AppKit callbacks open the dashboard, which only a SwiftUI `openWindow` action can do.
@MainActor
enum DashboardOpener {
    private static var openWindow: OpenWindowAction?

    /// Stores the action and opens the dashboard the first time, so it appears on launch.
    static func register(_ action: OpenWindowAction) {
        let isFirstRegistration = openWindow == nil
        openWindow = action
        if isFirstRegistration { open() }
    }

    /// `Window` scenes are single-instance, so this focuses an already open dashboard.
    static func open() {
        openWindow?(id: DashboardView.windowID)
        DockPresence.dashboardDidOpen()
    }
}

/// Hands the scene's `openWindow` action to `DashboardOpener` from the always-rendered menu bar label.
private struct DashboardOpenerBridge: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear { DashboardOpener.register(openWindow) }
    }
}

/// The app lives in the menu bar; it only shows a Dock icon while the dashboard is open.
@MainActor
enum DockPresence {
    static func dashboardDidOpen() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func dashboardDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }
}
