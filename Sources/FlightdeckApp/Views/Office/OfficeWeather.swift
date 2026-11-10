import MonitorCore
import SwiftUI

/// The light and weather outside, for the office windows and the lamps.
struct OfficeOutside {
    /// 1 in daylight, 0 at night.
    var daylight: Double
    /// How orange the sky is, around sunrise and sunset.
    var glow: Double
    var condition: OfficeWeatherCondition

    static let noon = OfficeOutside(daylight: 1, glow: 0, condition: .clear)

    static func at(_ date: Date, sunrise: Date?, sunset: Date?, condition: OfficeWeatherCondition) -> OfficeOutside {
        let typical = OfficeSky.typicalDay(around: date)
        let rise = sunrise.map { Calendar.current.isDate($0, inSameDayAs: date) ? $0 : typical.sunrise } ?? typical.sunrise
        let set = sunset.map { Calendar.current.isDate($0, inSameDayAs: date) ? $0 : typical.sunset } ?? typical.sunset
        return OfficeOutside(daylight: OfficeSky.daylight(at: date, sunrise: rise, sunset: set),
                             glow: OfficeSky.sunsetGlow(at: date, sunrise: rise, sunset: set), condition: condition)
    }

    /// `FLIGHTDECK_OFFICE_TIME=night|dusk|day` pins the time of day in demo mode, for screenshots.
    @MainActor static var demoOverride: OfficeOutside? {
        guard DemoData.isEnabled, let time = ProcessInfo.processInfo.environment["FLIGHTDECK_OFFICE_TIME"] else { return nil }
        switch time {
        case "night": return OfficeOutside(daylight: 0, glow: 0, condition: DemoData.officeWeather)
        case "dusk": return OfficeOutside(daylight: 0.45, glow: 0.9, condition: DemoData.officeWeather)
        default: return OfficeOutside(daylight: 1, glow: 0, condition: DemoData.officeWeather)
        }
    }
}

/// Windows along the outside walls showing the sky, and the dim and the desk lamps after dark.
struct OfficeWindowsLayer {
    let scene: OfficeScene
    let outside: OfficeOutside
    let pen: OfficePen
    let time: Double

    /// Every third tile of each room's outer wall, away from the corners.
    private var windowTiles: [TilePoint] {
        scene.map.rooms.flatMap { room in
            let row = room.isAboveHallway ? room.rect.y : room.rect.maxY - 1
            return stride(from: room.rect.x + 2, to: room.rect.maxX - 2, by: 3).map { TilePoint(x: $0, y: row) }
                .filter { scene.map.grid[$0] == .wall }
        }
    }

    func drawWindows() {
        for (index, tile) in windowTiles.enumerated() { drawWindow(tile, index: index) }
    }

    private func drawWindow(_ tile: TilePoint, index: Int) {
        let (x, y) = OfficePen.pixels(tile)
        pen.fill(x + 1, y + 3, 14, 11, 0x2B2F38)
        let glass = pen.rect(x + 2, y + 4, 12, 9)
        var clipped = pen.context
        clipped.clip(to: Path(glass))
        clipped.fill(Path(glass), with: .linearGradient(Gradient(colors: skyColors), startPoint: CGPoint(x: glass.midX, y: glass.minY), endPoint: CGPoint(x: glass.midX, y: glass.maxY)))
        var windowPen = pen
        windowPen.context = clipped
        drawSkyDetail(windowPen, x: x + 2, y: y + 4, index: index)
        pen.fill(x + 7.5, y + 4, 1, 9, 0x2B2F38)
        pen.fill(x + 2, y + 8, 12, 1, 0x2B2F38, opacity: 0.8)
        pen.fill(x + 1, y + 13, 14, 1, 0x8A93A3)
    }

    private var skyColors: [Color] {
        let night = (Color(hex: 0x0B1230), Color(hex: 0x1D2A52))
        let day = outside.condition == .clear ? (Color(hex: 0x5FB0F0), Color(hex: 0xBFE3FA)) : (Color(hex: 0x8C98A8), Color(hex: 0xC3CAD3))
        let sunset = (Color(hex: 0x6E5BA8), Color(hex: 0xF5A05F))
        let base = (mix(night.0, day.0, outside.daylight), mix(night.1, day.1, outside.daylight))
        let warmth = outside.glow * (outside.condition == .clear ? 0.85 : 0.4)
        return [mix(base.0, sunset.0, warmth), mix(base.1, sunset.1, warmth)]
    }

