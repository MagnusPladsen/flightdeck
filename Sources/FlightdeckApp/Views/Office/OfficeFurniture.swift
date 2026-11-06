import SwiftUI
import MonitorCore

/// Desks, chairs, plants and the objects that show system stats.
struct OfficeFurniture {
    let scene: OfficeScene
    let pen: OfficePen
    let time: Double

    func drawChair(_ desk: OfficeDesk) {
        let (x, y) = OfficePen.pixels(desk.desk)
        pen.fill(x + 9, y - 2, 14, 8, 0x3A3F4B)
        pen.fill(x + 9, y - 2, 14, 1, 0x4D5361)
    }

    func drawDesk(_ desk: OfficeDesk) {
        let (x, y) = OfficePen.pixels(desk.desk)
        let isWorking = desk.agentPID.flatMap { scene.map.poses[$0] } == .typing
        if isWorking { pen.fill(x + 1, y - 4, 12, 10, 0x8FD3FF, opacity: 0.18 + 0.08 * sin(time * 3)) }
        pen.fill(x + 2, y - 3, 10, 8, 0x2B2F38)
        pen.fill(x + 3, y - 2, 8, 1, isWorking ? 0x8FD3FF : 0x3A3F4B)
        pen.fill(x, y + 4, 32, 5, 0xC8A27A)
        pen.fill(x, y + 4, 32, 1, 0xDDBB93)
        pen.fill(x, y + 9, 32, 6, 0x8C6A4A)
        pen.fill(x + 1, y + 15, 30, 1, 0x000000, opacity: 0.25)
        pen.fill(x + 11, y + 5, 10, 2, 0x5A5F6B)
        pen.fill(x + 25, y + 2, 3, 4, 0xEDEDED)
        pen.fill(x + 28, y + 3, 1, 2, 0xEDEDED)
    }

    /// A small rack per dev server, its lights blinking while it listens.
    func drawServerRack(_ rack: OfficeRack) {
        let (x, y) = OfficePen.pixels(rack.tile)
        pen.fill(x + 2, y - 6, 12, 20, 0x262A33)
        pen.fill(x + 2, y - 6, 12, 1, 0x3A404C)
        for unit in 0..<3 {
            let unitY = y - 3 + Double(unit * 5)
            pen.fill(x + 4, unitY, 8, 3, 0x1B1E25)
            let isOn = sin(time * 2.5 + Double(rack.port.port % 17) + Double(unit) * 1.7) > -0.3
            pen.fill(x + 5, unitY + 1, 1, 1, isOn ? 0x5BD96A : 0x2D4A33)
            pen.fill(x + 7, unitY + 1, 1, 1, 0x4FA3E0)
        }
    }

    /// The big rack in the closet: the busier the CPU, the faster and redder its lights.
    func drawCPURack() {
        let (x, y) = OfficePen.pixels(TilePoint(x: scene.map.cpuRack.x, y: scene.map.cpuRack.y))
        let load = min(max(scene.cpuLoad, 0), 1)
        let color: UInt32 = load < 0.5 ? 0x5BD96A : (load < 0.8 ? 0xF2B33D : 0xF2545B)
        pen.fill(x + 1, y - 8, 30, 38, 0x20242C)
        pen.fill(x + 1, y - 8, 30, 2, 0x343A46)
        let rate = 1.5 + load * 12
        for unit in 0..<6 {
            let unitY = y - 4 + Double(unit * 5)
            pen.fill(x + 4, unitY, 24, 4, 0x15181E)
            for light in 0..<4 {
                let isOn = sin(time * rate + Double(unit) * 1.3 + Double(light) * 0.7) > 0.4 - load
                pen.fill(x + 6 + Double(light * 3), unitY + 1, 2, 2, isOn ? color : 0x2A2E36)
            }
            pen.fill(x + 20, unitY + 1, 6, 1, 0x2E333D)
            pen.fill(x + 20, unitY + 3, 6, 1, 0x2E333D)
        }
    }

