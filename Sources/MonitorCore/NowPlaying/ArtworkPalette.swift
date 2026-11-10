import Foundation

extension NowPlayingTrack {
    static let browserBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary", "com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "com.brave.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "app.zen-browser.zen", "com.kagi.kagimacOS", "org.chromium.Chromium", "ai.perplexity.comet", "com.openai.atlas",
    ]

    /// Plays in a web browser, whose artwork is usually the site's icon rather than a cover.
    public var isFromBrowser: Bool {
        sourceBundleID.map(Self.browserBundleIDs.contains) ?? false
    }
}

/// An sRGB colour with components in 0...1.
public struct PaletteColor: Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var brightness: Double { max(red, green, blue) }
    var saturation: Double { brightness == 0 ? 0 : (brightness - min(red, green, blue)) / brightness }
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
}

/// Picks the main colours of a cover from its pixels, skipping greys, black and white.
public enum ArtworkPalette {
    /// `rgba` holds 4 bytes per pixel. Returns up to `count` distinct colours, darkest first; empty for a grey cover.
    public static func dominantColors(rgba: [UInt8], count: Int = 3) -> [PaletteColor] {
        var buckets: [Int: (sum: PaletteColor, weight: Double)] = [:]
        for index in stride(from: 0, to: rgba.count - 3, by: 4) {
            let color = PaletteColor(red: Double(rgba[index]) / 255, green: Double(rgba[index + 1]) / 255, blue: Double(rgba[index + 2]) / 255)
            guard color.saturation > 0.25, color.brightness > 0.2 else { continue }
            let key = Int(color.red * 5.99) * 36 + Int(color.green * 5.99) * 6 + Int(color.blue * 5.99)
            let weight = color.saturation
            let old = buckets[key] ?? (PaletteColor(red: 0, green: 0, blue: 0), 0)
            buckets[key] = (PaletteColor(red: old.sum.red + color.red * weight, green: old.sum.green + color.green * weight,
                                         blue: old.sum.blue + color.blue * weight), old.weight + weight)
        }
        let ranked = buckets.values.sorted { $0.weight > $1.weight }.map { bucket in
            PaletteColor(red: bucket.sum.red / bucket.weight, green: bucket.sum.green / bucket.weight, blue: bucket.sum.blue / bucket.weight)
        }
        var picked: [PaletteColor] = []
        for color in ranked where picked.count < count && picked.allSatisfy({ distance($0, color) > 0.3 }) {
            picked.append(color)
        }
        return picked.sorted { $0.luminance < $1.luminance }
    }

    private static func distance(_ first: PaletteColor, _ second: PaletteColor) -> Double {
        let red = first.red - second.red, green = first.green - second.green, blue = first.blue - second.blue
        return (red * red + green * green + blue * blue).squareRoot()
    }
}
