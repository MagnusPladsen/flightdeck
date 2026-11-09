import MonitorCore
import SwiftUI

/// The jukebox's stage: speaker stacks that pump on the beat, the scrolling now-playing sign
/// on top, and the disco ball over the dance floor.
struct OfficePartyGear {
    let scene: OfficeScene
    let pen: OfficePen
    let time: Double

    private var pulse: Double { scene.party?.pulse ?? 0 }
    private static let signColor: UInt32 = 0xF2B33D

    /// Art-pixel point where the disco ball hangs: over the hallway, a few tiles past the jukebox.
    static func discoBall(in map: OfficeMap) -> (x: Double, y: Double) {
        let (x, y) = OfficePen.pixels(TilePoint(x: map.jukebox.x + 4, y: map.hallway.y + 1))
        return (x + 8, y)
    }

    func drawSpeaker(_ tile: TilePoint) {
        let (x, y) = OfficePen.pixels(tile)
        pen.fill(x, y - 22, 16, 37, 0x15171C)
        pen.fill(x, y - 22, 16, 1, 0x2C3039)
        pen.fill(x + 1, y - 21, 1, 35, 0x23262E)
        pen.fill(x + 1, y + 15, 14, 1, 0x000000, opacity: 0.3)
        for cone in Self.cones { drawCone(x + 8, y + cone.y, radius: cone.radius) }
    }

    private static let cones: [(y: Double, radius: Double)] = [(-16, 3), (-4, 6), (9, 5)]

    private func drawCone(_ centerX: Double, _ centerY: Double, radius: Double) {
        let pumped = radius * (1 + 0.2 * pulse)
        pen.ellipse(centerX - radius - 1, centerY - radius - 1, radius * 2 + 2, radius * 2 + 2, Color(hex: 0x2A2E37))
        pen.ellipse(centerX - pumped, centerY - pumped, pumped * 2, pumped * 2, Color(hex: 0x0B0C0F))
        pen.ellipse(centerX - pumped * 0.4, centerY - pumped * 0.4, pumped * 0.8, pumped * 0.8, Color(hex: 0x3A3F4B))
    }

    /// Lit parts drawn over the party lights so they stay bright.
    func drawGlow() {
        if let party = scene.party {
            for speaker in scene.map.speakers { drawSpeakerGlow(speaker, party: party) }
            drawDiscoBall(party)
        }
        if let track = scene.track {
            drawPadRims()
            drawSign(track)
        }
    }

    /// Floor pads in front of the jukebox: previous, play or pause, next. Click them, or Space, Q and E nearby.
    func drawPads() {
        guard let track = scene.track else { return }
        for pad in scene.map.jukeboxPads {
            let (x, y) = OfficePen.pixels(pad.tile)
            let isPressed = scene.pressedPad == pad.command
            let sink = isPressed ? 1.0 : 0
            pen.fill(x + 1, y + 2, 14, 13, 0x0B0910, opacity: 0.6)
            pen.fill(x + 1, y + 1 + sink, 14, 12, isPressed ? 0x4A3A66 : 0x2A1F3A)
            pen.fill(x + 1, y + 1 + sink, 14, 1, 0xFFFFFF, opacity: 0.18)
            let icon = OfficePixelIcons.icon(for: pad.command, isPlaying: track.isPlaying)
            pen.sprite(icon, palette: OfficePixelIcons.palette, bottomCenterX: x + 8, bottomY: y + 10.5 + sink)
            if isPressed { pen.fill(x + 1, y + 1 + sink, 14, 12, 0xFFFFFF, opacity: 0.35) }
        }
    }

    private func drawPadRims() {
        let color = scene.party?.color(scene.party?.beat ?? 0) ?? Color(hex: Self.signColor)
        let strength = scene.isAtJukebox ? 0.9 : 0.35
        var glow = pen
        glow.context.blendMode = .plusLighter
        for (index, pad) in scene.map.jukeboxPads.enumerated() {
            let (x, y) = OfficePen.pixels(pad.tile)
            let rim = scene.party.map { $0.color(index + $0.beat) } ?? color
            glow.context.stroke(Path(glow.rect(x + 1.5, y + 1.5, 13, 12)), with: .color(rim.opacity(strength * (0.7 + 0.3 * pulse))), lineWidth: pen.camera.scale)
        }
    }

