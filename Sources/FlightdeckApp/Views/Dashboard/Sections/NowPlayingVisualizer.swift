import MonitorCore
import SwiftUI

/// How the visualiser draws, picked to suit each layout.
enum VisualizerStyle {
    case bars, segments, waveform, rings

    init(layout: DashboardLayout) {
        switch layout {
        case .terminal, .cockpit, .mission: self = .segments
        case .editorial, .zen, .timeline: self = .waveform
        case .neon, .glass: self = .rings
        default: self = .bars
        }
    }
}

/// Live bars for the playing track: real levels from the system audio tap when it is on and
/// hearing something, otherwise a calm animation that follows play and pause (also what demo
/// mode shows when nothing really plays).
struct NowPlayingVisualizer: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var track: NowPlayingTrack
    var style: VisualizerStyle
    @State private var feed = SpectrumFeed()
    /// Keeps frames coming for a moment after pausing so the bars can fall instead of freezing.
    @State private var isSettling = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !track.isPlaying && !isSettling)) { context in
            let levels = feed.levels(at: context.date, track: track, audio: store.nowPlaying.audio)
            Canvas { canvas, size in
                VisualizerDrawing(levels: levels, size: size, theme: theme).draw(style, in: &canvas)
            }
        }
        .onAppear { store.nowPlaying.visualizerAppeared() }
        .onDisappear { store.nowPlaying.visualizerDisappeared() }
        .task(id: track.isPlaying) { await settleAfterPause() }
        .accessibilityHidden(true)
    }

    private func settleAfterPause() async {
        guard !track.isPlaying else { return }
        isSettling = true
        try? await Task.sleep(for: .seconds(1.5))
        isSettling = false
    }
}

/// Smoothed band levels from whichever source is live.
@MainActor
final class SpectrumFeed {
    static let bandCount = 32
    private var smoother = SpectrumSmoother(bandCount: bandCount)

    func levels(at date: Date, track: NowPlayingTrack, audio: SystemAudioTap) -> [Double] {
        smoother.update(with: target(at: date, track: track, audio: audio))
    }

    private func target(at date: Date, track: NowPlayingTrack, audio: SystemAudioTap) -> [Double] {
        let samples = audio.recentSamples()
        if track.isPlaying, audio.isRunning, !AudioSilence.isSilent(samples) {
            return SpectrumAnalyzer(bandCount: Self.bandCount, sampleRate: audio.sampleRate).bands(for: samples)
        }
        let synthetic = SyntheticSpectrum(bandCount: Self.bandCount, track: track.title)
        return synthetic.bands(at: date.timeIntervalSinceReferenceDate, energy: track.isPlaying ? 0.85 : 0)
    }
}

/// Draws band levels into a canvas in the theme's primary, secondary and accent colours.
private struct VisualizerDrawing {
    var levels: [Double]
    var size: CGSize
    var theme: Theme

