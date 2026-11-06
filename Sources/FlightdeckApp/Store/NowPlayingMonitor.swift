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
    /// The playing app's own volume, 0...100; nil where it cannot be set (see `AppVolume`).
    private(set) var appVolume: Int?
    let audio = SystemAudioTap()

    private var lastPlayedAt: Date?
    private var process: Process?
    private var pendingOutput = Data()
    private var isRunning = false
    private var visualizerCount = 0
    private var usesSystemAudio = false
    private var isDemo = false
    private var volumeWrite: Task<Void, Never>?
    /// A read started just before a slider change would put the old volume back.
    private var volumeChangedAt: Date?

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
        isDemo = true
        apply(.track(track))
        appVolume = 70
    }

    /// Play, pause or skip whatever plays. Play and pause show at once; the script confirms them.
    func send(_ command: NowPlayingCommand) {
        if let track { apply(.track(track.applying(command, at: Date()))) }
        guard !isDemo else { return }
        Task.detached { _ = CommandRunner.run(NowPlayingScript.executable, NowPlayingCommandScript.arguments(for: command), timeout: 3) }
    }

    /// Writes the last value of a slider drag once it pauses, rather than every step.
    func setAppVolume(_ volume: Int) {
        appVolume = AppVolume.clamped(volume)
        volumeChangedAt = Date()
        guard !isDemo, let processID = track?.sourceProcessID else { return }
        volumeWrite?.cancel()
        volumeWrite = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            _ = await Self.runScript(AppVolume.writeArguments(processID: processID, volume: volume))
        }
    }

    private func refreshAppVolume() {
        guard !isDemo else { return }
        guard let track, AppVolume.isSupported(bundleID: track.sourceBundleID, processID: track.sourceProcessID), let processID = track.sourceProcessID else {
            return appVolume = nil
        }
        Task {
            let volume = AppVolume.parse(await Self.runScript(AppVolume.readArguments(processID: processID)))
            let isSettled = volumeChangedAt.map { Date().timeIntervalSince($0) > 2 } ?? true
            if self.track?.sourceProcessID == processID, isSettled { appVolume = volume }
        }
    }

    private nonisolated static func runScript(_ arguments: [String]) async -> String {
        await Task.detached { CommandRunner.run(NowPlayingScript.executable, arguments, timeout: 3).output }.value
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
        let wasPlaying = track?.isPlaying == true
        switch event {
        case .track(let next):
            track = next.keepingArtwork(of: track)
            refreshAppVolume()
        case .nothingPlaying:
            track = nil
            appVolume = nil
        case .heartbeat:
            break
        }
        let now = Date()
        // The grace period runs from the moment playback stopped.
        if wasPlaying || track?.isPlaying == true { lastPlayedAt = now }
        isVisible = NowPlayingPresence.isVisible(track, lastPlayedAt: lastPlayedAt, now: now)
        updateAudioCapture()
    }
}
