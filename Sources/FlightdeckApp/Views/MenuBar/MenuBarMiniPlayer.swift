import MonitorCore
import SwiftUI

/// The playing track in the menu bar panel: artwork, title, controls and a slim visualiser.
struct MenuBarMiniPlayer: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var track: NowPlayingTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                NowPlayingArtwork(track: track).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(track.subtitle.isEmpty ? (track.isPlaying ? "Playing" : "Paused") : track.subtitle)
                        .font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(1)
                }
                Spacer(minLength: 6)
                NowPlayingTransport(track: track, showsVolume: false)
            }
            NowPlayingVisualizer(track: track, style: .bars).frame(height: 18)
        }
        .padding(10)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.border) }
    }
}