    private var shading: GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [theme.primary, theme.secondary, theme.accent]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0))
    }

    func draw(_ style: VisualizerStyle, in canvas: inout GraphicsContext) {
        switch style {
        case .bars: drawBars(in: &canvas)
        case .segments: drawSegments(in: &canvas)
        case .waveform: drawWaveform(in: &canvas)
        case .rings: drawRings(in: &canvas)
        }
    }

    private func drawBars(in canvas: inout GraphicsContext) {
        let slot = size.width / CGFloat(levels.count)
        var bars = Path()
        for (index, level) in levels.enumerated() {
            let height = max(CGFloat(level) * size.height, slot * 0.6)
            let rect = CGRect(x: CGFloat(index) * slot + slot * 0.18, y: size.height - height, width: slot * 0.64, height: height)
            bars.addRoundedRect(in: rect, cornerSize: CGSize(width: slot * 0.32, height: slot * 0.32))
        }
        canvas.fill(bars, with: shading)
    }

    /// LED-style columns of cells, unlit cells kept faintly visible.
    private func drawSegments(in canvas: inout GraphicsContext) {
        let rows = 9
        let slot = size.width / CGFloat(levels.count)
        let cell = size.height / CGFloat(rows)
        var lit = Path(), unlit = Path()
        for (index, level) in levels.enumerated() {
            let litCount = Int((level * Double(rows)).rounded())
            for row in 0..<rows {
                let rect = CGRect(x: CGFloat(index) * slot + 1, y: size.height - CGFloat(row + 1) * cell + 1, width: slot - 2, height: cell - 2)
                if row < litCount { lit.addRect(rect) } else { unlit.addRect(rect) }
            }
        }
        canvas.fill(unlit, with: .color(theme.overlay.opacity(0.6)))
        canvas.fill(lit, with: shading)
    }

    /// A smooth band mirrored around the centre line.
    private func drawWaveform(in canvas: inout GraphicsContext) {
        let middle = size.height / 2
        let step = size.width / CGFloat(max(levels.count - 1, 1))
        let top = levels.enumerated().map { CGPoint(x: CGFloat($0.offset) * step, y: middle - CGFloat($0.element) * middle * 0.95 - 0.5) }
        let bottom = top.reversed().map { CGPoint(x: $0.x, y: 2 * middle - $0.y) }
        var area = Path()
        area.move(to: CGPoint(x: 0, y: middle))
        Self.addSmoothLine(through: top, to: &area)
        Self.addSmoothLine(through: bottom, to: &area)
        area.closeSubpath()
        canvas.fill(area, with: shading)
        canvas.opacity = 0.35
        canvas.stroke(Path { $0.move(to: CGPoint(x: 0, y: middle)); $0.addLine(to: CGPoint(x: size.width, y: middle)) }, with: .color(theme.foreground), lineWidth: 0.5)
    }

    /// Rounds the corners between points with quadratic curves through their midpoints.
    private static func addSmoothLine(through points: [CGPoint], to path: inout Path) {
        guard var previous = points.first else { return }
        path.addLine(to: previous)
        for point in points.dropFirst() {
            path.addQuadCurve(to: CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2), control: previous)
            previous = point
        }
        path.addLine(to: previous)
    }

    /// A glowing ring of rays in the middle, with mirrored bars fading out to either side.
    private func drawRings(in canvas: inout GraphicsContext) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let inner = size.height * 0.2
        canvas.addFilter(.shadow(color: theme.accent.opacity(0.6), radius: 5))
        drawRays(around: center, inner: inner, outer: size.height / 2 - 2, in: &canvas)
        canvas.stroke(Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)), with: .color(theme.accent.opacity(0.8)), lineWidth: 1.5)
        drawSideBars(from: center, gap: size.height / 2 + 10, in: &canvas)
    }

    private func drawRays(around center: CGPoint, inner: CGFloat, outer: CGFloat, in canvas: inout GraphicsContext) {
        let mirrored = levels + levels.reversed()
        var rays = Path()
        for (index, level) in mirrored.enumerated() {
            let angle = Double(index) / Double(mirrored.count) * 2 * .pi - .pi / 2
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let length = inner + 3 + CGFloat(level) * (outer - inner - 3)
            rays.move(to: CGPoint(x: center.x + direction.x * (inner + 3), y: center.y + direction.y * (inner + 3)))
            rays.addLine(to: CGPoint(x: center.x + direction.x * length, y: center.y + direction.y * length))
        }
        canvas.stroke(rays, with: .radialGradient(Gradient(colors: [theme.primary, theme.accent]), center: center, startRadius: inner, endRadius: outer),
                      style: StrokeStyle(lineWidth: max(2 * .pi * inner / CGFloat(mirrored.count) * 0.55, 1.5), lineCap: .round))
    }

    private func drawSideBars(from center: CGPoint, gap: CGFloat, in canvas: inout GraphicsContext) {
        let slot = max((center.x - gap) / CGFloat(levels.count), 0)
        guard slot >= 2 else { return }
        var bars = Path()
        for (index, level) in levels.enumerated() {
            let height = max(CGFloat(level) * size.height * 0.8, 2)
            let offset = gap + CGFloat(index) * slot
            for x in [center.x + offset, center.x - offset - slot * 0.5] {
                bars.addRoundedRect(in: CGRect(x: x, y: center.y - height / 2, width: slot * 0.5, height: height), cornerSize: CGSize(width: slot * 0.25, height: slot * 0.25))
            }
        }
        canvas.opacity = 0.75
        canvas.fill(bars, with: .radialGradient(Gradient(colors: [theme.secondary, theme.primary.opacity(0.2)]), center: center, startRadius: gap, endRadius: center.x))
    }
}
