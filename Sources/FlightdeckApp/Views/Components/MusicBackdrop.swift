import MonitorCore
import SwiftUI

/// Soft glows and a dot grid behind the dashboard pages that pulse with the music, in the visualiser's colours.
/// Only drawn while something plays and the backdrop is on in Settings.
struct MusicBackdrop: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feed = OfficePartyFeed()

    var body: some View {
        if isShown, let track = store.nowPlaying.track {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let party = feed.frame(at: timeline.date, track: track, audio: store.nowPlaying.audio, colors: colors, allowsStrobe: false)
                Canvas { context, size in
                    MusicBackdropPainter(context: context, size: size, party: party, time: timeline.date.timeIntervalSinceReferenceDate,
                                         isCalm: reduceMotion).draw(store.settings.musicBackdropStyle)
                }
            }
            .allowsHitTesting(false)
            .onAppear { store.nowPlaying.visualizerAppeared() }
            .onDisappear { store.nowPlaying.visualizerDisappeared() }
            .transition(.opacity)
        }
    }

    private var isShown: Bool {
        let settings = store.settings
        return settings.musicBackdropEnabled && settings.nowPlayingEnabled && store.nowPlaying.track?.isPlaying == true
    }

    private var colors: [Color] {
        VisualizerColors(palette: store.settings.visualizerPalette, theme: theme).stops
    }
}

/// Draws one frame of the backdrop. `pulse` is 1 on a beat, easing to 0; `levels` are the spectrum bands.
struct MusicBackdropPainter {
    let context: GraphicsContext
    let size: CGSize
    let party: OfficeParty
    let time: Double
    /// Reduce Motion: levels only, no beat pulse or travelling motion.
    let isCalm: Bool

    var pulse: Double { isCalm ? 0 : party.pulse }
    var motionTime: Double { isCalm ? 0 : time }

    func draw(_ style: MusicBackdropStyle) {
        switch style {
        case .dots: drawGlows(); drawDots()
        case .glow: drawGlows(strength: 1.6)
        case .aurora: drawAurora()
        case .ripples: drawRipples()
        case .edges: drawEdges()
        case .beams: drawBeams()
        case .skyline: drawSkyline()
        case .stars: drawStars()
        case .grid: drawGrid()
        case .wave: drawWave()
        }
    }

    /// The level of the band under a share of the width, 0...1.
    func band(at share: Double) -> Double {
        guard !party.levels.isEmpty else { return 0 }
        return party.levels[min(max(Int(share * Double(party.levels.count)), 0), party.levels.count - 1)]
    }

    /// The palette colour for a share of the width, like the visualiser's gradient.
    func color(at share: Double) -> Color {
        party.color(Int(share * Double(max(party.colors.count - 1, 0)) + 0.5))
    }

    var averageLevel: Double {
        party.levels.isEmpty ? 0 : party.levels.reduce(0, +) / Double(party.levels.count)
    }

    /// How loud it is right now, 0...1: the beat when one is heard, else the overall level,
    /// so styles keep moving with live audio even when no clear kick drum comes through.
    var energy: Double { min(1, max(pulse, averageLevel * 1.6)) }
}
