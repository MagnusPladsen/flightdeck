import SwiftUI

/// The ten backdrop styles. Each stays faint at rest and brightens with the beat and the levels.
extension MusicBackdropPainter {
    private static let glowSpots: [(x: CGFloat, y: CGFloat)] = [(0.08, 0.05), (0.95, 0.4), (0.35, 1.0)]

    func drawGlows(strength: Double = 1) {
        for (index, spot) in Self.glowSpots.enumerated() {
            let center = CGPoint(x: size.width * spot.x, y: size.height * spot.y)
            radialGlow(at: center, radius: max(size.width, size.height) * 0.45 * (1 + 0.15 * energy),
                       color: party.color(index + party.beat), opacity: (0.1 + 0.22 * energy) * strength)
        }
    }

    /// Columns follow the spectrum, with a ripple running out from the middle on each beat.
    func drawDots() {
        let spacing: CGFloat = 26
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for x in stride(from: spacing / 2, to: size.width, by: spacing) {
            let share = Double(x / size.width)
            let level = band(at: share), color = color(at: share)
            for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                let ripple = max(0, sin(hypot(x - center.x, y - center.y) / 70 - motionTime * 5)) * energy
                let radius = 1.4 + 1.2 * ripple + 0.6 * level
                dot(at: CGPoint(x: x, y: y), radius: radius, color: color.opacity(0.14 + 0.35 * level + 0.35 * ripple))
            }
        }
    }

    /// Soft curtains drifting across the top, taller with louder bands.
    func drawAurora() {
        for layer in 0..<3 {
            var curtain = Path()
            curtain.move(to: .zero)
            for x in stride(from: 0, through: size.width, by: 12) {
                let share = Double(x / size.width)
                let sway = sin(share * 6 + motionTime * (0.6 + Double(layer) * 0.25) + Double(layer)) * 0.5 + 0.5
                curtain.addLine(to: CGPoint(x: x, y: size.height * (0.18 + 0.22 * sway + 0.25 * band(at: share))))
            }
            curtain.addLine(to: CGPoint(x: size.width, y: 0))
            curtain.closeSubpath()
            let color = party.color(layer + party.beat)
            context.fill(curtain, with: .linearGradient(Gradient(colors: [color.opacity(0.03), color.opacity(0.14 + 0.16 * energy)]),
                                                         startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.6)))
        }
    }

    /// Rings travelling out from the centre, brighter on the beat.
    func drawRipples() {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
        let reach = hypot(size.width, size.height) / 2
        for ring in 0..<6 {
            let progress = (motionTime * 0.12 + Double(ring) / 6).truncatingRemainder(dividingBy: 1)
            let radius = CGFloat(progress) * reach
            let opacity = (1 - progress) * (0.14 + 0.3 * energy)
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(party.color(ring + party.beat).opacity(opacity)), lineWidth: 2 + 4 * energy)
        }
    }

    /// A glow round the window's edges that breathes with the bass.
    func drawEdges() {
        let depth = min(size.width, size.height) * (0.12 + 0.1 * energy)
        let sides: [(CGRect, UnitPoint, UnitPoint)] = [
            (CGRect(x: 0, y: 0, width: size.width, height: depth), .top, .bottom),
            (CGRect(x: 0, y: size.height - depth, width: size.width, height: depth), .bottom, .top),
            (CGRect(x: 0, y: 0, width: depth, height: size.height), .leading, .trailing),
            (CGRect(x: size.width - depth, y: 0, width: depth, height: size.height), .trailing, .leading),
        ]
        for (index, side) in sides.enumerated() {
            let color = party.color(index + party.beat).opacity(0.14 + 0.24 * energy)
            context.fill(Path(side.0), with: .linearGradient(Gradient(colors: [color, .clear]),
                                                             startPoint: point(side.1, in: side.0), endPoint: point(side.2, in: side.0)))
        }
    }

    /// Stage lights sweeping up from the bottom edge.
    func drawBeams() {
        for beam in 0..<4 {
            let base = CGPoint(x: size.width * (0.15 + 0.23 * CGFloat(beam)), y: size.height + 20)
            let angle = sin(motionTime * 0.5 + Double(beam) * 1.7) * 0.45
            let length = size.height * 1.2
            let tip = CGPoint(x: base.x + CGFloat(sin(angle)) * length, y: base.y - CGFloat(cos(angle)) * length)
            let spread = size.width * 0.07
            var cone = Path()
            cone.move(to: base)
            cone.addLine(to: CGPoint(x: tip.x - spread, y: tip.y))
            cone.addLine(to: CGPoint(x: tip.x + spread, y: tip.y))
            cone.closeSubpath()
            let color = party.color(beam + party.beat)
            context.fill(cone, with: .linearGradient(Gradient(colors: [color.opacity(0.12 + 0.2 * energy), .clear]), startPoint: base, endPoint: tip))
        }
    }

    /// The spectrum as tall faint bars along the bottom of the window.
    func drawSkyline() {
        let count = max(party.levels.count, 1)
        let slot = size.width / CGFloat(count)
        for index in 0..<count {
            let share = Double(index) / Double(count)
            let height = size.height * (0.04 + 0.35 * band(at: share))
            let rect = CGRect(x: CGFloat(index) * slot + slot * 0.15, y: size.height - height, width: slot * 0.7, height: height)
            let color = color(at: share)
            context.fill(Path(rect), with: .linearGradient(Gradient(colors: [color.opacity(0.22 + 0.18 * energy), color.opacity(0)]),
                                                          startPoint: CGPoint(x: rect.midX, y: rect.maxY), endPoint: CGPoint(x: rect.midX, y: rect.minY)))
        }
    }

    /// Scattered points that twinkle with their band and flare on the beat.
    func drawStars() {
        var generator = SeededGenerator(seed: 7)
        for star in 0..<160 {
            let x = CGFloat(generator.next()) * size.width
            let y = CGFloat(generator.next()) * size.height
            let share = Double(x / max(size.width, 1))
            let twinkle = sin(motionTime * 2 + Double(star)) * 0.5 + 0.5
            let brightness = min(1, 0.2 + 0.5 * band(at: share) * twinkle + 0.4 * energy * Double(generator.next()))
            dot(at: CGPoint(x: x, y: y), radius: 1.2 + 2 * CGFloat(brightness), color: color(at: share).opacity(brightness))
        }
    }

    /// Thin grid lines that light up column by column with the spectrum.
    func drawGrid() {
        let spacing: CGFloat = 48
        for x in stride(from: 0, through: size.width, by: spacing) {
            let share = Double(x / max(size.width, 1))
            context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                           with: .color(color(at: share).opacity(0.08 + 0.3 * band(at: share))), lineWidth: 1.2)
        }
        for y in stride(from: 0, through: size.height, by: spacing) {
            context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                           with: .color(party.color(party.beat).opacity(0.07 + 0.18 * energy)), lineWidth: 1.2)
        }
    }

    /// A wide, soft waveform across the middle of the window.
    func drawWave() {
        let middle = size.height * 0.55
        for layer in 0..<2 {
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: size.height))
            for x in stride(from: 0, through: size.width, by: 10) {
                let share = Double(x / size.width)
                let swell = sin(share * 9 + motionTime * 1.2 + Double(layer) * 2) * (40 + 120 * averageLevel)
                wave.addLine(to: CGPoint(x: x, y: middle + CGFloat(swell) - CGFloat(band(at: share)) * 80))
            }
            wave.addLine(to: CGPoint(x: size.width, y: size.height))
            wave.closeSubpath()
            context.fill(wave, with: .color(party.color(layer + party.beat).opacity(0.09 + 0.14 * energy)))
        }
    }

    private func radialGlow(at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(Gradient(colors: [color.opacity(opacity), color.opacity(0)]), center: center, startRadius: 0, endRadius: radius))
    }

    private func dot(at center: CGPoint, radius: CGFloat, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    private func point(_ unit: UnitPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * unit.x, y: rect.minY + rect.height * unit.y)
    }
}

/// Same sequence every frame, so stars keep their places.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}
