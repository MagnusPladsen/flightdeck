// Draws the Flightdeck app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit
import SwiftUI

let orange = Color(red: 1, green: 0.42, blue: 0.08)
let ink = Color(white: 0.07)
let paper = Color(red: 0.95, green: 0.93, blue: 0.89)

/// Right half of a fighter jet seen from above, nose to tail; mirrored by `Symmetric`.
let fighter: [CGPoint] = [
    .init(x: 0, y: -340), .init(x: 34, y: -230), .init(x: 46, y: -90), .init(x: 320, y: 90), .init(x: 320, y: 140),
    .init(x: 60, y: 110), .init(x: 58, y: 200), .init(x: 170, y: 290), .init(x: 170, y: 325), .init(x: 40, y: 300), .init(x: 0, y: 300),
]

struct Symmetric: Shape {
    var half: [CGPoint]
    func path(in rect: CGRect) -> Path {
        let right = half.map { CGPoint(x: rect.midX + $0.x, y: rect.midY + $0.y) }
        let left = half.reversed().map { CGPoint(x: rect.midX - $0.x, y: rect.midY + $0.y) }
        var path = Path()
        path.addLines(right + left)
        path.closeSubpath()
        return path
    }
}

/// Three jets in a V: an orange lead and two paper wingmen on black.
struct FlightdeckIcon: View {
    var body: some View {
        ZStack {
            ink
            jet(orange, scale: 0.5).offset(y: -125)
            jet(paper, scale: 0.45).offset(x: -185, y: 125)
            jet(paper, scale: 0.45).offset(x: 185, y: 125)
        }
        .frame(width: 824, height: 824)
        .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
        .frame(width: 1024, height: 1024)
    }

    private func jet(_ color: Color, scale: CGFloat) -> some View {
        Symmetric(half: fighter).fill(color).frame(width: 824, height: 824).scaleEffect(scale)
    }
}

@MainActor
func writeIcon() throws {
    let renderer = ImageRenderer(content: FlightdeckIcon())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("Could not render icon") }
    let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = size * scale
            let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            try png(of: image, pixels: pixels).write(to: iconset.appendingPathComponent(name))
        }
    }
    try png(of: image, pixels: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
    try iconutil.run()
    iconutil.waitUntilExit()
    print("Wrote Resources/AppIcon.icns")
}

func png(of image: CGImage, pixels: Int) throws -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSImage(cgImage: image, size: .zero).draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try MainActor.assumeIsolated { try writeIcon() }
