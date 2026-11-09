import Testing
@testable import MonitorCore

struct BeatDetectorTests {
    @Test func kicksAboveTheAverageAreBeats() {
        var detector = BeatDetector()
        for frame in 0..<30 { detector.hear(bass: 0.2, at: Double(frame) / 30) }
        #expect(detector.beatCount == 0)
        #expect(detector.hear(bass: 0.8, at: 1.5) == true)
        #expect(detector.beatCount == 1)
    }

    @Test func oneKickIsNotHeardTwice() {
        var detector = BeatDetector()
        detector.hear(bass: 0.1, at: 0)
        #expect(detector.hear(bass: 0.9, at: 1) == true)
        #expect(detector.hear(bass: 0.95, at: 1.1) == false)
        #expect(detector.hear(bass: 0.95, at: 1.4) == true)
    }

    @Test func silenceHasNoBeats() {
        var detector = BeatDetector()
        for frame in 0..<60 { detector.hear(bass: 0.02, at: Double(frame) / 30) }
        #expect(detector.beatCount == 0)
        #expect(detector.pulse(at: 2) == 0)
    }

    @Test func tempoBeatsOncePerInterval() {
        var detector = BeatDetector()
        let landed = (0..<60).filter { detector.keepTempo(at: Double($0) / 30, beatsPerMinute: 120) }
        #expect(landed.count == 4)
    }

    @Test func pulseFadesAfterABeat() {
        var detector = BeatDetector()
        detector.keepTempo(at: 10, beatsPerMinute: 60)
        #expect(detector.pulse(at: 10) == 1)
        #expect(detector.pulse(at: 10.1) < 1)
        #expect(detector.pulse(at: 10.5) == 0)
    }
}
