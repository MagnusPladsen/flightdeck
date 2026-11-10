import MonitorCore
import SwiftUI

/// Previous, play or pause, and next for whatever plays, plus the player's own volume where it
/// has one that other apps may set.
struct NowPlayingTransport: View {
    @Environment(MonitorStore.self) private var store
    var track: NowPlayingTrack

    var body: some View {
        HStack(spacing: 2) {
            control("backward.fill", help: "Previous", command: .previousTrack)
            control(track.isPlaying ? "pause.fill" : "play.fill", help: track.isPlaying ? "Pause" : "Play", command: .togglePlayPause)
            control("forward.fill", help: "Next", command: .nextTrack)
            if let volume = store.nowPlaying.appVolume {
                AppVolumeSlider(volume: volume, appName: track.sourceName ?? SourceApp.name(bundleID: track.sourceBundleID)).padding(.leading, 10)
            }
        }
    }

    private func control(_ symbol: String, help: String, command: NowPlayingCommand) -> some View {
        Button { store.nowPlaying.send(command) } label: { Image(systemName: symbol) }
            .buttonStyle(IconButtonStyle())
            .help(help)
    }
}

private struct AppVolumeSlider: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var volume: Int
    var appName: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
                .frame(width: 16)
            Slider(value: Binding(get: { Double(volume) }, set: { store.nowPlaying.setAppVolume(Int($0.rounded())) }), in: 0...100)
                .controlSize(.mini)
                .frame(width: 96)
        }
        .help("\(appName ?? "Player") volume: \(volume)%. Changes only this app, not the Mac's volume.")
    }
}

/// Opens the now-playing adjustments: mode, visualiser style and colour.
struct NowPlayingAdjustButton: View {
    @State private var isAdjusting = false

    var body: some View {
        Button { isAdjusting = true } label: { Image(systemName: "slider.horizontal.3") }
            .buttonStyle(IconButtonStyle())
            .help("Adjust")
            .popover(isPresented: $isAdjusting, arrowEdge: .bottom) {
                NowPlayingAdjustments().padding(16).frame(width: 300, alignment: .leading)
            }
    }
}

private struct NowPlayingAdjustments: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        let settings = store.settings
        VStack(alignment: .leading, spacing: 14) {
            group("Mode") {
                Picker("Mode", selection: Binding(get: { settings.nowPlayingMode }, set: { settings.nowPlayingMode = $0 })) {
                    ForEach(NowPlayingMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Group {
                group("Style") { stylePicker }
                group("Colour") { VisualizerPaletteSwatches() }
                FollowAudioToggle()
                MusicBackdropToggle()
            }
            .disabled(settings.nowPlayingMode == .minimal)
        }
    }

    private var stylePicker: some View {
        let settings = store.settings
        return Picker("Style", selection: Binding(get: { settings.visualizerStyle }, set: { settings.visualizerStyle = $0 })) {
            Text("Layout default (\(VisualizerStyle(layout: layout).title))").tag(VisualizerStyle?.none)
            Divider()
            ForEach(VisualizerStyle.allCases, id: \.self) { Text($0.title).tag(VisualizerStyle?.some($0)) }
        }
        .labelsHidden()
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }
}

/// A swatch per palette, the theme's own first.
private struct VisualizerPaletteSwatches: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let selected = store.settings.visualizerPalette
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                swatch(nil, title: "Theme", isSelected: selected == nil)
                ForEach(VisualizerPalette.allCases, id: \.self) { swatch($0, title: $0.title, isSelected: selected == $0) }
            }
            Text(selected?.title ?? "Theme (follows the colours of \(theme.name))").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func swatch(_ palette: VisualizerPalette?, title: String, isSelected: Bool) -> some View {
        let colors = VisualizerColors(palette: palette, theme: theme)
        return Button { store.settings.visualizerPalette = palette } label: {
            Circle()
                .fill(LinearGradient(colors: colors.stops, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 22, height: 22)
                .padding(3)
                .overlay { Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

/// The opt-in to real audio levels, with what it costs.
/// Turns the dashboard background that pulses with the music on or off, and picks its style.
struct MusicBackdropToggle: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        let settings = store.settings
        Toggle("Pulse the background to the music", isOn: Binding(get: { settings.musicBackdropEnabled }, set: { settings.musicBackdropEnabled = $0 }))
        Picker("Background", selection: Binding(get: { settings.musicBackdropStyle }, set: { settings.musicBackdropStyle = $0 })) {
            ForEach(MusicBackdropStyle.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .disabled(!settings.musicBackdropEnabled)
    }
}

struct FollowAudioToggle: View {
    @Environment(MonitorStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Follow the actual audio", isOn: Binding(get: { store.settings.nowPlayingUsesSystemAudio }, set: { store.setNowPlayingUsesSystemAudio($0) }))
                .toggleStyle(.checkbox)
            Text("Off, the visualiser is an animation that follows play and pause. On, it shows the real levels and asks for the system audio recording permission.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Says whether the bars hear the music or only animate, and opens the switch between the two.
struct VisualizerSourceBadge: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var track: NowPlayingTrack
    @State private var isExplaining = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let source = currentSource
            Button { isExplaining = true } label: { label(for: source) }
                .buttonStyle(.plain)
                .help(source.explanation)
                .popover(isPresented: $isExplaining, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(source.explanation).fixedSize(horizontal: false, vertical: true)
                        FollowAudioToggle()
                    }
                    .padding(16)
                    .frame(width: 300, alignment: .leading)
                }
        }
    }

    private var currentSource: VisualizerSource {
        let audio = store.nowPlaying.audio
        return VisualizerSource.resolve(isPlaying: track.isPlaying, followsAudio: store.settings.nowPlayingUsesSystemAudio,
                                        tapIsRunning: audio.isRunning, isSilent: AudioSilence.isSilent(audio.recentSamples()))
    }

    private func label(for source: VisualizerSource) -> some View {
        let tint = switch source {
        case .animated: theme.muted
        case .live: theme.success
        case .noAudioHeard: theme.warning
        }
        let symbol = switch source {
        case .animated: "sparkles"
        case .live: "waveform"
        case .noAudioHeard: "speaker.slash"
        }
        return Label(source.title, systemImage: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
