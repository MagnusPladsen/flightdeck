import MonitorCore
import SwiftUI

/// Agents in their poses, and the player.
struct OfficePeople {
    let scene: OfficeScene
    let pen: OfficePen
    let time: Double

    private var frame: Int { Int(time * 4) }

    func drawAgent(_ pid: Int32, at position: OfficePoint) {
        guard let agent = scene.agents[pid] else { return }
        let pose = scene.map.poses[pid] ?? .phone
        let (x, y) = OfficePen.pixels(position)
        if pose.isStanding { pen.ellipse(x - 5, y - 2, 10, 3, .black.opacity(0.25)) }
        let palette = OfficeCharacters.palette(tool: agent.tool, pid: pid)
        if let party = scene.party {
            pen.sprite(OfficeCharacters.headbangSprite(isStanding: pose.isStanding, isHeadDown: party.isHeadDown), palette: palette,
                       bottomCenterX: x, bottomY: y + (party.isHeadDown ? 1 : 0), flipped: (party.beat / 2 + Int(pid)).isMultiple(of: 2))
            return
        }
        let bob = pose == .impatient && frame.isMultiple(of: 2) ? -0.5 : 0
        pen.sprite(OfficeCharacters.sprite(for: pose, frame: frame + Int(pid)), palette: palette,
                   bottomCenterX: x, bottomY: y + bob, flipped: pose == .impatient && (frame / 4).isMultiple(of: 2))
    }

    func drawPlayer() {
        let (x, y) = OfficePen.pixels(scene.player)
        let feet = y + OfficeMotion.radius * OfficeCamera.tilePixels
        pen.ellipse(x - 5, feet - 2, 10, 3, .black.opacity(0.3))
        let bounce = scene.party?.isHeadDown == true && !scene.isPlayerWalking ? 1.0 : 0
        pen.sprite(OfficeCharacters.playerSprite(isWalking: scene.isPlayerWalking, frame: Int(time * 8)), palette: OfficeCharacters.playerPalette,
                   bottomCenterX: x, bottomY: feet + bounce, flipped: scene.playerFacesLeft)
    }
}

/// Name plates, cubicle labels, and the wall clock with its limits battery.
struct OfficeWallDecor {
    let scene: OfficeScene
    let pen: OfficePen
    let time: Double

    func draw() {
        for room in scene.map.rooms {
            let (x, y) = OfficePen.pixels(room.plate)
            label(room.name, x: x, y: y + 4, background: 0x2B2F38, foreground: .white, size: 6)
            for cubicle in room.cubicles {
                let (cubicleX, cubicleY) = OfficePen.pixels(TilePoint(x: cubicle.rect.x, y: cubicle.rect.y))
                label(cubicle.label, x: cubicleX + 1, y: cubicleY + 1, background: 0xF4EFE4, foreground: Color(hex: 0x4A3B2A), size: 4.5)
            }
        }
        drawClock()
        if let headroom = scene.limitsHeadroom { drawBattery(headroom) }
    }

    /// A small sign; `size` is the font size in art pixels.
    private func label(_ text: String, x: Double, y: Double, background: UInt32, foreground: Color, size: Double) {
        let scale = pen.camera.scale
        let resolved = pen.context.resolve(Text(text).font(.system(size: size * scale, weight: .bold, design: .rounded)).foregroundStyle(foreground))
        let measured = resolved.measure(in: CGSize(width: 400, height: 100))
        let width = measured.width / scale + 4
        let height = measured.height / scale + 1
        pen.context.fill(Path(roundedRect: pen.rect(x, y, width, height), cornerRadius: scale * 1.5), with: .color(Color(hex: background)))
        pen.context.draw(resolved, at: pen.point(x + width / 2, y + height / 2))
    }

    private func drawClock() {
        let (x, y) = OfficePen.pixels(scene.map.wallClock)
        let face = pen.rect(x + 3, y + 3, 10, 10)
        pen.context.fill(Path(ellipseIn: face), with: .color(Color(hex: 0xF4F1EA)))
        pen.context.stroke(Path(ellipseIn: face), with: .color(Color(hex: 0x1D1D24)), lineWidth: pen.camera.scale)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutes = Double(parts.minute ?? 0)
        hand(center: CGPoint(x: face.midX, y: face.midY), angle: minutes / 60, length: 3.6)
        hand(center: CGPoint(x: face.midX, y: face.midY), angle: (Double((parts.hour ?? 0) % 12) + minutes / 60) / 12, length: 2.4)
    }

    private func hand(center: CGPoint, angle turns: Double, length: Double) {
        let radians = turns * 2 * .pi - .pi / 2
        let tip = CGPoint(x: center.x + cos(radians) * length * pen.camera.scale, y: center.y + sin(radians) * length * pen.camera.scale)
        var path = Path()
        path.move(to: center)
        path.addLine(to: tip)
        pen.context.stroke(path, with: .color(Color(hex: 0x1D1D24)), lineWidth: pen.camera.scale)
    }

    /// Remaining usage-limit headroom, like a phone battery.
    private func drawBattery(_ headroom: Double) {
        let (x, y) = OfficePen.pixels(TilePoint(x: scene.map.wallClock.x + 1, y: scene.map.wallClock.y))
        let color: UInt32 = headroom > 0.5 ? 0x5BD96A : (headroom > 0.2 ? 0xF2B33D : 0xF2545B)
        pen.fill(x + 2, y + 5, 11, 7, 0x1D1D24)
        pen.fill(x + 13, y + 7, 1, 3, 0x1D1D24)
        pen.fill(x + 3, y + 6, 9, 5, 0x3A404C)
        pen.fill(x + 3, y + 6, (9 * min(max(headroom, 0), 1)).rounded(), 5, color)
    }
}
