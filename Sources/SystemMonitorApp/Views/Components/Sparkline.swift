import Charts
import SwiftUI

struct Sparkline: View {
    var values: [Double]
    var color: Color = .accentColor
    /// Fixed upper bound, e.g. 1 for fractions. Nil scales to the data.
    var maximum: Double?

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { offset, value in
            let index = Sparkline.rightAlignedIndex(offset, count: values.count)
            AreaMark(x: .value("Sample", index), y: .value("Value", value))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Sample", index), y: .value("Value", value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...max(MonitorStore.historyLength - 1, 1))
        .chartYScale(domain: 0...yUpperBound)
    }

    /// Places the newest sample at the right edge so short histories grow leftwards.
    static func rightAlignedIndex(_ offset: Int, count: Int) -> Int {
        MonitorStore.historyLength - count + offset
    }

    private var yUpperBound: Double {
        if let maximum { return maximum }
        return max(values.max() ?? 1, 1)
    }
}
