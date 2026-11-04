import AppKit
import SwiftUI

@main
struct FlightdeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: MonitorStore
    @State private var updater = AppUpdater()

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
        }
        .menuBarExtraStyle(.window)

        Window("Dashboard", id: DashboardView.windowID) {
            DashboardView()
                .environment(store)
                .themedRoot(store.settings)
                .onAppear { DockPresence.dashboardDidOpen() }
                .onDisappear { DockPresence.dashboardDidClose() }
        }
        .defaultSize(width: 1180, height: 780)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environment(store)
                .environment(updater)
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
