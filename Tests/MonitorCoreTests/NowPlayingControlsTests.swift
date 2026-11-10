import Foundation
import Testing
@testable import MonitorCore

struct NowPlayingControlsTests {
    @Test func commandScriptPassesMediaRemoteNumbers() {
        #expect(NowPlayingCommand.togglePlayPause.rawValue == 2)
        #expect(NowPlayingCommand.nextTrack.rawValue == 4)
        #expect(NowPlayingCommand.previousTrack.rawValue == 5)
        let arguments = NowPlayingCommandScript.arguments(for: .nextTrack)
        #expect(arguments.prefix(2) == ["-l", "JavaScript"])
        #expect(arguments.last == "4")
        #expect(arguments.contains { $0.contains("MRMediaRemoteSendCommand") })
    }

    @Test func volumeOnlyForScriptablePlayersWithAProcess() {
        #expect(AppVolume.isSupported(bundleID: "com.spotify.client", processID: 42))
        #expect(AppVolume.isSupported(bundleID: "com.apple.Music", processID: 42))
        #expect(!AppVolume.isSupported(bundleID: "com.google.Chrome", processID: 42))
        #expect(!AppVolume.isSupported(bundleID: "app.zen-browser.zen", processID: 42))
        #expect(!AppVolume.isSupported(bundleID: "com.spotify.client", processID: nil))
        #expect(!AppVolume.isSupported(bundleID: "com.spotify.client", processID: 0))
        #expect(!AppVolume.isSupported(bundleID: nil, processID: 42))
    }

    @Test func volumeScriptsAddressTheProcessIDAndClamp() {
        #expect(AppVolume.readArguments(processID: 30304).last == "Application(30304).soundVolume()")
        #expect(AppVolume.writeArguments(processID: 30304, volume: 140).last == "Application(30304).soundVolume = 100")
        #expect(AppVolume.writeArguments(processID: 30304, volume: -5).last == "Application(30304).soundVolume = 0")
    }

    @Test func parsesVolumeOutput() {
        #expect(AppVolume.parse("64\n") == 64)
        #expect(AppVolume.parse("101") == 100)
        #expect(AppVolume.parse("") == nil)
        #expect(AppVolume.parse("execution error: Not authorized") == nil)
    }

    @Test func parserReadsThePlayerProcess() {
        let line = #"{"state":"track","playing":true,"title":"White Oak","bundleID":"com.spotify.client","pid":30304}"#
        guard case .track(let track) = NowPlayingParser.parse(line) else { Issue.record("Expected a track"); return }
        #expect(track.sourceProcessID == 30304)
        guard case .track(let unknown) = NowPlayingParser.parse(#"{"state":"track","title":"A","pid":0}"#) else { Issue.record("Expected a track"); return }
        #expect(unknown.sourceProcessID == nil)
    }
}

struct VisualizerOptionsTests {
    @Test func styleFollowsTheLayoutUntilPicked() {
        #expect(VisualizerStyle.resolved(choice: nil, layoutDefault: .rings) == .rings)
        #expect(VisualizerStyle.resolved(choice: .peaks, layoutDefault: .rings) == .peaks)
        #expect(VisualizerStyle.allCases.count == 10)
        #expect(MusicBackdropStyle.allCases.count == 10)
    }

    @Test func fixedPalettesHaveThreeStopsAndThemePalettesNone() {
        for palette in VisualizerPalette.allCases {
            switch palette {
            case .accent, .mono: #expect(palette.hexStops == nil)
            default: #expect(palette.hexStops?.count == 3)
            }
        }
    }

    @Test func sourceSaysWhetherTheBarsHearTheMusic() {
        #expect(VisualizerSource.resolve(isPlaying: true, followsAudio: false, tapIsRunning: false, isSilent: true) == .animated)
        #expect(VisualizerSource.resolve(isPlaying: true, followsAudio: true, tapIsRunning: true, isSilent: false) == .live)
        #expect(VisualizerSource.resolve(isPlaying: true, followsAudio: true, tapIsRunning: true, isSilent: true) == .noAudioHeard)
        #expect(VisualizerSource.resolve(isPlaying: true, followsAudio: true, tapIsRunning: false, isSilent: false) == .noAudioHeard)
        #expect(VisualizerSource.resolve(isPlaying: false, followsAudio: true, tapIsRunning: false, isSilent: true) == .live)
    }