    private func drawSpeakerGlow(_ tile: TilePoint, party: OfficeParty) {
        let (x, y) = OfficePen.pixels(tile)
        var glow = pen
        glow.context.blendMode = .plusLighter
        for (index, cone) in Self.cones.enumerated() {
            let radius = cone.radius * (1 + 0.2 * pulse) + 0.5
            glow.context.stroke(Path(ellipseIn: glow.rect(x + 8 - radius, y + cone.y - radius, radius * 2, radius * 2)),
                                with: .color(party.color(index + party.beat).opacity(0.45 + 0.55 * pulse)), lineWidth: pen.camera.scale)
        }
        let wave = 7 + (1 - pulse) * 24
        glow.context.stroke(Path(ellipseIn: glow.rect(x + 8 - wave, y - 4 - wave, wave * 2, wave * 2)),
                            with: .color(party.color(party.beat).opacity(0.6 * pulse)), lineWidth: 1.5 * pen.camera.scale)
    }

    private func drawDiscoBall(_ party: OfficeParty) {
        let ball = Self.discoBall(in: scene.map)
        let top = Double(scene.map.hallway.y) * OfficeCamera.tilePixels - 4
        pen.fill(ball.x - 0.25, top, 0.5, ball.y - top - 5, 0x8A8F98)
        pen.ellipse(ball.x - 5, ball.y - 5, 10, 10, Color(hex: 0xB8BEC8))
        for row in 0..<4 {
            for column in 0..<4 {
                let isLit = (row * 4 + column + Int(time * 10)) % 5 == 0
                let color = isLit ? party.color(row + column) : Color(hex: (row + column).isMultiple(of: 2) ? 0xDDE2EA : 0x8F96A3)
                pen.context.fill(Path(pen.rect(ball.x - 4 + Double(column) * 2, ball.y - 4 + Double(row) * 2, 1.6, 1.6)), with: .color(color))
            }
        }
        pen.fill(ball.x - 3, ball.y - 3, 1, 1, 0xFFFFFF)
    }

    /// A marquee across the speaker tops scrolling the track, with chasing bulbs round it.
    private func drawSign(_ track: NowPlayingTrack) {
        let (jukeboxX, jukeboxY) = OfficePen.pixels(scene.map.jukebox)
        let sign = (x: jukeboxX - 17, y: jukeboxY - 31, width: 50.0, height: 9.0)
        let color = scene.party?.color(scene.party?.beat ?? 0) ?? Color(hex: Self.signColor)
        pen.fill(sign.x, sign.y, sign.width, sign.height, 0x0B0B10)
        pen.context.stroke(Path(pen.rect(sign.x, sign.y, sign.width, sign.height)), with: .color(color), lineWidth: pen.camera.scale)
        drawBulbs(sign, color: color)
        drawScrollingText(track, in: pen.rect(sign.x + 2, sign.y + 1.5, sign.width - 4, sign.height - 3), color: color)
        if let progress = track.progress(at: Date()) {
            pen.context.fill(Path(pen.rect(sign.x + 1, sign.y + sign.height - 1, (sign.width - 2) * progress, 0.75)), with: .color(.white.opacity(0.85)))
        }
    }

    private func drawBulbs(_ sign: (x: Double, y: Double, width: Double, height: Double), color: Color) {
        let chase = Int(time * 8)
        for bulb in 0..<Int(sign.width / 3) {
            let isLit = (bulb + chase) % 3 == 0
            let bulbX = sign.x + 1 + Double(bulb) * 3
            for bulbY in [sign.y - 1.5, sign.y + sign.height + 0.5] {
                pen.context.fill(Path(ellipseIn: pen.rect(bulbX, bulbY, 1, 1)), with: .color(isLit ? .white : color.opacity(0.35)))
            }
        }
    }

    private func drawScrollingText(_ track: NowPlayingTrack, in box: CGRect, color: Color) {
        let words = [track.title, track.artist].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
        let label = (track.isPlaying ? "♪ " : "❚❚ ") + words + "   "
        let text = pen.context.resolve(Text(label).font(.system(size: 5.5 * pen.camera.scale, weight: .heavy, design: .monospaced)).foregroundStyle(color))
        let width = text.measure(in: CGSize(width: 4000, height: 200)).width
        let travel = (time * 16 * pen.camera.scale).truncatingRemainder(dividingBy: max(width, 1))
        var clipped = pen.context
        clipped.clip(to: Path(box))
        var x = box.minX - travel
        while x < box.maxX {
            clipped.draw(text, at: CGPoint(x: x, y: box.midY), anchor: .leading)
            x += width
        }
    }
}