    private func drawSkyDetail(_ glass: OfficePen, x: Double, y: Double, index: Int) {
        if outside.daylight < 0.4, outside.condition == .clear { drawStars(glass, x: x, y: y, index: index) }
        if outside.daylight < 0.4, index % 4 == 1, outside.condition != .storm { glass.ellipse(x + 7, y + 1.5, 3, 3, Color(hex: 0xF4F1DE).opacity(0.9)) }
        if outside.daylight >= 0.4, outside.condition == .clear, index % 5 == 2 { glass.ellipse(x + 7, y + 1, 3.5, 3.5, Color(hex: 0xFFE38A)) }
        switch outside.condition {
        case .cloudy, .rain, .storm: drawClouds(glass, x: x, y: y, index: index)
        case .fog: glass.fill(x, y, 12, 9, 0xE6E9EE, opacity: 0.45)
        default: break
        }
        switch outside.condition {
        case .rain, .storm: drawRain(glass, x: x, y: y, index: index)
        case .snow: drawSnow(glass, x: x, y: y, index: index)
        default: break
        }
        if outside.condition == .storm, isLightning(index: index) { glass.fill(x, y, 12, 9, 0xFFFFFF, opacity: 0.75) }
    }

    private func drawStars(_ glass: OfficePen, x: Double, y: Double, index: Int) {
        for star in 0..<4 {
            let seed = index * 7 + star * 13
            let twinkle = 0.5 + 0.5 * sin(time * 2 + Double(seed))
            glass.fill(x + Double((seed * 5) % 11), y + Double((seed * 3) % 7), 0.8, 0.8, 0xFFFFFF, opacity: 0.4 + 0.5 * twinkle)
        }
    }

    private func drawClouds(_ glass: OfficePen, x: Double, y: Double, index: Int) {
        let drift = (time * 0.8 + Double(index) * 4).truncatingRemainder(dividingBy: 20) - 6
        let shade = Color(hex: outside.daylight > 0.4 ? 0xEEF1F5 : 0x3A4360).opacity(0.85)
        glass.ellipse(x + drift, y + 1, 7, 3.5, shade)
        glass.ellipse(x + drift + 3, y, 5, 3, shade)
    }

    private func drawRain(_ glass: OfficePen, x: Double, y: Double, index: Int) {
        let color = Color(hex: 0xC8DDF2).opacity(outside.daylight > 0.4 ? 0.85 : 0.55)
        for drop in 0..<6 {
            let fall = (time * 14 + Double(drop * 5 + index * 3)).truncatingRemainder(dividingBy: 11) - 2
            let left = x + Double((drop * 7 + index) % 12)
            var path = Path()
            path.move(to: glass.point(left, y + fall))
            path.addLine(to: glass.point(left - 0.8, y + fall + 2.2))
            glass.context.stroke(path, with: .color(color), lineWidth: 0.5 * pen.camera.scale)
        }
    }

    private func drawSnow(_ glass: OfficePen, x: Double, y: Double, index: Int) {
        for flake in 0..<6 {
            let fall = (time * 3 + Double(flake * 4 + index * 2)).truncatingRemainder(dividingBy: 11) - 1
            let sway = sin(time * 1.5 + Double(flake)) * 0.8
            glass.fill(x + Double((flake * 5 + index) % 12) + sway, y + fall, 1, 1, 0xFFFFFF, opacity: 0.9)
        }
    }

    /// A flash now and then, at slightly different moments in each window.
    private func isLightning(index: Int) -> Bool {
        let cycle = (time + Double(index % 3) * 0.05).truncatingRemainder(dividingBy: 7)
        return cycle < 0.08 || (cycle > 0.2 && cycle < 0.26)
    }

    /// The room darkens after sunset; desks with an agent keep a warm lamp on.
    func drawNight() {
        let darkness = (1 - outside.daylight) * 0.5 + (outside.condition == .clear ? 0 : 0.06 * outside.daylight)
        guard darkness > 0.01 else { return }
        let width = Double(scene.map.grid.width) * OfficeCamera.tilePixels
        let height = Double(scene.map.grid.height) * OfficeCamera.tilePixels
        pen.context.fill(Path(pen.rect(0, 0, width, height)), with: .color(Color(hex: 0x0A1030).opacity(darkness)))
        guard outside.daylight < 0.6 else { return }
        var lamps = pen
        lamps.context.blendMode = .plusLighter
        let strength = (0.6 - outside.daylight) / 0.6
        for desk in scene.map.desks where desk.agentPID != nil {
            let (deskX, deskY) = OfficePen.pixels(desk.desk)
            let center = lamps.point(deskX + 16, deskY + 6)
            let radius = 26 * pen.camera.scale
            lamps.context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                               with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC872).opacity(0.32 * strength), .clear]), center: center, startRadius: 0, endRadius: radius))
        }
    }

    private func mix(_ first: Color, _ second: Color, _ amount: Double) -> Color {
        let a = NSColor(first).usingColorSpace(.sRGB) ?? .black
        let b = NSColor(second).usingColorSpace(.sRGB) ?? .black
        let t = min(max(amount, 0), 1)
        return Color(red: a.redComponent + (b.redComponent - a.redComponent) * t, green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                     blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t)
    }
}
