import MonitorCore
import SwiftUI

/// Everything one frame of the office needs.
struct OfficeScene {
    var map: OfficeMap
    var agents: [Int32: AgentSession]
    /// 0...1
    var cpuLoad: Double
    var memory: MemoryUsage?
    /// Remaining share of the most-used limit window, 0...1; nil without limit data.
    var limitsHeadroom: Double?
    var isMusicPlaying: Bool
    /// What plays, for the sign over the jukebox; nil when nothing does.
    var track: NowPlayingTrack?
    /// The rave while music plays and the party is on.
    var party: OfficeParty?
    /// The player stands by the jukebox, so its pads light up.
    var isAtJukebox = false
    /// The pad pressed a moment ago, drawn pushed in.
    var pressedPad: NowPlayingCommand?
    var player: OfficePoint
    var isPlayerWalking: Bool
    var playerFacesLeft: Bool
    /// The agent the player is next to or pointing at; its bubble is always shown in full.
    var spotlightPID: Int32?
    /// The sky in the windows; nil keeps it noon and the lights on.
    var outside: OfficeOutside?
}

/// Draws the office: floors and walls, then furniture and people from back to front, then bubbles.
struct OfficeRenderer {
    let scene: OfficeScene
    let pen: OfficePen
    let time: Double

    func draw(size: CGSize) {
        let windows = OfficeWindowsLayer(scene: scene, outside: scene.outside ?? .noon, pen: pen, time: time)
        drawTiles(size: size)
        windows.drawWindows()
        OfficeWallDecor(scene: scene, pen: pen, time: time).draw()
        OfficePartyGear(scene: scene, pen: pen, time: time).drawPads()
        for item in drawables().sorted(by: { $0.depth < $1.depth }) { item.draw() }
        if let party = scene.party { OfficePartyLights(scene: scene, party: party, pen: pen, time: time).draw() } else { windows.drawNight() }
        OfficePartyGear(scene: scene, pen: pen, time: time).drawGlow()
        OfficeBubbles(scene: scene, pen: pen, time: time).draw()
    }

    private func drawTiles(size: CGSize) {
        let camera = pen.camera
        let first = camera.officePoint(screenX: 0, screenY: 0).tile
        let last = camera.officePoint(screenX: size.width, screenY: size.height).tile
        for y in stride(from: max(0, first.y), through: min(scene.map.grid.height - 1, last.y), by: 1) {
            for x in stride(from: max(0, first.x), through: min(scene.map.grid.width - 1, last.x), by: 1) {
                drawTile(TilePoint(x: x, y: y))
            }
        }
    }

    private func drawTile(_ tile: TilePoint) {
        let (x, y) = OfficePen.pixels(tile)
        switch scene.map.grid[tile] {
        case .void: return
        case .wall:
            pen.fill(x, y, 16, 16, 0x4B5363)
            pen.fill(x, y, 16, 4, 0x6B7486)
            pen.fill(x, y + 15, 16, 1, 0x3A404C)
        case .partition:
            drawFloor(.roomFloor, tile, x, y)
            pen.fill(x + 6, y, 4, 16, 0xB8C0CC)
            pen.fill(x + 6, y, 1, 16, 0xD5DBE3)
        case .furniture: drawFloor(floorUnderFurniture(tile), tile, x, y)
        case let floor: drawFloor(floor, tile, x, y)
        }
    }

    private func floorUnderFurniture(_ tile: TilePoint) -> OfficeTile {
        if scene.map.hallway.contains(tile) { return .hallFloor }
        return scene.map.closet.contains(tile) ? .closetFloor : .roomFloor
    }

    private func drawFloor(_ floor: OfficeTile, _ tile: TilePoint, _ x: Double, _ y: Double) {
        switch floor {
        case .hallFloor:
            pen.fill(x, y, 16, 16, (tile.x + tile.y).isMultiple(of: 2) ? 0xD9D3C7 : 0xCFC8BA)
        case .closetFloor:
            pen.fill(x, y, 16, 16, 0x464C57)
            pen.fill(x + 15, y, 1, 16, 0x3D424C)
            pen.fill(x, y + 15, 16, 1, 0x3D424C)
        default:
            pen.fill(x, y, 16, 16, tile.y.isMultiple(of: 2) ? 0x9C7A55 : 0x967451)
            pen.fill(x, y + 8, 16, 1, 0x87684A)
            pen.fill(x + Double((tile.y * 7) % 16), y, 1, 8, 0x87684A)
        }
    }

    private func drawables() -> [OfficeDrawable] {
        let furniture = OfficeFurniture(scene: scene, pen: pen, time: time)
        let people = OfficePeople(scene: scene, pen: pen, time: time)
        var items: [OfficeDrawable] = []
        for desk in scene.map.desks {
            let deskY = Double(desk.desk.y)
            items.append(OfficeDrawable(depth: deskY + 0.2) { furniture.drawChair(desk) })
            items.append(OfficeDrawable(depth: deskY + 0.9) { furniture.drawDesk(desk) })
            if let pid = desk.agentPID, let position = scene.map.position(of: pid) {
                items.append(OfficeDrawable(depth: position.y) { people.drawAgent(pid, at: position) })
            }
        }
        for rack in scene.map.racks { items.append(OfficeDrawable(depth: Double(rack.tile.y) + 0.9) { furniture.drawServerRack(rack) }) }
        for room in scene.map.rooms {
            let plant = TilePoint(x: room.rect.maxX - 2, y: room.rect.y + 1)
            items.append(OfficeDrawable(depth: Double(plant.y) + 0.8) { furniture.drawPlant(plant) })
        }
        items.append(OfficeDrawable(depth: Double(scene.map.cpuRack.maxY) - 0.1) { furniture.drawCPURack() })
        items.append(OfficeDrawable(depth: Double(scene.map.waterCooler.y) + 0.9) { furniture.drawWaterCooler() })
        items.append(OfficeDrawable(depth: Double(scene.map.jukebox.y) + 0.9) { furniture.drawJukebox() })
        let gear = OfficePartyGear(scene: scene, pen: pen, time: time)
        for speaker in scene.map.speakers { items.append(OfficeDrawable(depth: Double(speaker.y) + 0.9) { gear.drawSpeaker(speaker) }) }
        items.append(OfficeDrawable(depth: scene.player.y + OfficeMotion.radius) { people.drawPlayer() })
        return items
    }
}

/// One thing to paint, with the depth used to order it back to front.
struct OfficeDrawable {
    let depth: Double
    let draw: () -> Void
}
