import MonitorCore
import SwiftUI

/// Draws in art pixels (16 per tile) on the office canvas, so furniture code never thinks about zoom.
struct OfficePen {
    var context: GraphicsContext
    let camera: OfficeCamera

    func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
        CGRect(x: camera.originX + x * camera.scale, y: camera.originY + y * camera.scale, width: width * camera.scale, height: height * camera.scale)
    }

    func fill(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ hex: UInt32, opacity: Double = 1) {
        context.fill(Path(rect(x, y, width, height)), with: .color(Color(hex: hex).opacity(opacity)))
    }

    func ellipse(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Color) {
        context.fill(Path(ellipseIn: rect(x, y, width, height)), with: .color(color))
    }

    /// Draws a sprite with its bottom-centre at the given art-pixel point.
    func sprite(_ sprite: PixelSprite, palette: SpritePalette, bottomCenterX x: Double, bottomY y: Double, flipped: Bool = false) {
        let frame = rect(x - Double(sprite.width) / 2, y - Double(sprite.height), Double(sprite.width), Double(sprite.height))
        var context = context
        if flipped {
            context.translateBy(x: frame.midX, y: 0)
            context.scaleBy(x: -1, y: 1)
            context.translateBy(x: -frame.midX, y: 0)
        }
        context.draw(sprite.image(palette: palette), in: frame)
    }

    /// Screen point of an art-pixel position.
    func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: camera.originX + x * camera.scale, y: camera.originY + y * camera.scale)
    }

    /// Art pixels of a tile's top-left corner.
    static func pixels(_ tile: TilePoint) -> (x: Double, y: Double) {
        (Double(tile.x) * OfficeCamera.tilePixels, Double(tile.y) * OfficeCamera.tilePixels)
    }

    static func pixels(_ point: OfficePoint) -> (x: Double, y: Double) {
        (point.x * OfficeCamera.tilePixels, point.y * OfficeCamera.tilePixels)
    }
}
