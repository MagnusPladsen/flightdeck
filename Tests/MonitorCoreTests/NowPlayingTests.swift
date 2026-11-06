import Foundation
import Testing
@testable import MonitorCore

struct NowPlayingParserTests {
    @Test func parsesATrackLine() throws {
        let line = #"{"state":"track","playing":true,"title":"White Oak","artist":"dryhope","album":"","duration":180.5,"elapsed":12,"rate":1,"timestamp":1793959232.5,"id":"F44C","bundleID":"com.spotify.client","app":"Spotify","hasArtwork":true,"artwork":"AQID"}"#
        guard case .track(let track) = NowPlayingParser.parse(line) else { Issue.record("Expected a track"); return }
        #expect(track.title == "White Oak")
        #expect(track.artist == "dryhope")
        #expect(track.album == nil)
        #expect(track.isPlaying)
        #expect(track.sourceName == "Spotify")
        #expect(track.duration == 180.5)
        #expect(track.reportedAt == Date(timeIntervalSince1970: 1793959232.5))
        #expect(track.artwork == Data([1, 2, 3]))
        #expect(track.subtitle == "dryhope")
    }

    @Test func toleratesMissingFields() throws {
        guard case .track(let track) = NowPlayingParser.parse(#"{"state":"track","title":"Live stream","playing":false,"rate":0}"#) else {
            Issue.record("Expected a track")
            return
        }
        #expect(!track.isPlaying)
        #expect(track.duration == nil)
        #expect(track.position(at: Date()) == nil)
        #expect(track.subtitle.isEmpty)
    }

    @Test func otherStates() {
        #expect(NowPlayingParser.parse(#"{"state":"none"}"#) == .nothingPlaying)
        #expect(NowPlayingParser.parse(#"{"state":"heartbeat"}"#) == .heartbeat)
        #expect(NowPlayingParser.parse(#"{"state":"track","title":"  "}"#) == .nothingPlaying)
        #expect(NowPlayingParser.parse("execution error: nope") == nil)
        #expect(NowPlayingParser.parse(#"{"state":"surprise"}"#) == nil)
    }

    @Test func positionAdvancesOnlyWhilePlaying() {
        let reported = Date(timeIntervalSince1970: 1_000)
        var track = NowPlayingTrack(title: "A", isPlaying: true, duration: 100, elapsed: 10, reportedAt: reported, rate: 1)
        #expect(track.position(at: reported.addingTimeInterval(5)) == 15)
        #expect(track.progress(at: reported.addingTimeInterval(40)) == 0.5)
        #expect(track.position(at: reported.addingTimeInterval(500)) == 100)
        track.isPlaying = false
        #expect(track.position(at: reported.addingTimeInterval(5)) == 10)
    }

    @Test func clockTextLooksLikeAPlayer() {
        #expect(NowPlayingTrack.clockText(65.9) == "1:05")
        #expect(NowPlayingTrack.clockText(3725) == "1:02:05")
        #expect(NowPlayingTrack.clockText(-3) == "0:00")
    }

    @Test func laterUpdatesOfTheSameTrackKeepItsArtwork() {
        let first = NowPlayingTrack(title: "A", isPlaying: true, identifier: "1", artwork: Data([9]))
        let update = NowPlayingTrack(title: "A", isPlaying: false, identifier: "1", hasArtwork: true)
        #expect(update.keepingArtwork(of: first).artwork == Data([9]))
        let next = NowPlayingTrack(title: "B", isPlaying: true, identifier: "2", hasArtwork: true)
        #expect(next.keepingArtwork(of: first).artwork == nil)
        let withoutArtwork = NowPlayingTrack(title: "A", isPlaying: true, identifier: "1")
        #expect(withoutArtwork.keepingArtwork(of: first).artwork == nil)
    }

    @Test func presenceLingersBrieflyAfterPausing() {
        let now = Date()
        let paused = NowPlayingTrack(title: "A", isPlaying: false)
        #expect(NowPlayingPresence.isVisible(NowPlayingTrack(title: "A", isPlaying: true), lastPlayedAt: nil, now: now))
        #expect(NowPlayingPresence.isVisible(paused, lastPlayedAt: now.addingTimeInterval(-5), now: now))
        #expect(!NowPlayingPresence.isVisible(paused, lastPlayedAt: now.addingTimeInterval(-60), now: now))
        #expect(!NowPlayingPresence.isVisible(paused, lastPlayedAt: nil, now: now))
        #expect(!NowPlayingPresence.isVisible(nil, lastPlayedAt: now, now: now))
    }

    @Test func scriptRunsThroughOsascriptAsJavaScript() {
        #expect(NowPlayingScript.executable == "/usr/bin/osascript")
        #expect(NowPlayingScript.arguments.prefix(3) == ["-l", "JavaScript", "-e"])
        #expect(NowPlayingScript.source.contains("MRNowPlayingRequest"))
    }
}

