import Foundation

/// A transport command for whatever owns the system now-playing slot, with MediaRemote's numbers.
public enum NowPlayingCommand: Int, Hashable, Sendable, CaseIterable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

/// One-off JavaScript for Automation that sends a MediaRemote command, run by `osascript` for the
/// same reason as `NowPlayingScript`. The command travels over XPC after the call returns, so the
/// script keeps its run loop alive for a moment before exiting.
public enum NowPlayingCommandScript {
    public static func arguments(for command: NowPlayingCommand) -> [String] {
        ["-l", "JavaScript", "-e", source, String(command.rawValue)]
    }

    static let source = """
    function run(argv) {
      ObjC.import('Foundation');
      $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework').load;
      ObjC.bindFunction('MRMediaRemoteSendCommand', ['bool', ['int', 'id']]);
      const sent = $.MRMediaRemoteSendCommand(parseInt(argv[0], 10), $());
      delay(0.4);
      return sent ? 'sent' : 'failed';
    }
    """
}

/// The playing app's own volume, for the few players that let other apps set it. Browsers and most
/// other players have no such control, and the system volume is never touched.
public enum AppVolume {
    /// Spotify and Music both script a 0...100 `sound volume`.
    public static let scriptableBundleIDs: Set<String> = ["com.spotify.client", "com.apple.Music"]

    public static func isSupported(bundleID: String?, processID: Int32?) -> Bool {
        guard let bundleID, let processID, processID > 0 else { return false }
        return scriptableBundleIDs.contains(bundleID)
    }

    /// Addresses the app by process id, so a second copy or a renamed app is never the target.
    public static func readArguments(processID: Int32) -> [String] {
        ["-l", "JavaScript", "-e", "Application(\(processID)).soundVolume()"]
    }

    public static func writeArguments(processID: Int32, volume: Int) -> [String] {
        ["-l", "JavaScript", "-e", "Application(\(processID)).soundVolume = \(clamped(volume))"]
    }

    /// Nil unless the script printed a whole number.
    public static func parse(_ output: String) -> Int? {
        Int(output.trimmingCharacters(in: .whitespacesAndNewlines)).map(clamped)
    }

    public static func clamped(_ volume: Int) -> Int {
        min(max(volume, 0), 100)
    }
}
