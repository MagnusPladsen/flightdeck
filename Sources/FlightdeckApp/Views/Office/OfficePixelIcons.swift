import MonitorCore

/// Seven-pixel transport icons for the jukebox pads.
enum OfficePixelIcons {
    static let palette = SpritePalette(colors: ["w": 0xFFFFFF])

    static let play = PixelSprite(name: "icon-play", rows: ["w......", "www....", "wwwww..", "wwwwwww", "wwwww..", "www....", "w......"])
    static let pause = PixelSprite(name: "icon-pause", rows: Array(repeating: "ww...ww", count: 7))
    static let previous = PixelSprite(name: "icon-previous", rows: ["w....ww", "w...www", "w..wwww", "w.wwwww", "w..wwww", "w...www", "w....ww"])
    static let next = PixelSprite(name: "icon-next", rows: ["ww....w", "www...w", "wwww..w", "wwwww.w", "wwww..w", "www...w", "ww....w"])

    static func icon(for command: NowPlayingCommand, isPlaying: Bool) -> PixelSprite {
        switch command {
        case .previousTrack: previous
        case .nextTrack: next
        default: isPlaying ? pause : play
        }
    }
}
