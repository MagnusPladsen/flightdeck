import Foundation

/// Finds beats for the office party: kicks in the bass of real audio, or a steady party tempo
/// when the music is only animated.
public struct BeatDetector: Sendable {
    public static let fallbackTempo = 128.0
    /// Bass must rise this far above its running average to count as a kick.
    public var sensitivity = 1.3
    /// Quietest bass that can still be a kick, 0...1.
    public var floor = 0.12
    /// Shortest time between two beats, so one kick isn't heard twice.
    public var minimumGap: TimeInterval = 0.28
    public private(set) var beatCount = 0
    public private(set) var lastBeat: TimeInterval?
    private var average: Double?
    private var tempoIndex: Int?

    public init() {}

    /// Feeds the bass level heard at `time`; true when it lands a beat.
    @discardableResult
    public mutating func hear(bass: Double, at time: TimeInterval) -> Bool {
        let baseline = average ?? bass
        average = baseline * 0.9 + bass * 0.1
        guard bass > max(baseline * sensitivity, floor) else { return false }
        if let lastBeat, time - lastBeat < minimumGap { return false }
        return beat(at: time)
    }

    /// Beats on a fixed tempo; true when `time` has crossed into a new beat.
    @discardableResult
    public mutating func keepTempo(at time: TimeInterval, beatsPerMinute: Double = fallbackTempo) -> Bool {
        let interval = 60 / beatsPerMinute
        let index = Int((time / interval).rounded(.down))
        guard index != tempoIndex else { return false }
        tempoIndex = index
        return beat(at: Double(index) * interval)
    }

    /// 1 right on a beat, easing to 0 over `decay` seconds.
    public func pulse(at time: TimeInterval, decay: TimeInterval = 0.32) -> Double {
        guard let lastBeat else { return 0 }
        let remaining = 1 - max(time - lastBeat, 0) / decay
        return remaining > 0 ? remaining * remaining : 0
    }

    private mutating func beat(at time: TimeInterval) -> Bool {
        lastBeat = time
        beatCount += 1
        return true
    }
}
