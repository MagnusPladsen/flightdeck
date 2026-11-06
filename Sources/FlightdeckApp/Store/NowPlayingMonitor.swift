import Foundation
import MonitorCore
import Observation

/// Follows the system now-playing item through a long-running `osascript` (see `NowPlayingScript`)
/// and owns the optional system audio tap behind the visualiser.
@MainActor
@Observable
final class NowPlayingMonitor {
    private static let restartDelay: Duration = .seconds(5)

    private(set) var track: NowPlayingTrack?
    /// Whether the section shows: playing, or paused only moments ago.
    private(set) var isVisible = false
    let audio = SystemAudioTap()

    private var lastPlayedAt: Date?
    private var process: Process?
    private var pendingOutput = Data()
    private var isRunning = false
    private var visualizerCount = 0
    private var usesSystemAudio = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        launchScript()
    }

    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
        apply(.nothingPlaying)
    }

    /// Demo mode: a made-up track instead of the script.
    func showDemo(_ track: NowPlayingTrack) {
        apply(.track(track))
    }

    func setUsesSystemAudio(_ isEnabled: Bool) {
        usesSystemAudio = isEnabled
        updateAudioCapture()
    }

    /// The tap only runs while a visualiser is on screen and something plays.
    func visualizerAppeared() {
        visualizerCount += 1
        updateAudioCapture()
    }

    func visualizerDisappeared() {
        visualizerCount = max(visualizerCount - 1, 0)
        updateAudioCapture()
    }

    private func updateAudioCapture() {
        let shouldCapture = usesSystemAudio && visualizerCount > 0 && track?.isPlaying == true
        if shouldCapture { audio.start() } else { audio.stop() }
    }

    private func launchScript() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: NowPlayingScript.executable)
        process.arguments = NowPlayingScript.arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor in self?.receive(data) }
        }
        process.terminationHandler = { [weak self] _ in
            output.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in await self?.scriptEnded(process) }
        }
        do { try process.run() } catch { return }
        self.process = process
    }

    /// The script should run as long as the app does; if it dies, it comes back after a pause.
    private func scriptEnded(_ ended: Process) async {
        guard ended === process else { return }
        process = nil
        try? await Task.sleep(for: Self.restartDelay)
        if isRunning && process == nil { launchScript() }
    }

    private func receive(_ data: Data) {
        pendingOutput.append(data)
        while let newline = pendingOutput.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: pendingOutput[pendingOutput.startIndex..<newline], as: UTF8.self)
            pendingOutput.removeSubrange(pendingOutput.startIndex...newline)
            if let event = NowPlayingParser.parse(line) { apply(event) }
        }
    }

    private func apply(_ event: NowPlayingEvent) {
        switch event {
        case .track(let next):
            track = next.keepingArtwork(of: track)
        case .nothingPlaying:
            track = nil
        case .heartbeat:
            break
        }
        let now = Date()
        if track?.isPlaying == true { lastPlayedAt = now }
        isVisible = NowPlayingPresence.isVisible(track, lastPlayedAt: lastPlayedAt, now: now)
        updateAudioCapture()
    }
}
