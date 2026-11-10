import MonitorCore
import ServiceManagement
import SwiftUI

/// The dashboard's settings page: a tab bar over one settings section, filling the window.
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(SettingsTab.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 560)
            .padding(.vertical, 14)
            content
                .frame(maxWidth: 760, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general: GeneralSettings()
        case .appearance: AppearanceSettings()
        case .alerts: AlertSettings()
        case .ai: AISettings()
        case .widgets: WidgetSettings()
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, alerts, ai, widgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .alerts: "Alerts"
        case .ai: "AI"
        case .widgets: "Widgets"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .alerts: "bell"
        case .ai: "sparkles"
        case .widgets: "square.grid.2x2"
        }
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
            NowPlayingSettings()
            OfficeSettings()
            NextAgentHotkeySection()
            CommandLineSettings()
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
            KeepAwakeSettings()
            AgentLaunchSettings()
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
            SpendSettings()
            DailyRecapSettings()
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
                LayoutPicker()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Theme").font(.headline)
                    Text("Colours for the whole app. Every theme works with every layout.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ThemeOptionButton(title: "Match system", subtitle: "Clean Dark or Clean Light", themes: [.cleanDark, .cleanLight], isSelected: store.settings.themeID == Theme.systemID) {
                    store.settings.themeID = Theme.systemID
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Theme.all) { theme in
                        ThemeOptionButton(title: theme.name, subtitle: theme.isDark ? "Dark" : "Light", themes: [theme], isSelected: store.settings.themeID == theme.id) {
                            store.settings.themeID = theme.id
                        }
                    }
                }
                if !store.settings.customThemes.isEmpty {
                    Text("Your themes").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(store.settings.customThemes) { custom in
                            let theme = store.settings.theme(for: custom)
                            ThemeOptionButton(title: custom.name, subtitle: "Custom · \(theme.isDark ? "Dark" : "Light")", themes: [theme], isSelected: store.settings.themeID == custom.id) {
                                store.settings.themeID = custom.id
                            }
                        }
                    }
                }
                CustomColorsEditor()
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
            ForEach(DashboardLayout.allCases.filter { $0 == store.settings.dashboardLayout || store.settings.isCustomized($0) }) { layout in
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

/// Opt-in token and spend tracking. Off by default, because subscriptions do not bill per token.
private struct SpendSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        @Bindable var settings = store.settings
        Section {
            Toggle("Track tokens and estimated spend", isOn: Binding(get: { settings.spendTrackingEnabled }, set: { store.setSpendTrackingEnabled($0) }))
            if settings.spendTrackingEnabled {
                TextField("Daily budget (US$)", value: $settings.dailySpendBudget, format: .number.precision(.fractionLength(0...2)))
                    .onSubmit { Task { await store.refreshSpend() } }
            }
        } header: {
            Text("Token spend")
        } footer: {
            Text("Adds a Token spend section to the Agents page with tokens per project and an estimated pay-as-you-go API cost per model, read from local Claude Code and Codex logs. It is only an estimate: subscriptions are billed differently. Set a daily budget above 0 to get an alert when today's estimate passes it.")
        }
    }
}

/// The now-playing section, and whether its visualiser hears the actual audio.
private struct NowPlayingSettings: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        let settings = store.settings
        Section {
            Toggle("Show what's playing on the dashboard", isOn: Binding(get: { settings.nowPlayingEnabled }, set: { store.setNowPlayingEnabled($0) }))
            Toggle("Visualiser follows the actual audio", isOn: Binding(get: { settings.nowPlayingUsesSystemAudio }, set: { store.setNowPlayingUsesSystemAudio($0) }))
                .disabled(!settings.nowPlayingEnabled)
            Toggle("Party in the office while music plays", isOn: Binding(get: { settings.officePartyEnabled }, set: { settings.officePartyEnabled = $0 }))
                .disabled(!settings.nowPlayingEnabled)
            MusicBackdropToggle()
                .disabled(!settings.nowPlayingEnabled)
            MusicColorToggles()
                .disabled(!settings.nowPlayingEnabled)
            Toggle("Mini player in the menu bar panel", isOn: Binding(get: { settings.panelShowsNowPlaying }, set: { settings.panelShowsNowPlaying = $0 }))
                .disabled(!settings.nowPlayingEnabled)
            Toggle("Music bars in the menu bar", isOn: Binding(get: { settings.menuBarShowsVisualizer }, set: { settings.menuBarShowsVisualizer = $0 }))
                .disabled(!settings.nowPlayingEnabled)
        } header: {
            Text("Now playing")
        } footer: {
            Text("Shows the track, artist, artwork and playback controls from Spotify, Music, browsers and any other app that plays media, under System on the overview. It hides itself when nothing plays.\n\nWith \"Visualiser follows the actual audio\" off, the bars are an animation that only follows play and pause, not the beat; the section marks this as Animated. Turn it on for real levels, marked Live audio: it asks for the system audio recording permission and only listens while the visualiser is on screen. Mode, style and colour are in the adjust menu on the section.\n\nThe office party dims the lights, flashes the dance floor in the visualiser's colours and gets the agents nodding to the beat; with the actual audio it follows the kick drum. Reduce Motion turns off the strobe.\n\nThe pulsing background puts soft glows and dots in the same colours behind the dashboard while music plays.\n\nThe mini player shows the track and its controls in the menu bar panel. Music bars put a tiny live visualiser next to the menu bar readings while something plays.\n\nColours from the cover art paint the visualiser, background and office party in the cover's colours; music playing in a browser keeps the chosen palette, as its artwork is the site's icon. Flash accents on the beat makes status dots and the selected page glow with each beat.")
        }
    }
}
