import MonitorCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettings().tabItem { Label("Appearance", systemImage: "paintpalette") }
            AlertSettings().tabItem { Label("Alerts", systemImage: "bell") }
            AISettings().tabItem { Label("AI", systemImage: "sparkles") }
            WidgetSettings().tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
        }
        .frame(width: 480)
        .frame(minHeight: 380)
    }
}

private struct GeneralSettings: View {
    @Environment(MonitorStore.self) private var store
    @Environment(AppUpdater.self) private var updater
    @Environment(WhatsNew.self) private var whatsNew
    @Environment(\.theme) private var theme
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        @Bindable var settings = store.settings
        @Bindable var updater = updater
        Form {
            Section("Menu bar") {
                Picker("Label style", selection: $settings.menuBarLabelStyle) {
                    ForEach(MenuBarLabelStyle.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Menu bar shows") {
                ForEach(MenuBarMetric.allCases) { metric in
                    Toggle(metric.title, isOn: Binding(
                        get: { settings.isShowingInMenuBar(metric) },
                        set: { settings.setMenuBarMetric(metric, shown: $0) }
                    ))
                }
            }
            Section("Menu bar panel") {
                Toggle("Show network and disk, not just CPU and memory", isOn: $settings.panelShowsNetworkAndDisk)
            }
            Section("Ports") {
                Toggle("Show system ports, not just dev servers", isOn: $settings.showSystemPorts)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, isEnabled in setLaunchAtLogin(isEnabled) }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(theme.error)
                }
            }
            Section {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                    .disabled(!updater.isAvailable)
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates || !updater.isAvailable)
                Button("What's New") {
                    DashboardOpener.open()
                    whatsNew.showRecent()
                }
                .disabled(!whatsNew.isAvailable)
            } header: {
                Text("Updates")
            } footer: {
                if !updater.isAvailable {
                    Text("Updates work only from the bundled Flightdeck.app.")
                }
            }
        }
        .formStyle(.grouped)
        .themedScrollBackground()
    }

    private func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not change login item: \(error.localizedDescription). This only works from the bundled Flightdeck.app."
        }
    }
}

private struct AISettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        Form {
            Section("Agents") {
                Toggle("Show idle agent sessions", isOn: $settings.showIdleAgents)
            }
            Section {
                Toggle("Show Claude usage limit percentages", isOn: $settings.claudeLimitsEnabled)
                    .onChange(of: settings.claudeLimitsEnabled) { Task { await store.refreshUsage() } }
            } header: {
                Text("Claude limits")
            } footer: {
                Text("Reads Claude Code's sign-in token from your keychain and calls an unofficial Anthropic endpoint. It may break or change without notice. Token counts from local logs work without this.")
            }
            Section {
                Text("Codex limits are read from local session logs in ~/.codex/sessions and need no setup.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .themedScrollBackground()
    }
}

private struct WidgetSettings: View {
    @Environment(MonitorStore.self) private var store
    @State private var editingWidget: CustomWidget?

    var body: some View {
        Form {
            Section {
                if store.settings.customWidgets.isEmpty {
                    Text("No widgets yet.").foregroundStyle(.secondary)
                }
                ForEach(store.settings.customWidgets) { widget in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(widget.title)
                            Text(widget.command)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Edit") { editingWidget = widget }
                        Button(role: .destructive) {
                            store.settings.customWidgets.removeAll { $0.id == widget.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Custom widgets")
            } footer: {
                Text("Each widget runs a shell command on a timer and shows its output on the dashboard.")
            }
            Section {
                Button("Add widget…") { editingWidget = CustomWidget(title: "", command: "") }
            }
        }
        .formStyle(.grouped)
        .themedScrollBackground()
        .sheet(item: $editingWidget) { widget in
            WidgetEditor(widget: widget) { saved in
                store.settings.upsertWidget(saved)
                Task { await store.refreshDueWidgets(force: true) }
            }
        }
    }
}

private struct AppearanceSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Theme").font(.headline)
                    Text("A theme sets the dashboard's layout as well as its colours. More layouts are on the way.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ThemeOptionButton(title: "Match system", subtitle: "Clean Dark or Clean Light · \(store.settings.layoutTitle(.ignition)) layout", themes: [.cleanDark, .cleanLight], isSelected: store.settings.themeID == Theme.systemID) {
                    store.settings.themeID = Theme.systemID
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Theme.all) { theme in
                        ThemeOptionButton(title: theme.name, subtitle: "\(store.settings.layoutTitle(theme.layout)) layout · \(theme.isDark ? "dark" : "light")", themes: [theme], isSelected: store.settings.themeID == theme.id) {
                            store.settings.themeID = theme.id
                        }
                    }
                }
                LayoutCustomization()
            }
            .padding(20)
        }
    }
}

/// Which layouts the user has rearranged, with a way back to the original.
private struct LayoutCustomization: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layout").font(.headline)
            Text("Use the lock button on any dashboard page to move, resize, hide and re-add sections. Your arrangement is saved as a custom version of the layout.")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(DashboardLayout.allCases) { layout in
                HStack {
                    Text(store.settings.layoutTitle(layout))
                    Spacer()
                    Button("Reset to original") { store.settings.resetLayout(layout) }
                        .disabled(!store.settings.isCustomized(layout))
                }
            }
        }
        .padding(.top, 8)
    }
}

private struct ThemeOptionButton: View {
    @Environment(\.theme) private var currentTheme
    var title: String
    var subtitle: String
    /// One theme for a swatch; two for a split light/dark preview.
    var themes: [Theme]
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(themes) { ThemeSwatch(theme: $0) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(subtitle).font(.caption).opacity(0.6)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(currentTheme.primary)
                }
            }
            .padding(8)
            .background(currentTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? currentTheme.primary : currentTheme.border, lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Mini preview of a palette: background with accent and status colours.
private struct ThemeSwatch: View {
    var theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(theme.foreground).frame(width: 26, height: 3)
            HStack(spacing: 3) {
                ForEach(Array([theme.primary, theme.secondary, theme.success, theme.warning, theme.error].enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 6, height: 6)
                }
            }
        }
        .padding(7)
        .background(theme.background)
    }
}
