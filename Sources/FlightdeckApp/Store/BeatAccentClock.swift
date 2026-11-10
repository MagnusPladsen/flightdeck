import MonitorCore
import Observation
import SwiftUI

/// The beat, about thirty times a second, for the small accents that flash with the music.
/// Only runs while the accents are on and something plays.
@MainActor
@Observable
final class BeatAccentClock {
    /// 1 on a beat, easing to 0.
    private(set) var pulse: Double = 0
    private(set) var color: Color = .accentColor
    @ObservationIgnored private let feed = OfficePartyFeed()

    func run(store: MonitorStore, theme: Theme) async {
        while !Task.isCancelled, let track = store.nowPlaying.track, track.isPlaying {
            let colors = store.visualizerColors(theme: theme).stops
            let party = feed.frame(at: Date(), track: track, audio: store.nowPlaying.audio, colors: colors, allowsStrobe: false)
            pulse = party.pulse
            color = party.color(party.beat)
            try? await Task.sleep(for: .milliseconds(33))
        }
        pulse = 0
    }
}

/// Keeps the beat clock running behind the dashboard while beat accents are on and music plays.
struct BeatAccentDriver: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .task(id: isActive) {
                guard isActive else { return }
                store.nowPlaying.visualizerAppeared()
                await store.beatAccent.run(store: store, theme: theme)
                store.nowPlaying.visualizerDisappeared()
            }
    }

    private var isActive: Bool {
        let settings = store.settings
        return settings.beatAccentsEnabled && settings.nowPlayingEnabled && !reduceMotion && store.nowPlaying.track?.isPlaying == true
    }
}

/// A glow in the beat's colour that flashes with each beat, when beat accents are running.
struct BeatAccentGlow: ViewModifier {
    @Environment(BeatAccentClock.self) private var clock: BeatAccentClock?
    var radius: CGFloat = 6

    func body(content: Content) -> some View {
        let pulse = clock?.pulse ?? 0
        content
            .shadow(color: (clock?.color ?? .clear).opacity(0.9 * pulse), radius: radius * pulse)
            .scaleEffect(1 + 0.12 * pulse)
    }
}

extension View {
    func beatAccent(radius: CGFloat = 6) -> some View {
        modifier(BeatAccentGlow(radius: radius))
    }
}