struct SpectrumTests {
    private func sine(frequency: Double, sampleRate: Double, amplitude: Float = 1) -> [Float] {
        (0..<SpectrumAnalyzer.windowSize).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) }
    }

    @Test func fftFindsTheBinOfAPureTone() {
        let samples = (0..<64).map { sin(2 * Double.pi * 8 * Double($0) / 64) }
        let magnitudes = FFT.magnitudes(of: samples)
        #expect(magnitudes.count == 32)
        #expect(magnitudes.firstIndex(of: magnitudes.max()!) == 8)
        #expect(abs(magnitudes[8] - 32) < 1e-9)
    }

    @Test func aLowToneLightsTheLowBandsAndAHighToneTheHighOnes() {
        let analyzer = SpectrumAnalyzer(bandCount: 16, sampleRate: 48_000)
        let low = analyzer.bands(for: sine(frequency: 80, sampleRate: 48_000))
        let high = analyzer.bands(for: sine(frequency: 9_000, sampleRate: 48_000))
        #expect(low.firstIndex(of: low.max()!)! < 4)
        #expect(high.firstIndex(of: high.max()!)! > 11)
        #expect(low.max()! > 0.7)
    }

    @Test func silenceAndQuietToneScaleDown() {
        let analyzer = SpectrumAnalyzer(bandCount: 8, sampleRate: 44_100)
        #expect(analyzer.bands(for: [Float](repeating: 0, count: 1024)).allSatisfy { $0 == 0 })
        let loud = analyzer.bands(for: sine(frequency: 440, sampleRate: 44_100)).max()!
        let quiet = analyzer.bands(for: sine(frequency: 440, sampleRate: 44_100, amplitude: 0.01)).max()!
        #expect(quiet < loud)
        #expect(quiet > 0)
    }

    @Test func trebleIsTiltedUpAgainstBass() {
        var analyzer = SpectrumAnalyzer(bandCount: 16, sampleRate: 48_000)
        let flat = { (frequency: Double) in analyzer.bands(for: self.sine(frequency: frequency, sampleRate: 48_000, amplitude: 0.01)).max()! }
        analyzer.tiltDecibelsPerOctave = 0
        let untiltedHigh = flat(8_000)
        analyzer.tiltDecibelsPerOctave = 3
        #expect(flat(8_000) > untiltedHigh)
    }

    @Test func bandsCoverDistinctBinsInOrder() {
        let ranges = SpectrumAnalyzer(bandCount: 32, sampleRate: 48_000).binRanges(binCount: 512)
        #expect(ranges.count == 32)
        for (previous, next) in zip(ranges, ranges.dropFirst()) {
            #expect(next.lowerBound > previous.upperBound)
        }
        #expect(ranges.last!.upperBound <= 511)
    }

    @Test func shortInputIsPaddedNotRejected() {
        let bands = SpectrumAnalyzer(bandCount: 8, sampleRate: 48_000).bands(for: [0.5, -0.5, 0.25])
        #expect(bands.count == 8)
    }

    @Test func smootherRisesFastAndFallsSlowly() {
        var smoother = SpectrumSmoother(bandCount: 1, attack: 0.5, release: 0.1)
        #expect(smoother.update(with: [1]) == [0.5])
        #expect(smoother.update(with: [1]) == [0.75])
        let falling = smoother.update(with: [0])[0]
        #expect(abs(falling - 0.675) < 1e-9)
    }

    @Test func smootherAdaptsToANewBandCount() {
        var smoother = SpectrumSmoother(bandCount: 2)
        #expect(smoother.update(with: [1, 1, 1]).count == 3)
    }

    @Test func inaudibleBuffersCountAsSilence() {
        #expect(AudioSilence.isSilent([0, 0, 0]))
        #expect(AudioSilence.isSilent([]))
        #expect(AudioSilence.isSilent([0, 0.0002, -0.0004]))
        #expect(!AudioSilence.isSilent([0, 0.02, 0]))
    }
}

struct SyntheticSpectrumTests {
    @Test func isDeterministicAndBounded() {
        let spectrum = SyntheticSpectrum(bandCount: 24, track: "White Oak")
        let first = spectrum.bands(at: 12.3, energy: 1)
        #expect(first == spectrum.bands(at: 12.3, energy: 1))
        #expect(first.count == 24)
        #expect(first.allSatisfy { (0...1).contains($0) })
    }

    @Test func movesOverTimeAndDiffersPerTrack() {
        let spectrum = SyntheticSpectrum(bandCount: 12, track: "A")
        #expect(spectrum.bands(at: 0, energy: 1) != spectrum.bands(at: 0.5, energy: 1))
        #expect(spectrum.bands(at: 3, energy: 1) != SyntheticSpectrum(bandCount: 12, track: "B").bands(at: 3, energy: 1))
    }

    @Test func energyScalesTheBarsDown() {
        let spectrum = SyntheticSpectrum(bandCount: 8, seed: 42)
        #expect(spectrum.bands(at: 4, energy: 0).allSatisfy { $0 == 0 })
        let full = spectrum.bands(at: 4, energy: 1).reduce(0, +)
        let half = spectrum.bands(at: 4, energy: 0.5).reduce(0, +)
        #expect(abs(half - full / 2) < 1e-9)
    }

    @Test func lowsAreFullerThanHighsOnAverage() {
        let spectrum = SyntheticSpectrum(bandCount: 16, seed: 7)
        let frames = stride(from: 0.0, to: 30, by: 0.25).map { spectrum.bands(at: $0, energy: 1) }
        let lows = frames.map { $0.prefix(4).reduce(0, +) }.reduce(0, +)
        let highs = frames.map { $0.suffix(4).reduce(0, +) }.reduce(0, +)
        #expect(lows > highs)
    }
}
