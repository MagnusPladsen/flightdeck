import MonitorCore
import SwiftUI

/// One frame of the office party: the beat, the music's levels and the visualiser's colours.
struct OfficeParty {
    var levels: [Double]
    /// 1 on a beat, easing to 0 before the next.
    var pulse: Double
    var beat: Int
    var colors: [Color]
    /// Off with Reduce Motion: no full-room flashes.
    var allowsStrobe: Bool

    var isHeadDown: Bool { pulse > 0.3 }

    func color(_ index: Int) -> Color {
        guard !colors.isEmpty else { return .white }
        return colors[((index % colors.count) + colors.count) % colors.count]
    }
}

/// Turns what plays into party frames: levels from the visualiser's feed, beats from their bass,
/// or a steady party tempo while the music is only animated.
@MainActor
final class OfficePartyFeed {
    private let spectrum = SpectrumFeed()
    private var beats = BeatDetector()

    func frame(at date: Date, track: NowPlayingTrack, audio: SystemAudioTap, colors: [Color], allowsStrobe: Bool) -> OfficeParty {
        let time = date.timeIntervalSinceReferenceDate
        let levels = spectrum.frame(at: date, track: track, audio: audio).levels
        if audio.isRunning, !AudioSilence.isSilent(audio.recentSamples()) {
            beats.hear(bass: Self.bass(of: levels), at: time)
        } else {
            beats.keepTempo(at: time)
        }
        return OfficeParty(levels: levels, pulse: beats.pulse(at: time), beat: beats.beatCount, colors: colors, allowsStrobe: allowsStrobe)
    }

    private static func bass(of levels: [Double]) -> Double {
        let low = levels.prefix(4)
        return low.isEmpty ? 0 : low.reduce(0, +) / Double(low.count)
    }
}
