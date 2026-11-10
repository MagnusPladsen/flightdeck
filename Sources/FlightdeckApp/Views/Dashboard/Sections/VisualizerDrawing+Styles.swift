import SwiftUI

/// The newer visualiser styles: mirror, dot matrix, line, sunburst and ribbons.
extension VisualizerDrawing {
    /// Bars growing up and down from the centre line.
    func drawMirror(in canvas: inout GraphicsContext) {
        let slot = size.width / CGFloat(levels.count)
        let middle = size.height / 2
        var bars = Path()
        for (index, level) in levels.enumerated() {
            let half = max(CGFloat(level) * middle * 0.95, 1)
            bars.addRoundedRect(in: CGRect(x: CGFloat(index) * slot + slot * 0.2, y: middle - half, width: slot * 0.6, height: half * 2),
                                cornerSize: CGSize(width: slot * 0.3, height: slot * 0.3))
        }
        canvas.fill(bars, with: shading)
    }

    /// Columns of round dots, unlit ones faintly visible.
    func drawDotMatrix(in canvas: inout GraphicsContext) {
        let rows = 8
        let slot = size.width / CGFloat(levels.count)
        let cell = size.height / CGFloat(rows)
        let radius = min(slot, cell) * 0.32
        var lit = Path(), unlit = Path()
        for (index, level) in levels.enumerated() {
            let litCount = Int((level * Double(rows)).rounded())
            let x = CGFloat(index) * slot + slot / 2
            for row in 0..<rows {
                let y = size.height - (CGFloat(row) + 0.5) * cell
                let dot = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                if row < litCount { lit.addEllipse(in: dot) } else { unlit.addEllipse(in: dot) }
            }
        }
        canvas.fill(unlit, with: .color(theme.overlay.opacity(0.7)))
        canvas.fill(lit, with: shading)
    }

    /// One glowing line over the bands, with a fading fill beneath.
    func drawLine(in canvas: inout GraphicsContext) {
        let step = size.width / CGFloat(max(levels.count - 1, 1))
        let points = levels.enumerated().map { CGPoint(x: CGFloat($0.offset) * step, y: size.height - 2 - CGFloat($0.element) * (size.height - 4)) }
        var line = Path()
        line.move(to: points.first ?? .zero)
        Self.addSmoothLine(through: points, to: &line)
        var area = line
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        canvas.fill(area, with: .linearGradient(Gradient(colors: [colors.middle.opacity(0.35), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        canvas.addFilter(.shadow(color: colors.glow.opacity(0.7), radius: 4))
        canvas.stroke(line, with: shading, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
    }

    /// A fan of rays rising from the middle of the bottom edge, one per band and mirrored.
    func drawSunburst(in canvas: inout GraphicsContext) {
        let center = CGPoint(x: size.width / 2, y: size.height)
        let outer = min(size.height - 2, size.width / 2)
        let inner = outer * 0.22
        let mirrored = levels.reversed() + levels
        var rays = Path()
        for (index, level) in mirrored.enumerated() {
            let angle = Double.pi + (Double(index) + 0.5) / Double(mirrored.count) * .pi
            let length = inner + 3 + CGFloat(level) * (outer - inner - 3)
            rays.move(to: CGPoint(x: center.x + cos(angle) * (inner + 3), y: center.y + sin(angle) * (inner + 3)))
            rays.addLine(to: CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length))
        }
        canvas.addFilter(.shadow(color: colors.glow.opacity(0.5), radius: 4))
        canvas.stroke(rays, with: .radialGradient(Gradient(colors: colors.stops), center: center, startRadius: inner, endRadius: outer),
                      style: StrokeStyle(lineWidth: max(.pi * outer / CGFloat(mirrored.count) * 0.45, 2), lineCap: .round))
        var core = Path()
        core.addArc(center: center, radius: inner, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        canvas.fill(core, with: .color(colors.glow.opacity(0.8)))
    }

    /// Three translucent waves in the palette's colours, each a little out of step.
    func drawRibbons(in canvas: inout GraphicsContext) {
        let middle = size.height / 2
        let step = size.width / CGFloat(max(levels.count - 1, 1))
        let ribbonColors = colors.stops.isEmpty ? [colors.glow] : colors.stops
        for (layer, color) in ribbonColors.prefix(3).enumerated() {
            let shift = layer * 3
            let points = levels.indices.map { index in
                let level = levels[(index + shift) % levels.count]
                let direction: CGFloat = layer.isMultiple(of: 2) ? -1 : 1
                return CGPoint(x: CGFloat(index) * step, y: middle + direction * CGFloat(level) * middle * 0.9)
            }
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: 0, y: middle))
            Self.addSmoothLine(through: points, to: &ribbon)
            ribbon.addLine(to: CGPoint(x: size.width, y: middle))
            ribbon.closeSubpath()
            canvas.fill(ribbon, with: .color(color.opacity(0.45)))
        }
    }
}