    @Test func togglingCollapsedSectionsKeepsDeclaredOrder() {
        #expect(CollapsibleSection.toggling(.nowPlaying, in: []) == [.nowPlaying])
        #expect(CollapsibleSection.toggling(.system, in: [.nowPlaying]) == [.system, .nowPlaying])
        #expect(CollapsibleSection.toggling(.nowPlaying, in: [.system, .nowPlaying]) == [.system])
    }
}

struct VisualizerTimingTests {
    @Test func smootherMovesTheSameAtAnyFrameRate() {
        var at30 = SpectrumSmoother(bandCount: 1)
        var at60 = SpectrumSmoother(bandCount: 1)
        _ = at30.update(with: [1], elapsed: 1.0 / 30)
        _ = at60.update(with: [1], elapsed: 1.0 / 60)
        let after60 = at60.update(with: [1], elapsed: 1.0 / 60)[0]
        #expect(abs(at30.levels[0] - after60) < 1e-9)
    }

    /// 1.4.0 reacted in about 100 ms and took over half a second to fall back after a beat.
    @Test func barsFollowBeatsQuickly() {
        let smoother = SpectrumSmoother(bandCount: 1)
        #expect(smoother.responseTime(reaching: 0.9, rising: true, frameInterval: 1.0 / 60) <= 0.06)
        #expect(smoother.responseTime(reaching: 0.9, rising: false, frameInterval: 1.0 / 60) <= 0.25)
        let old = SpectrumSmoother(bandCount: 1, attack: 0.65, release: 0.14)
        #expect(old.responseTime(reaching: 0.9, rising: false, frameInterval: 1.0 / 30) > 0.5)
    }

    @Test func smootherIgnoresLongStalls() {
        var smoother = SpectrumSmoother(bandCount: 1)
        _ = smoother.update(with: [1], elapsed: 60)
        #expect(smoother.levels[0] <= 1)
        #expect(smoother.levels[0] > 0.99)
    }

    @Test func peaksHoldThenFall() {
        var hold = PeakHold(bandCount: 1)
        #expect(hold.update(with: [0.8], elapsed: 0.02) == [0.8])
        #expect(hold.update(with: [0.2], elapsed: 0.3) == [0.8])
        let falling = hold.update(with: [0.2], elapsed: 0.3)[0]
        #expect(falling < 0.8 && falling >= 0.2)
        #expect(hold.update(with: [0.2], elapsed: 2)[0] == 0.2)
        #expect(hold.update(with: [0.9], elapsed: 0.02) == [0.9])
    }
}

struct NowPlayingOptimisticTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func pauseFreezesThePositionWhereItWas() {
        let track = NowPlayingTrack(title: "A", isPlaying: true, duration: 200, elapsed: 10, reportedAt: start)
        let paused = track.applying(.togglePlayPause, at: start.addingTimeInterval(5))
        #expect(!paused.isPlaying)
        #expect(paused.position(at: start.addingTimeInterval(60)) == 15)
    }

    @Test func playResumesFromThePausedPosition() {
        let track = NowPlayingTrack(title: "A", isPlaying: false, duration: 200, elapsed: 15, reportedAt: start)
        let playing = track.applying(.play, at: start.addingTimeInterval(30))
        #expect(playing.isPlaying)
        #expect(playing.position(at: start.addingTimeInterval(32)) == 17)
    }

    @Test func skipsWaitForThePlayer() {
        let track = NowPlayingTrack(title: "A", isPlaying: true, elapsed: 3, reportedAt: start)
        #expect(track.applying(.nextTrack, at: start.addingTimeInterval(1)) == track)
    }
}
