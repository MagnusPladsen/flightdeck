import AppKit
import MonitorCore
import SwiftUI

/// The cover's main colours, worked out once per artwork.
@MainActor
final class ArtworkColorCache {
    private var lastArtwork: Data?
    private var lastColors: [Color] = []

    func colors(for artwork: Data) -> [Color] {
        if artwork == lastArtwork { return lastColors }
        lastArtwork = artwork
        lastColors = Self.extract(artwork).map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
        return lastColors
    }

    /// Draws the cover into 32×32 pixels and reads them back.
    private static func extract(_ artwork: Data) -> [PaletteColor] {
        guard let image = NSImage(data: artwork)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drew ? ArtworkPalette.dominantColors(rgba: pixels) : []
    }
}

extension MonitorStore {
    /// The visualiser's colours: the cover's own when that is turned on, the track has a real cover
    /// (not a browser's site icon) and it is colourful enough; otherwise the chosen palette.
    func visualizerColors(theme: Theme) -> VisualizerColors {
        if settings.visualizerUsesArtworkColors, let track = nowPlaying.track, !track.isFromBrowser, let artwork = track.artwork {
            let stops = artworkColors.colors(for: artwork)
            if stops.count >= 2 { return VisualizerColors(stops: stops) }
        }
        return VisualizerColors(palette: settings.visualizerPalette, theme: theme)
    }
}
