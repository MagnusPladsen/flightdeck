import Foundation

/// What the Mac is playing, from whichever app owns the system now-playing slot.
public struct NowPlayingTrack: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var isPlaying: Bool
    public var sourceBundleID: String?
    public var sourceName: String?
    public var duration: TimeInterval?
    /// Elapsed time at `reportedAt`; playback has moved on by `rate` seconds per second since.
    public var elapsed: TimeInterval?
    public var reportedAt: Date?
    public var rate: Double
    public var identifier: String?
    public var artwork: Data?
    public var hasArtwork: Bool

    public init(title: String, artist: String? = nil, album: String? = nil, isPlaying: Bool, sourceBundleID: String? = nil, sourceName: String? = nil,
                duration: TimeInterval? = nil, elapsed: TimeInterval? = nil, reportedAt: Date? = nil, rate: Double = 1,
                identifier: String? = nil, artwork: Data? = nil, hasArtwork: Bool = false) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.sourceBundleID = sourceBundleID
        self.sourceName = sourceName
        self.duration = duration
        self.elapsed = elapsed
        self.reportedAt = reportedAt
        self.rate = rate
        self.identifier = identifier
        self.artwork = artwork
        self.hasArtwork = hasArtwork || artwork != nil
    }

    /// The playback position now, clamped to the track length.
    public func position(at now: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        let moved = isPlaying ? max(now.timeIntervalSince(reportedAt ?? now), 0) * rate : 0
        let position = elapsed + moved
        return duration.map { min(position, $0) } ?? position
    }

    /// 0...1 through the track, when its length is known.
    public func progress(at now: Date) -> Double? {
        guard let duration, duration > 0, let position = position(at: now) else { return nil }
        return min(max(position / duration, 0), 1)
    }

    /// "1:05", or "1:02:05" past an hour, as music players show positions.
    public static func clockText(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded(.down)), 0)
        let (hours, minutes, rest) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }

    /// "Artist · Album", leaving out whichever is empty.
    public var subtitle: String {
        [artist, album].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The script sends artwork once per track, so later updates of the same track keep it.
    public func keepingArtwork(of previous: NowPlayingTrack?) -> NowPlayingTrack {
        guard artwork == nil, hasArtwork, let previous, previous.identifier == identifier, previous.title == title else { return self }
        var merged = self
        merged.artwork = previous.artwork
        return merged
    }
}
