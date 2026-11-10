import Testing
@testable import MonitorCore

struct ArtworkPaletteTests {
    private func pixels(_ colors: [(UInt8, UInt8, UInt8)], repeating count: Int) -> [UInt8] {
        colors.flatMap { color in Array(repeating: [color.0, color.1, color.2, 255], count: count).flatMap { $0 } }
    }

    @Test func picksDistinctColoursAndSkipsGreys() {
        let rgba = pixels([(230, 40, 40), (40, 60, 220), (128, 128, 128), (10, 10, 10), (235, 45, 38)], repeating: 50)
        let colors = ArtworkPalette.dominantColors(rgba: rgba)
        #expect(colors.count == 2)
        #expect(colors.allSatisfy { $0.saturation > 0.5 })
    }

    @Test func greyCoverHasNoPalette() {
        #expect(ArtworkPalette.dominantColors(rgba: pixels([(120, 120, 120), (250, 250, 250)], repeating: 20)).isEmpty)
    }

    @Test func knowsBrowsers() {
        #expect(NowPlayingTrack(title: "x", isPlaying: true, sourceBundleID: "com.google.Chrome").isFromBrowser)
        #expect(!NowPlayingTrack(title: "x", isPlaying: true, sourceBundleID: "com.spotify.client").isFromBrowser)
    }
}
