import CoreGraphics
import SwiftUI

/// A small picture written as rows of palette letters; "." is transparent.
struct PixelSprite: Hashable {
    let name: String
    let rows: [String]

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }

    /// Draws the sprite once per palette and keeps the bitmap. Only called while drawing on the main thread.
    func image(palette: SpritePalette) -> Image {
        let key = SpriteKey(sprite: self, palette: palette)
        if let cached = SpriteCache.images[key] { return cached }
        let image = render(palette).map { Image(decorative: $0, scale: 1).interpolation(.none) } ?? Image(systemName: "questionmark")
        SpriteCache.images[key] = image
        return image
    }

    private func render(_ palette: SpritePalette) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for (row, line) in rows.enumerated() {
            for (column, letter) in line.enumerated() {
                guard let hex = palette.colors[letter] else { continue }
                context.setFillColor(CGColor.fromHex(hex))
                context.fill(CGRect(x: column, y: height - 1 - row, width: 1, height: 1))
            }
        }
        return context.makeImage()
    }
}

/// Colours for a sprite's letters, as 0xRRGGBB.
struct SpritePalette: Hashable {
    var colors: [Character: UInt32]
}

private struct SpriteKey: Hashable {
    let sprite: PixelSprite
    let palette: SpritePalette
}

private enum SpriteCache {
    nonisolated(unsafe) static var images: [SpriteKey: Image] = [:]
}

extension CGColor {
    static func fromHex(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}
