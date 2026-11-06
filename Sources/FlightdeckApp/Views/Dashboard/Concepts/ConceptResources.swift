import MonitorCore
import SwiftUI

/// The resources section in the form each layout was designed with.
struct LayoutResources: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout

    var body: some View {
        let readings = ResourceReading.all(store: store, theme: theme)
        switch layout {
        case .ignition: RingGauges(readings: readings, chrome: .plain)
        case .macOS: RingGauges(readings: readings, chrome: .card)
        case .neon: RingGauges(readings: readings, chrome: .glow)
        case .terminal: TextBarResources(readings: readings)
        case .cockpit: LEDResources(readings: readings)
        case .mission: TelemetryResources(readings: readings)
        case .bento: BentoResources(readings: readings)
        case .editorial: NumeralResources(readings: readings)
        case .glass: BigNumberResources(readings: readings, weight: .heavy)
        case .zen: BigNumberResources(readings: readings, weight: .light)
        case .timeline: TrendList(readings: readings)
        default: ResourceStrip()
        }
    }
}

/// "Customize" for the concept forms, which leave out the move-to-sidebar button.
private struct CustomizeResourcesButton: View {
    @Environment(MonitorStore.self) private var store
    @State private var isCustomizing = false

    var body: some View {
        Button("Customize") { isCustomizing = true }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .opacity(0.6)
            .popover(isPresented: $isCustomizing, arrowEdge: .bottom) {
                OptionChecklist(
                    title: "Show resources",
                    options: OverviewResource.allCases,
                    label: \.customizeTitle,
                    isOn: { store.settings.overviewResources.contains($0) },
                    setOn: { resource, isOn in
                        store.settings.overviewResources = AppSettings.updating(store.settings.overviewResources, with: resource, shown: isOn)
                    }
                )
                .padding(16)
                .frame(minWidth: 220, alignment: .leading)
            }
    }
}

/// Section title with the customize button at the far end. Inside a collapsible section the
/// title also folds the section away.
struct ConceptHeading: View {
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout
    @Environment(\.sectionCollapse) private var collapse
    var title: String
    var count: Int?
    var showsCustomize = false
    /// Muted text after the title, such as what plays in a collapsed now-playing section.
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let collapse {
                Button(action: collapse.toggle) { titleRow(chevron: collapse.isCollapsed ? "chevron.right" : "chevron.down") }
                    .buttonStyle(.plain)
                    .help(collapse.isCollapsed ? "Expand" : "Collapse")
            } else {
                titleRow(chevron: nil)
            }
            Spacer()
            if showsCustomize { CustomizeResourcesButton() }
        }
    }

    private func titleRow(chevron: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let chevron {
                Image(systemName: chevron).font(.system(size: 10, weight: .bold)).foregroundStyle(theme.muted).frame(width: 12)
            }
            Text(layout.style.uppercaseLabels ? title.uppercased() : title)
                .font(.system(size: layout.style.uppercaseLabels ? 12 : 15, weight: .bold))
                .tracking(layout.style.uppercaseLabels ? 1.4 : 0)
                .foregroundStyle(layout.style.uppercaseLabels ? theme.muted : theme.foreground)
            if let count { Text("\(count)").font(.system(size: 13, weight: .medium)).foregroundStyle(theme.muted) }
            if let detail { Text(detail).font(.system(size: 13)).foregroundStyle(theme.muted).lineLimit(1) }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Ring gauges (macOS, Neon)

struct RingGauge: View {
    @Environment(\.theme) private var theme
    var fraction: Double
    var color: Color
    var label: String
    var glows = false
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            Circle().stroke(theme.overlay, lineWidth: size * 0.105)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.105, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glows ? color.opacity(0.7) : .clear, radius: 8)
            Text(label).font(.system(size: size * 0.22, weight: .bold).monospacedDigit())
        }
        .frame(width: size, height: size)
        .animation(.smooth, value: fraction)
    }
}

private struct RingGauges: View {
    enum Chrome { case plain, card, glow }

    @Environment(\.theme) private var theme
    var readings: [ResourceReading]
    var chrome: Chrome
    @State private var width: CGFloat = 0

