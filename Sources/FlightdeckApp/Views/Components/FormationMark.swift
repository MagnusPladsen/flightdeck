import SwiftUI

/// The app icon's three-jet formation, drawn small for the sidebar: an accent lead and two wingmen.
struct FormationMark: View {
    var lead: Color
    var wingmen: Color

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 824
            draw(lead, scale: 0.5 * unit, center: CGPoint(x: size.width / 2, y: size.height / 2 - 125 * unit), in: &context)
            draw(wingmen, scale: 0.45 * unit, center: CGPoint(x: size.width / 2 - 185 * unit, y: size.height / 2 + 125 * unit), in: &context)
            draw(wingmen, scale: 0.45 * unit, center: CGPoint(x: size.width / 2 + 185 * unit, y: size.height / 2 + 125 * unit), in: &context)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Right half of a jet seen from above, nose to tail, in the 824pt icon's units; mirrored to draw.
    private static let fighter: [CGPoint] = [
        .init(x: 0, y: -340), .init(x: 34, y: -230), .init(x: 46, y: -90), .init(x: 320, y: 90), .init(x: 320, y: 140),
        .init(x: 60, y: 110), .init(x: 58, y: 200), .init(x: 170, y: 290), .init(x: 170, y: 325), .init(x: 40, y: 300), .init(x: 0, y: 300),
    ]

    private func draw(_ color: Color, scale: CGFloat, center: CGPoint, in context: inout GraphicsContext) {
        let right = Self.fighter.map { CGPoint(x: center.x + $0.x * scale, y: center.y + $0.y * scale) }
        let left = Self.fighter.reversed().map { CGPoint(x: center.x - $0.x * scale, y: center.y + $0.y * scale) }
        var path = Path()
        path.addLines(right + left)
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }
}
