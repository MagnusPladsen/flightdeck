import AppKit
import MonitorCore
import SwiftUI

/// The jukebox's own screen, shown while the player stands by it: pixelated artwork, the track
/// on a neon frame and chunky pixel buttons, so it reads as part of the game.
struct OfficeJukeboxPanel: View {
    var track: NowPlayingTrack
    var colors: [Color]
    var send: (NowPlayingCommand) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OfficePixelArtwork(track: track).frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.isPlaying ? "NOW SPINNING" : "PAUSED").font(.pixel(8)).tracking(1.5).foregroundStyle(colors.first ?? .orange)
                Text(track.title).font(.pixel(13)).foregroundStyle(.white).lineLimit(1)
                if let artist = track.artist, !artist.isEmpty {
                    Text(artist).font(.pixel(10)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                OfficePixelProgress(track: track, color: colors.last ?? .orange)
                HStack(spacing: 6) {
                    OfficePixelButton(icon: OfficePixelIcons.previous, key: "Q", help: "Previous track") { send(.previousTrack) }
                    OfficePixelButton(icon: track.isPlaying ? OfficePixelIcons.pause : OfficePixelIcons.play, key: "SPACE", help: "Play or pause") { send(.togglePlayPause) }
                    OfficePixelButton(icon: OfficePixelIcons.next, key: "E", help: "Next track") { send(.nextTrack) }
                }
                .padding(.top, 3)
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
        .background(OfficePixelFrame(colors: colors))
    }
}

extension Font {
    static func pixel(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .monospaced) }
}

/// A dark panel with stepped pixel corners and a neon border in the visualiser's colours.
private struct OfficePixelFrame: View {
    var colors: [Color]

    var body: some View {
        let shape = SteppedRectangle(step: 4)
        shape.fill(Color(hex: 0x140D1C))
            .overlay { shape.inset(by: 1.5).stroke(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), lineWidth: 3) }
            .overlay { SteppedRectangle(step: 3).inset(by: 6).stroke(.white.opacity(0.08), lineWidth: 1) }
            .shadow(color: (colors.first ?? .clear).opacity(0.55), radius: 12)
    }
}

/// A rectangle with its corners cut into one pixel step.
private struct SteppedRectangle: InsettableShape {
    var step: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: insetAmount, dy: insetAmount)
        return Path { path in
            path.addLines([
                CGPoint(x: frame.minX + step, y: frame.minY), CGPoint(x: frame.maxX - step, y: frame.minY),
                CGPoint(x: frame.maxX - step, y: frame.minY + step), CGPoint(x: frame.maxX, y: frame.minY + step),
                CGPoint(x: frame.maxX, y: frame.maxY - step), CGPoint(x: frame.maxX - step, y: frame.maxY - step),
                CGPoint(x: frame.maxX - step, y: frame.maxY), CGPoint(x: frame.minX + step, y: frame.maxY),
                CGPoint(x: frame.minX + step, y: frame.maxY - step), CGPoint(x: frame.minX, y: frame.maxY - step),
                CGPoint(x: frame.minX, y: frame.minY + step), CGPoint(x: frame.minX + step, y: frame.minY + step),
            ])
            path.closeSubpath()
        }
    }

    func inset(by amount: CGFloat) -> SteppedRectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// The artwork shrunk to 20 by 20 pixels and blown back up, else a pixel record.
private struct OfficePixelArtwork: View {
    var track: NowPlayingTrack

    var body: some View {
        Group {
            if let artwork = PixelatedArtwork.image(for: track) {
                Image(decorative: artwork, scale: 1).resizable().interpolation(.none)
            } else {
                OfficePixelIcons.record.image(palette: OfficePixelIcons.recordPalette).resizable().interpolation(.none)
                    .padding(6)
                    .background(Color(hex: 0x241A30))
            }
        }
        .overlay { Rectangle().strokeBorder(.black, lineWidth: 2) }
    }
}

@MainActor
private enum PixelatedArtwork {
    private static let size = 20
    private static var cached: (key: String, image: CGImage?)?

    static func image(for track: NowPlayingTrack) -> CGImage? {
        guard let data = track.artwork else { return nil }
        let key = "\(track.identifier ?? track.title)-\(data.count)"
        if let cached, cached.key == key { return cached.image }
        let image = pixelate(data)
        cached = (key, image)
        return image
    }

    private static func pixelate(_ data: Data) -> CGImage? {
        guard let source = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context.makeImage()
    }
}

/// A row of blocks that fills as the track plays, with the position beside them.
private struct OfficePixelProgress: View {
    static let blocks = 18
    var track: NowPlayingTrack
    var color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let lit = Int(((track.progress(at: timeline.date) ?? 0) * Double(Self.blocks)).rounded())
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<Self.blocks, id: \.self) { block in
                        Rectangle().fill(block < lit ? color : .white.opacity(0.12)).frame(width: 6, height: 4)
                    }
                }
                if let position = track.position(at: timeline.date) {
                    Text(NowPlayingTrack.clockText(position)).font(.pixel(8)).foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }
}

/// A chunky button with a pixel icon and the key that does the same.
private struct OfficePixelButton: View {
    var icon: PixelSprite
    var key: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                icon.image(palette: OfficePixelIcons.palette).resizable().interpolation(.none).frame(width: 14, height: 14)
                    .frame(width: 34, height: 24)
                    .background(Color(hex: 0x2E2440))
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.18)).frame(height: 2) }
                    .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.45)).frame(height: 2) }
                    .overlay { Rectangle().strokeBorder(.black, lineWidth: 1.5) }
                Text(key).font(.pixel(7)).foregroundStyle(.white.opacity(0.45))
            }
        }
        .buttonStyle(OfficePixelButtonStyle())
        .help(help)
    }
}

private struct OfficePixelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.offset(y: configuration.isPressed ? 1 : 0).brightness(configuration.isPressed ? -0.1 : 0)
    }
}

/// Seven-pixel transport icons and a record for tracks without artwork.
enum OfficePixelIcons {
    static let palette = SpritePalette(colors: ["w": 0xFFFFFF])
    static let recordPalette = SpritePalette(colors: ["k": 0x111116, "g": 0x2E2E38, "r": 0xF2545B, "w": 0xFFFFFF])

    static let play = PixelSprite(name: "icon-play", rows: ["w......", "www....", "wwwww..", "wwwwwww", "wwwww..", "www....", "w......"])
    static let pause = PixelSprite(name: "icon-pause", rows: Array(repeating: "ww...ww", count: 7))
    static let previous = PixelSprite(name: "icon-previous", rows: ["w....ww", "w...www", "w..wwww", "w.wwwww", "w..wwww", "w...www", "w....ww"])
    static let next = PixelSprite(name: "icon-next", rows: ["ww....w", "www...w", "wwww..w", "wwwww.w", "wwww..w", "www...w", "ww....w"])
    static let record = PixelSprite(name: "icon-record", rows: [
        "...kkkkkk...",
        "..kkgkkgkk..",
        ".kgkkkkkkgk.",
        "kkkkrrrrkkkk",
        "kgkrrrrrrkgk",
        "kkkrrwwrrkkk",
        "kkkrrwwrrkkk",
        "kgkrrrrrrkgk",
        "kkkkrrrrkkkk",
        ".kgkkkkkkgk.",
        "..kkgkkgkk..",
        "...kkkkkk...",
    ])
}
