import Foundation

/// Bar heights that move like music without hearing any, for when there is no audio to analyse.
/// Each band mixes a few slow sine waves seeded by the track, over a soft bass-heavy shape and a
/// steady pulse, so the motion feels alive but never twitchy. Same inputs always give the same bars.
public struct SyntheticSpectrum: Sendable {
    public var bandCount: Int
    public var seed: UInt64
    /// Beats per second of the low-band pulse.
    public var pulseRate = 1.9

    public init(bandCount: Int, seed: UInt64) {
        self.bandCount = bandCount
        self.seed = seed
    }

    /// A stable seed per track, so every song gets its own motion.
    public init(bandCount: Int, track: String) {
        self.init(bandCount: bandCount, seed: Self.fnv1a(track))
    }

    /// Heights at `time` seconds; `energy` scales them so pausing can ease the bars down.
    public func bands(at time: TimeInterval, energy: Double) -> [Double] {
        (0..<bandCount).map { band in
            let position = bandCount > 1 ? Double(band) / Double(bandCount - 1) : 0
            let motion = wave(band: band, time: time)
            let pulse = pow(max(sin(time * pulseRate * .pi), 0), 6) * (1 - position) * 0.35
            return min(max(shape(at: position) * (0.45 + 0.55 * motion) + pulse, 0), 1) * min(max(energy, 0), 1)
        }
    }

    /// Fuller in the lows and low mids, tapering off toward the highs.
    private func shape(at position: Double) -> Double {
        0.85 - 0.5 * position + 0.12 * sin(position * .pi * 2.2)
    }

    /// 0...1, from three sines with per-band speeds and phases taken from the seed.
    private func wave(band: Int, time: TimeInterval) -> Double {
        var generator = SplitMix(seed: seed &+ UInt64(band) &* 0x9E37_79B9_7F4A_7C15)
        let total = (0..<3).reduce(0.0) { sum, harmonic in
            let speed = 0.6 + generator.nextUnit() * 2.4 * Double(harmonic + 1)
            let phase = generator.nextUnit() * 2 * .pi
            return sum + sin(time * speed + phase)
        }
        return (total / 3 + 1) / 2
    }

    static func fnv1a(_ text: String) -> UInt64 {
        text.utf8.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }
}

/// Small deterministic generator; the standard library's is randomly seeded.
private struct SplitMix {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func nextUnit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31
        return Double(mixed >> 11) / Double(1 << 53)
    }
}
