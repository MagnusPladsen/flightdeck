import Foundation

/// How much of the now-playing section shows.
public enum NowPlayingMode: String, CaseIterable, Codable, Sendable {
    /// Track details and playback controls.
    case minimal
    /// Also the visualiser.
    case expanded

    public var title: String {
        switch self {
        case .minimal: "Minimal"
        case .expanded: "Expanded"
        }
    }
}

/// How the visualiser draws. Each layout has its own default; the user can pick any of them.
public enum VisualizerStyle: String, CaseIterable, Codable, Sendable {
    case bars, segments, waveform, rings, peaks, mirror, dotMatrix, line, sunburst, ribbons

    public var title: String {
        switch self {
        case .bars: "Bars"
        case .segments: "LED"
        case .waveform: "Waveform"
        case .rings: "Rings"
        case .peaks: "Peaks"
        case .mirror: "Mirror"
        case .dotMatrix: "Dot matrix"
        case .line: "Line"
        case .sunburst: "Sunburst"
        case .ribbons: "Ribbons"
        }
    }

    /// The style picked in the adjust menu, else the layout's own.
    public static func resolved(choice: VisualizerStyle?, layoutDefault: VisualizerStyle) -> VisualizerStyle {
        choice ?? layoutDefault
    }
}

/// Colours for the visualiser beyond the theme's own, which stays the default.
public enum VisualizerPalette: String, CaseIterable, Codable, Sendable {
    case accent, mono, sunset, ocean, aurora, candy

    public var title: String {
        switch self {
        case .accent: "Accent"
        case .mono: "Mono"
        case .sunset: "Sunset"
        case .ocean: "Ocean"
        case .aurora: "Aurora"
        case .candy: "Candy"
        }
    }

    /// Fixed gradient stops as hex, left to right; nil for palettes taken from the theme.
    public var hexStops: [String]? {
        switch self {
        case .accent, .mono: nil
        case .sunset: ["#FF5E62", "#FF9966", "#FFD452"]
        case .ocean: ["#00C6FF", "#0072FF", "#7F5AF0"]
        case .aurora: ["#00F5A0", "#00D9F5", "#A05CFF"]
        case .candy: ["#F72585", "#B5179E", "#4CC9F0"]
        }
    }
}

/// The dashboard background that pulses with the music, in the visualiser's colours.
public enum MusicBackdropStyle: String, CaseIterable, Codable, Sendable {
    case dots, glow, aurora, ripples, edges, beams, skyline, stars, grid, wave

    public var title: String {
        switch self {
        case .dots: "Dot grid"
        case .glow: "Glow"
        case .aurora: "Aurora"
        case .ripples: "Ripples"
        case .edges: "Edges"
        case .beams: "Beams"
        case .skyline: "Skyline"
        case .stars: "Stars"
        case .grid: "Grid"
        case .wave: "Wave"
        }
    }
}

/// Where the visualiser's motion comes from right now, so the UI can say so.
public enum VisualizerSource: Equatable, Sendable {
    /// A made-up animation that only follows play and pause.
    case animated
    /// Real levels from the system audio tap.
    case live
    /// Following the audio is on, but the tap hears nothing: the permission is denied, the tap
    /// failed, or the player is silent. Falls back to the animation.
    case noAudioHeard

    public static func resolve(isPlaying: Bool, followsAudio: Bool, tapIsRunning: Bool, isSilent: Bool) -> VisualizerSource {
        guard followsAudio else { return .animated }
        guard isPlaying else { return .live }
        return tapIsRunning && !isSilent ? .live : .noAudioHeard
    }

    public var title: String {
        switch self {
        case .animated: "Animated"
        case .live: "Live audio"
        case .noAudioHeard: "No audio heard"
        }
    }

    public var explanation: String {
        switch self {
        case .animated: "This animation follows play and pause, not the music. Turn on \"Follow the actual audio\" to see real levels."
        case .live: "Levels come from what the Mac is playing right now."
        case .noAudioHeard: "Following the audio is on, but nothing is heard. Check System Settings › Privacy & Security › Screen & System Audio Recording."
        }
    }
}