    var body: some View {
        let fit = RingFit(count: readings.count, width: width, cellPadding: chrome == .plain ? 0 : 28)
        VStack(alignment: .leading, spacing: 14) {
            if chrome == .plain {
                HStack {
                    ConceptHeading(title: "System")
                    ResourceControls(moveTitle: "Send to sidebar", moveImage: "sidebar.right")
                }
                Hairline()
            } else {
                ConceptHeading(title: "System", showsCustomize: true)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: RingFit.gap, alignment: .leading), count: fit.columns), alignment: .leading, spacing: RingFit.gap) {
                ForEach(readings) { cell($0, ringSize: fit.ringSize) }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .padding(.vertical, chrome == .plain ? 6 : 0)
            if chrome == .plain { Hairline() }
        }
    }

    private func cell(_ reading: ResourceReading, ringSize: CGFloat) -> some View {
        HStack(spacing: 14) {
            RingGauge(fraction: reading.fraction ?? 0, color: ringColor(reading), label: reading.value, glows: chrome == .glow, size: ringSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.shortTitle ?? reading.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Group {
                    if let agentName = reading.agentName { Text(agentName).lineLimit(1) }
                    Text(reading.detail).lineLimit(reading.agentName == nil ? 2 : 1)
                }
                .minimumScaleFactor(0.85)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(chrome == .plain ? 0 : 14)
        .background(theme.overlay.opacity(chrome == .card ? 0.45 : 0), in: RoundedRectangle(cornerRadius: chrome == .glow ? 0 : 12))
        .overlay { if chrome == .glow { Rectangle().strokeBorder(ringColor(reading).opacity(0.6)).shadow(color: ringColor(reading).opacity(0.35), radius: 11) } }
        .help(reading.agentName.map { "\($0) \(reading.shortTitle ?? ""), \(reading.detail)" } ?? "")
    }

    /// Neon gives each gauge its own colour; the others colour limits by how full they are and leave CPU and memory plain.
    private func ringColor(_ reading: ResourceReading) -> Color {
        switch chrome {
        case .glow:
            let palette = [theme.primary, theme.accent, theme.success, theme.warning, theme.secondary, theme.info]
            let index = readings.firstIndex { $0.id == reading.id } ?? 0
            return palette[index % palette.count]
        case .plain where reading.id == .cpu || reading.id == .memory:
            return theme.foreground
        default:
            return reading.fraction.map { UsageLevel.color(forFraction: $0, in: theme) } ?? theme.primary
        }
    }
}

/// Ring size and column count: rings shrink to keep every reading on one row,
/// and once they would go below the minimum the readings wrap into even rows.
struct RingFit {
    static let gap: CGFloat = 16
    static let maximumRing: CGFloat = 76
    static let minimumRing: CGFloat = 48
    /// Room the title and detail need beside the ring, plus the spacing between them.
    static let labelWidth: CGFloat = 136

    let columns: Int
    let ringSize: CGFloat

    init(count: Int, width: CGFloat, cellPadding: CGFloat) {
        let count = max(count, 1)
        let room = { (columns: Int) in (width - Self.gap * CGFloat(columns - 1)) / CGFloat(columns) - cellPadding - Self.labelWidth }
        guard width > 0, room(count) < Self.minimumRing else {
            columns = count
            ringSize = width > 0 ? min(Self.maximumRing, room(count)) : Self.maximumRing
            return
        }
        let minimumCell = Self.minimumRing + Self.labelWidth + cellPadding
        let maximumColumns = max(1, Int((width + Self.gap) / (minimumCell + Self.gap)))
        let rows = (count + maximumColumns - 1) / maximumColumns
        columns = (count + rows - 1) / rows
        ringSize = max(Self.minimumRing, min(Self.maximumRing, room(columns)))
    }
}

// MARK: - Text bars (Terminal)

private struct TextBarResources: View {
    @Environment(\.theme) private var theme
    var readings: [ResourceReading]
    private static let barWidth = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ConceptHeading(title: "┤ cpu · mem · disk ├", showsCustomize: true)
            ForEach(readings) { reading in
                HStack(spacing: 12) {
                    Text(reading.title.lowercased()).frame(width: 150, alignment: .leading).lineLimit(1)
                    bar(reading)
                    Text(reading.value).frame(width: 70, alignment: .trailing).foregroundStyle(reading.valueColor ?? theme.foreground)
                    Text(TextGraph.sparkline(reading.history)).foregroundStyle(theme.info).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13, design: .monospaced))
            }
        }
    }

    private func bar(_ reading: ResourceReading) -> some View {
        let filled = Int(((reading.fraction ?? 0) * Double(Self.barWidth)).rounded())
        return (Text(String(repeating: "■", count: filled)).foregroundStyle(UsageLevel.color(forFraction: reading.fraction ?? 0, in: theme))
            + Text(String(repeating: "■", count: Self.barWidth - filled)).foregroundStyle(theme.overlay))
            .font(.system(size: 11, design: .monospaced))
            .fixedSize()
    }
}

/// Graphs drawn with text glyphs, for the terminal layout.
enum TextGraph {
    private static let levels = Array("▁▂▃▄▅▆▇█")

