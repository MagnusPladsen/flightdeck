import AppKit
import MonitorCore
import SwiftUI

/// What the Mac is playing: artwork, track, playback controls and, when expanded, a live
/// visualiser in the theme's colours.
struct NowPlayingSection: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ConceptHeading(title: "Now playing")
                if let track = store.nowPlaying.track, store.settings.nowPlayingMode == .expanded {
                    VisualizerSourceBadge(track: track)
                }
                NowPlayingAdjustButton()
            }
            if let track = store.nowPlaying.track {
                content(for: track)
            } else {
                NowPlayingPlaceholder()
            }
        }
    }

    @ViewBuilder
    private func content(for track: NowPlayingTrack) -> some View {
        if store.settings.nowPlayingMode == .minimal {
            NowPlayingDetails(track: track).frame(maxWidth: 420, alignment: .leading)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    NowPlayingDetails(track: track).frame(width: 300, alignment: .leading)
                    visualizer(for: track)
                }
                VStack(alignment: .leading, spacing: 14) {
                    NowPlayingDetails(track: track)
                    visualizer(for: track)
                }
            }
        }
    }

    private func visualizer(for track: NowPlayingTrack) -> some View {
        let style = VisualizerStyle.resolved(choice: store.settings.visualizerStyle, layoutDefault: VisualizerStyle(layout: layout))
        return NowPlayingVisualizer(track: track, style: style)
            .frame(minWidth: 220, maxWidth: .infinity)
            .frame(height: style == .rings ? 96 : 72)
    }
}

/// Artwork, title, artist and where it plays, with a progress line when the length is known and
/// the playback controls underneath.
private struct NowPlayingDetails: View {
    var track: NowPlayingTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NowPlayingSummary(track: track)
            NowPlayingTransport(track: track)
        }
    }
}

private struct NowPlayingSummary: View {
    @Environment(\.theme) private var theme
    var track: NowPlayingTrack

    var body: some View {
        HStack(spacing: 14) {
            NowPlayingArtwork(track: track).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                if !track.subtitle.isEmpty {
                    Text(track.subtitle).font(.system(size: 13)).foregroundStyle(theme.muted).lineLimit(1)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    NowPlayingProgress(track: track, now: context.date)
                }
            }
            .help(track.subtitle.isEmpty ? track.title : "\(track.title)\n\(track.subtitle)")
        }
    }
}

private struct NowPlayingProgress: View {
    @Environment(\.theme) private var theme
    var track: NowPlayingTrack
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(caption).font(.system(size: 11).monospacedDigit()).foregroundStyle(theme.muted).lineLimit(1)
            if let progress = track.progress(at: now) {
                ThinBar(fraction: progress, color: theme.accent, height: 3)
            }
        }
        .padding(.top, 2)
    }

    /// "Spotify · 1:05 / 3:41", or "Paused" in place of the clock.
    private var caption: String {
        let source = track.sourceName ?? SourceApp.name(bundleID: track.sourceBundleID)
        var parts = [source].compactMap { $0 }
        if !track.isPlaying {
            parts.append("Paused")
        } else if let position = track.position(at: now) {
            let length = track.duration.map { " / " + NowPlayingTrack.clockText($0) } ?? ""
            parts.append(NowPlayingTrack.clockText(position) + length)
        }
        return parts.joined(separator: " · ")
    }
}

/// The track's artwork, else the playing app's icon on a tinted tile.
struct NowPlayingArtwork: View {
    @Environment(\.theme) private var theme
    var track: NowPlayingTrack

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Group {
            if let data = track.artwork, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [theme.primary.opacity(0.35), theme.secondary.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let icon = SourceApp.icon(bundleID: track.sourceBundleID) {
                        Image(nsImage: icon).resizable().frame(width: 38, height: 38)
                    } else {
                        Image(systemName: "music.note").font(.system(size: 24, weight: .semibold)).foregroundStyle(theme.foreground.opacity(0.8))
                    }
                }
            }
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(theme.border) }
    }
}

/// Shown only while editing the layout, when nothing plays.
private struct NowPlayingPlaceholder: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Label("Shows up here when music or other audio plays", systemImage: "music.note")
            .font(.system(size: 13))
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }
}

/// Name and icon of the app that owns the now-playing item.
enum SourceApp {
    static func name(bundleID: String?) -> String? {
        url(bundleID: bundleID).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
    }

    static func icon(bundleID: String?) -> NSImage? {
        url(bundleID: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    private static func url(bundleID: String?) -> URL? {
        bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }
}