    /// Water level is used memory; it bubbles under pressure and drips when memory is critical.
    func drawWaterCooler() {
        let (x, y) = OfficePen.pixels(scene.map.waterCooler)
        let used = scene.memory?.usedFraction ?? 0
        pen.fill(x + 3, y + 4, 10, 11, 0xE7E9EC)
        pen.fill(x + 11, y + 4, 2, 11, 0xC9CDD3)
        pen.fill(x + 6, y + 8, 4, 2, 0x5B6473)
        pen.fill(x + 3, y - 8, 10, 12, 0xBFE3F7, opacity: 0.55)
        let level = (11 * used).rounded()
        pen.fill(x + 4, y - 7 + (11 - level), 8, level, 0x4BA3E3, opacity: 0.85)
        pen.fill(x + 6, y - 10, 4, 2, 0x2F6FA8)
        drawPressure(x, y)
    }

    private func drawPressure(_ x: Double, _ y: Double) {
        guard let pressure = scene.memory?.pressure, pressure != .normal else { return }
        for bubble in 0..<3 {
            let rise = (time * 6 + Double(bubble) * 4).truncatingRemainder(dividingBy: 10)
            pen.fill(x + 5 + Double(bubble * 2), y + 3 - rise, 1, 1, 0xFFFFFF)
        }
        if pressure == .critical {
            pen.fill(x + 7, y + 10 + (time * 8).truncatingRemainder(dividingBy: 5), 1, 2, 0x4BA3E3)
        }
    }

    /// Lit up with dancing bars and drifting notes while music plays; dark otherwise.
    func drawJukebox() {
        let (x, y) = OfficePen.pixels(scene.map.jukebox)
        let isPlaying = scene.isMusicPlaying
        pen.fill(x + 2, y - 8, 12, 23, 0x6B3A2E)
        pen.fill(x + 2, y - 8, 12, 2, 0x8A4E3D)
        pen.fill(x + 3, y - 6, 10, 2, isPlaying ? 0xF2B33D : 0x5A4A3A, opacity: isPlaying ? 0.7 + 0.3 * sin(time * 4) : 1)
        pen.fill(x + 4, y - 3, 8, 7, 0x1B1E25)
        pen.fill(x + 4, y + 6, 8, 6, 0x4A2A22)
        for slot in 0..<3 { pen.fill(x + 5, y + 7 + Double(slot * 2), 6, 1, 0x2E1A15) }
        pen.fill(x + 3, y + 15, 10, 1, 0x000000, opacity: 0.25)
        guard isPlaying else { return }
        drawVisualizer(x + 4, y + 4)
        drawNotes(x, y)
    }

    private func drawVisualizer(_ left: Double, _ bottom: Double) {
        let colors: [UInt32] = [0x5BD96A, 0x4FA3E0, 0xF2B33D, 0xF2545B]
        for bar in 0..<4 {
            let level = 0.5 + 0.5 * sin(time * (5 + Double(bar) * 1.3) + Double(bar) * 2.1)
            let height = (1 + 5 * level).rounded()
            pen.fill(left + Double(bar * 2), bottom - height, 1, height, colors[bar])
        }
    }

    private func drawNotes(_ x: Double, _ y: Double) {
        for note in 0..<2 {
            let rise = (time * 5 + Double(note) * 7).truncatingRemainder(dividingBy: 14)
            let drift = sin(time * 2 + Double(note) * 3) * 2
            let noteX = x + 6 + Double(note * 5) + drift
            let noteY = y - 10 - rise
            pen.fill(noteX, noteY, 2, 2, 0xEDEDED, opacity: 1 - rise / 14)
            pen.fill(noteX + 1, noteY - 3, 1, 3, 0xEDEDED, opacity: 1 - rise / 14)
        }
    }

    func drawPlant(_ tile: TilePoint) {
        let (x, y) = OfficePen.pixels(tile)
        pen.ellipse(x + 2, y - 2, 8, 9, .init(hex: 0x3E7F49))
        pen.ellipse(x + 6, y - 4, 8, 10, .init(hex: 0x4E9F5B))
        pen.fill(x + 4, y + 6, 8, 7, 0xB5653A)
        pen.fill(x + 4, y + 6, 8, 1, 0xCF7C4E)
    }
}
