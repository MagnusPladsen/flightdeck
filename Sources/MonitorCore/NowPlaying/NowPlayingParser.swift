import Foundation

/// One line from `NowPlayingScript`.
public enum NowPlayingEvent: Equatable, Sendable {
    case track(NowPlayingTrack)
    case nothingPlaying
    case heartbeat
}

public enum NowPlayingParser {
    private struct Line: Decodable {
        var state: String
        var playing: Bool?
        var title: String?
        var artist: String?
        var album: String?
        var duration: Double?
        var elapsed: Double?
        var rate: Double?
        var timestamp: Double?
        var id: String?
        var bundleID: String?
        var app: String?
        var pid: Int32?
        var hasArtwork: Bool?
        var artwork: String?
    }

    /// Nil for lines that are not valid script output.
    public static func parse(_ line: String) -> NowPlayingEvent? {
        guard let decoded = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)) else { return nil }
        switch decoded.state {
        case "heartbeat": return .heartbeat
        case "none": return .nothingPlaying
        case "track": return track(from: decoded).map(NowPlayingEvent.track) ?? .nothingPlaying
        default: return nil
        }
    }

    private static func track(from line: Line) -> NowPlayingTrack? {
        guard let title = line.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
        let rate = line.rate ?? 1
        return NowPlayingTrack(
            title: title, artist: nonEmpty(line.artist), album: nonEmpty(line.album),
            isPlaying: line.playing ?? (rate > 0), sourceBundleID: nonEmpty(line.bundleID), sourceName: nonEmpty(line.app),
            sourceProcessID: line.pid.flatMap { $0 > 0 ? $0 : nil },
            duration: line.duration.flatMap { $0 > 0 ? $0 : nil }, elapsed: line.elapsed,
            reportedAt: line.timestamp.map(Date.init(timeIntervalSince1970:)), rate: rate > 0 ? rate : 1,
            identifier: nonEmpty(line.id), artwork: line.artwork.flatMap { Data(base64Encoded: $0) },
            hasArtwork: line.hasArtwork ?? false
        )
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// Decides whether the now-playing section shows. A short grace period after pausing stops it
/// flickering away between tracks or when the user pauses for a moment.
public enum NowPlayingPresence {
    public static let gracePeriod: TimeInterval = 20

    public static func isVisible(_ track: NowPlayingTrack?, lastPlayedAt: Date?, now: Date) -> Bool {
        guard let track else { return false }
        if track.isPlaying { return true }
        guard let lastPlayedAt else { return false }
        return now.timeIntervalSince(lastPlayedAt) < gracePeriod
    }
}