    static func sparkline(_ values: [Double], width: Int = 24) -> String {
        let recent = values.suffix(width)
        guard let low = recent.min(), let high = recent.max() else { return "" }
        let range = max(high - low, high * 0.05, 0.0001)
        return String(recent.map { levels[min(Int(($0 - low) / range * Double(levels.count - 1)), levels.count - 1)] })
    }
}

// MARK: - LED segments (Cockpit)

struct LEDBar: View {
    @Environment(\.theme) private var theme
    var fraction: Double
    var color: Color
    var segments = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Rectangle()
                    .fill(Double(index) < fraction * Double(segments) ? color : theme.overlay)
                    .frame(height: 10)
            }
        }
    }
}

private struct LEDResources: View {
    @Environment(\.theme) private var theme
    var readings: [ResourceReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConceptHeading(title: "Systems", showsCustomize: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(readings) { reading in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reading.title.uppercased().replacingOccurrences(of: " ", with: ".")).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.2).foregroundStyle(theme.muted)
                        Text(Self.readout(reading)).font(.system(size: 54, weight: .bold, design: .monospaced)).foregroundStyle(reading.valueColor ?? theme.primary).lineLimit(1).minimumScaleFactor(0.5)
                        LEDBar(fraction: reading.fraction ?? 0, color: UsageLevel.color(forFraction: reading.fraction ?? 0, in: theme))
                        Text(reading.detail.uppercased()).font(.system(size: 10, design: .monospaced)).foregroundStyle(theme.muted).lineLimit(1)
                    }
                    .padding(12)
                    .overlay(Rectangle().strokeBorder(theme.border))
                }
            }
        }
    }

    /// "34%" becomes "034", as on a panel readout.
    static func readout(_ reading: ResourceReading) -> String {
        guard let fraction = reading.fraction, reading.value.hasSuffix("%") else { return reading.value }
        return String(format: "%03d", Int((fraction * 100).rounded()))
    }
}

// MARK: - Telemetry (Mission control)

private struct TelemetryResources: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var readings: [ResourceReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConceptHeading(title: "Telemetry", showsCustomize: true)
            HStack(spacing: 0) {
                ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                    if index > 0 { Rectangle().fill(theme.border).frame(width: 1) }
                    cell(reading).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
                }
            }
            .padding(.vertical, 12)
            .overlay(Rectangle().strokeBorder(theme.border))
            LineChart(values: store.cpuHistory, color: theme.foreground)
                .frame(height: 110)
                .overlay(alignment: .topLeading) { Text("CPU · LAST 3 MIN").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(theme.muted) }
        }
    }

    private func cell(_ reading: ResourceReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reading.title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.6).foregroundStyle(theme.muted).lineLimit(1)
            Text(reading.value).font(.system(size: 46, weight: .ultraLight).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.5)
            let status = Self.status(reading.fraction)
            Text(status.word).font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(status.isNominal ? theme.success : theme.warning)
        }
    }

    static func status(_ fraction: Double?) -> (word: String, isNominal: Bool) {
        guard let fraction else { return ("NOMINAL", true) }
        if fraction >= 0.85 { return ("CRITICAL", false) }
        return fraction >= 0.6 ? ("WATCH", false) : ("NOMINAL", true)
    }
}

/// A thin line over time with a dashed midline, as on a mission console.
struct LineChart: View {
    @Environment(\.theme) private var theme
    var values: [Double]
    var color: Color
    var maximum: Double = 1

    var body: some View {
        Canvas { context, size in
            var midline = Path()
            midline.move(to: CGPoint(x: 0, y: size.height / 2))
            midline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(midline, with: .color(theme.border), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            guard values.count > 1 else { return }
            let step = size.width / CGFloat(MonitorStore.historyLength - 1)
            let start = CGFloat(MonitorStore.historyLength - values.count) * step
            var line = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: start + CGFloat(index) * step, y: size.height * (1 - CGFloat(min(value / maximum, 1))))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            context.stroke(line, with: .color(color), lineWidth: 1.5)
        }
    }
}

// MARK: - Bento tiles

private struct BentoResources: View {
    @Environment(MonitorStore.self) private var store
    @Environment(\.theme) private var theme
    var readings: [ResourceReading]

    var body: some View {
        let hero = readings.first { $0.id == .cpu } ?? readings.first
        let rest = readings.filter { $0.id != hero?.id }
        HStack(alignment: .top, spacing: 12) {
            if let hero { heroTile(hero) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(rest) { tile($0) }
            }
        }
    }

