import MonitorCore
import SwiftUI

/// The rave: the lights go down, the dance floor flashes on the beat, spotlights sweep,
/// lasers and disco-ball sparkles spin, and big beats strobe.
struct OfficePartyLights {
    let scene: OfficeScene
    let party: OfficeParty
    let pen: OfficePen
    let time: Double

    private var mapWidth: Double { Double(scene.map.grid.width) * OfficeCamera.tilePixels }
    private var mapHeight: Double { Double(scene.map.grid.height) * OfficeCamera.tilePixels }

    func draw() {
        pen.context.fill(Path(pen.rect(0, 0, mapWidth, mapHeight)), with: .color(.black.opacity(0.55 - 0.15 * party.pulse)))
        var glow = pen
        glow.context.blendMode = .plusLighter
        drawDanceFloor(glow)
        drawRoomGlows(glow)
        drawSpotlights(glow)
        if (party.beat / 8).isMultiple(of: 2) { drawLasers(glow) }
        drawSparkles(glow)
        drawStrobe()
    }

    private func drawDanceFloor(_ glow: OfficePen) {
        let hallway = scene.map.hallway
        for y in hallway.y..<hallway.maxY {
            for x in hallway.x..<hallway.maxX where (x + y + party.beat).isMultiple(of: 2) {
                let (left, top) = OfficePen.pixels(TilePoint(x: x, y: y))
                let color = party.color(x / 2 + y + party.beat).opacity(0.2 + 0.35 * party.pulse)
                glow.context.fill(Path(glow.rect(left + 1, top + 1, 14, 14)), with: .color(color))
            }
        }
    }

    /// A pool of coloured light drifting around each room.
    private func drawRoomGlows(_ glow: OfficePen) {
        for (index, room) in scene.map.rooms.enumerated() {
            let (left, top) = OfficePen.pixels(TilePoint(x: room.rect.x, y: room.rect.y))
            let width = Double(room.rect.width) * OfficeCamera.tilePixels
            let height = Double(room.rect.height) * OfficeCamera.tilePixels
            let center = glow.point(left + width * (0.5 + 0.35 * sin(time * 0.7 + Double(index) * 1.9)),
                                    top + height * (0.5 + 0.3 * cos(time * 0.9 + Double(index))))
            let radius = (40 + 16 * party.pulse) * pen.camera.scale
            let color = party.color(index + party.beat / 2)
            glow.context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                              with: .radialGradient(Gradient(colors: [color.opacity(0.4 + 0.3 * party.pulse), .clear]), center: center, startRadius: 0, endRadius: radius))
        }
    }

    /// Cones of light from both hallway walls, swinging back and forth.
    private func drawSpotlights(_ glow: OfficePen) {
        let hallway = scene.map.hallway
        for (index, column) in stride(from: 3, to: scene.map.grid.width - 1, by: 7).enumerated() {
            let isTop = index.isMultiple(of: 2)
            let sourceY = Double(isTop ? hallway.y : hallway.maxY) * OfficeCamera.tilePixels
            let source = glow.point(Double(column) * OfficeCamera.tilePixels + 8, sourceY)
            let angle = (isTop ? Double.pi / 2 : -Double.pi / 2) + sin(time * 1.1 + Double(index) * 1.3) * 0.7
            drawCone(from: source, angle: angle, color: party.color(index + party.beat), in: glow)
        }
    }

    private func drawCone(from source: CGPoint, angle: Double, color: Color, in glow: OfficePen) {
        let scale = pen.camera.scale
        let length = 95 * scale, spread = 0.28
        let end = CGPoint(x: source.x + cos(angle) * length, y: source.y + sin(angle) * length)
        var cone = Path()
        cone.move(to: source)
        cone.addLine(to: CGPoint(x: source.x + cos(angle - spread) * length, y: source.y + sin(angle - spread) * length))
        cone.addLine(to: CGPoint(x: source.x + cos(angle + spread) * length, y: source.y + sin(angle + spread) * length))
        cone.closeSubpath()
        glow.context.fill(cone, with: .linearGradient(Gradient(colors: [color.opacity(0.5 + 0.3 * party.pulse), .clear]), startPoint: source, endPoint: end))
        let spot = 14 * scale
        glow.context.fill(Path(ellipseIn: CGRect(x: end.x - spot, y: end.y - spot * 0.6, width: spot * 2, height: spot * 1.2)
            .offsetBy(dx: -cos(angle) * spot * 2, dy: -sin(angle) * spot * 2)), with: .color(color.opacity(0.15 + 0.2 * party.pulse)))
    }

    private func drawLasers(_ glow: OfficePen) {
        let ball = OfficePartyGear.discoBall(in: scene.map)
        let origin = glow.point(ball.x, ball.y)
        let length = 700 * pen.camera.scale
        for beam in 0..<10 {
            let direction = beam.isMultiple(of: 2) ? 1.0 : -1.0
            let angle = Double(beam) * .pi / 5 + time * 0.8 * direction
            var line = Path()
            line.move(to: origin)
            line.addLine(to: CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length * 0.6))
            let color = party.color(beam)
            glow.context.stroke(line, with: .color(color.opacity(0.25)), lineWidth: 3 * pen.camera.scale)
            glow.context.stroke(line, with: .color(color.opacity(0.8)), lineWidth: 0.6 * pen.camera.scale)
        }
    }

    /// Specks of light thrown around the room by the disco ball.
    private func drawSparkles(_ glow: OfficePen) {
        let ball = OfficePartyGear.discoBall(in: scene.map)
        for speck in 0..<80 {
            let angle = Double(speck) * 2.399 + time * 0.35
            let distance = 20 + Double((speck * 53) % 97) / 97 * 380
            let twinkle = 0.5 + 0.5 * sin(time * 7 + Double(speck) * 1.3)
            let color = speck.isMultiple(of: 3) ? party.color(speck) : .white
            glow.context.fill(Path(glow.rect(ball.x + cos(angle) * distance, ball.y + sin(angle) * distance * 0.55, 2, 2)),
                              with: .color(color.opacity(0.25 + 0.55 * twinkle)))
        }
    }

    private func drawStrobe() {
        guard party.allowsStrobe, party.beat.isMultiple(of: 4), party.pulse > 0.5 else { return }
        pen.context.fill(Path(pen.rect(0, 0, mapWidth, mapHeight)), with: .color(.white.opacity(0.22 * party.pulse)))
    }
}
