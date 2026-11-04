// Draws the Ignition app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit
import SwiftUI

let orange = Color(red: 1, green: 0.478, blue: 0.102)
let ink = Color(red: 0.906, green: 0.914, blue: 0.918)

struct IgnitionIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.10), .black], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(RadialGradient(colors: [orange.opacity(0.38), .clear], center: .init(x: 0.5, y: 0.62), startRadius: 0, endRadius: 420))
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 4)
            gauge
            Image(systemName: "bolt.fill")
                .font(.system(size: 330, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.4), orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: orange.opacity(0.9), radius: 40)
                .offset(y: 30)
        }
        .frame(width: 824, height: 824)
        .frame(width: 1024, height: 1024)
    }

    /// A 270° dial: a dim track and an orange reading.
    private var gauge: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(ink.opacity(0.16), style: StrokeStyle(lineWidth: 46, lineCap: .round))
            Circle().trim(from: 0, to: 0.52)
                .stroke(orange, style: StrokeStyle(lineWidth: 46, lineCap: .round))
                .shadow(color: orange.opacity(0.7), radius: 24)
        }
        .rotationEffect(.degrees(135))
        .frame(width: 600, height: 600)
        .offset(y: 30)
    }
}

@MainActor
func writeIcon() throws {
    let renderer = ImageRenderer(content: IgnitionIcon())
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