    private func heroTile(_ reading: ResourceReading) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(reading.title).font(.system(size: 15, weight: .bold))
                Spacer()
                CustomizeResourcesButton()
            }
            Text(reading.value).font(.system(size: 120, weight: .bold).monospacedDigit()).tracking(-6).lineLimit(1).minimumScaleFactor(0.4)
            Text(reading.detail).font(.system(size: 13, weight: .medium)).opacity(0.7)
            Spacer(minLength: 16)
            HistoryBars(values: reading.history, color: theme.background.opacity(0.7)).frame(height: 70)
        }
        .foregroundStyle(theme.background)
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(theme.primary, in: RoundedRectangle(cornerRadius: 18))
    }

    private func tile(_ reading: ResourceReading) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reading.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.muted).lineLimit(1)
            Text(reading.value).font(.system(size: 44, weight: .bold).monospacedDigit()).tracking(-2).foregroundStyle(reading.valueColor ?? theme.foreground).lineLimit(1).minimumScaleFactor(0.5)
            if reading.history.count > 4 {
                HistoryBars(values: reading.history, color: reading.color.opacity(0.8), maximum: reading.historyMaximum).frame(height: 28)
            } else if let fraction = reading.fraction {
                ThinBar(fraction: fraction, color: reading.color, height: 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
        .background(theme.overlay, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// The last samples as a row of bars.
struct HistoryBars: View {
    var values: [Double]
    var color: Color
    var maximum: Double?
    var count = 30

    var body: some View {
        let recent = Array(values.suffix(count))
        let top = maximum ?? max(recent.max() ?? 1, 0.0001)
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(recent.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(height: max(proxy.size.height * CGFloat(min(value / top, 1)), 2))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Numerals (Editorial) and big numbers (Glass, Zen)

private struct NumeralResources: View {
    @Environment(\.theme) private var theme
    var readings: [ResourceReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConceptHeading(title: "By the numbers", showsCustomize: true)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                    if index > 0 { Rectangle().fill(theme.border).frame(width: 1).padding(.horizontal, 20) }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reading.title.uppercased()).font(.system(size: 12, weight: .semibold, design: .default)).tracking(1.4).foregroundStyle(theme.muted).lineLimit(1)
                        Text(reading.value).font(.system(size: 88, weight: .heavy, design: .default).monospacedDigit()).tracking(-4).lineLimit(1).minimumScaleFactor(0.4)
                        Text(reading.detail).font(.system(size: 15).italic()).foregroundStyle(theme.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Rectangle().fill(theme.foreground).frame(height: 2)
        }
    }
}

private struct BigNumberResources: View {
    @Environment(\.theme) private var theme
    @Environment(\.dashboardLayout) private var layout
    var readings: [ResourceReading]
    var weight: Font.Weight

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptHeading(title: "System", showsCustomize: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 18, alignment: .leading)], alignment: .leading, spacing: 18) {
                ForEach(readings) { reading in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reading.value).font(.system(size: weight == .light ? 36 : 40, weight: weight).monospacedDigit()).tracking(-1).lineLimit(1).minimumScaleFactor(0.5)
                            .foregroundStyle(reading.valueColor ?? theme.foreground)
                        Text(reading.title).font(.system(size: 13)).foregroundStyle(theme.muted).lineLimit(1)
                        if let fraction = reading.fraction {
                            ThinBar(fraction: fraction, color: barColor(reading), height: weight == .light ? 2 : 6)
                        }
                    }
                    .padding(layout == .glass ? 16 : 0)
                    .background(layout == .glass ? theme.foreground.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func barColor(_ reading: ResourceReading) -> Color {
        guard layout == .glass else { return reading.color }
        let palette = [theme.info, theme.error, theme.success, theme.accent, theme.warning]
        return palette[(readings.firstIndex { $0.id == reading.id } ?? 0) % palette.count]
    }
}

// MARK: - Trends (Timeline)

/// A side panel of short trend rows, like a feed's "What's happening".
private struct TrendList: View {
    @Environment(\.theme) private var theme
    var readings: [ResourceReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConceptHeading(title: "What's happening", showsCustomize: true).padding(.bottom, 8)
            ForEach(readings) { reading in
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Mac · \(reading.title)").font(.system(size: 13)).foregroundStyle(theme.muted).lineLimit(1)
                    Text(reading.value).font(.system(size: 17, weight: .heavy)).foregroundStyle(reading.valueColor ?? theme.foreground)
                    if !reading.detail.isEmpty { Text(reading.detail).font(.system(size: 13)).foregroundStyle(theme.muted).lineLimit(1) }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Hairline() }
            }
        }
        .padding(16)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
