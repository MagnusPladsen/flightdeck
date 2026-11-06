import Foundation

/// In-place radix-2 FFT. Pure Swift so the core still builds where Accelerate is missing; a
/// 1024-point transform 30 times a second is far below anything that shows up in CPU use.
enum FFT {
    /// Magnitudes of the first `samples.count / 2` bins. The count must be a power of two.
    static func magnitudes(of samples: [Double]) -> [Double] {
        let count = samples.count
        precondition(count > 1 && count & (count - 1) == 0, "FFT size must be a power of two")
        var real = samples
        var imaginary = [Double](repeating: 0, count: count)
        reorderByBitReversal(&real, &imaginary)
        butterflies(&real, &imaginary)
        return (0..<count / 2).map { (real[$0] * real[$0] + imaginary[$0] * imaginary[$0]).squareRoot() }
    }

    private static func reorderByBitReversal(_ real: inout [Double], _ imaginary: inout [Double]) {
        var target = 0
        for index in 0..<real.count - 1 {
            if index < target {
                real.swapAt(index, target)
                imaginary.swapAt(index, target)
            }
            var bit = real.count >> 1
            while target & bit != 0 {
                target ^= bit
                bit >>= 1
            }
            target |= bit
        }
    }

    private static func butterflies(_ real: inout [Double], _ imaginary: inout [Double]) {
        var size = 2
        while size <= real.count {
            let angle = -2 * Double.pi / Double(size)
            for start in stride(from: 0, to: real.count, by: size) {
                for offset in 0..<size / 2 {
                    let even = start + offset, odd = even + size / 2
                    let cosine = cos(angle * Double(offset)), sine = sin(angle * Double(offset))
                    let oddReal = real[odd] * cosine - imaginary[odd] * sine
                    let oddImaginary = real[odd] * sine + imaginary[odd] * cosine
                    (real[odd], imaginary[odd]) = (real[even] - oddReal, imaginary[even] - oddImaginary)
                    (real[even], imaginary[even]) = (real[even] + oddReal, imaginary[even] + oddImaginary)
                }
            }
            size <<= 1
        }
    }
}

/// Turns raw audio into a handful of 0...1 bar heights on a log frequency scale.
public struct SpectrumAnalyzer: Sendable {
    public static let windowSize = 1024
    public var bandCount: Int
    public var sampleRate: Double
    public var lowestFrequency = 40.0
    public var highestFrequency = 16_000.0
    /// Levels at or below this many decibels under full scale draw as an empty bar.
    public var floorDecibels = -70.0
    /// Music carries far less energy up high, so bands above 1 kHz are lifted (and below it lowered)
    /// by this much per octave to keep the whole row moving.
    public var tiltDecibelsPerOctave = 3.0

    public init(bandCount: Int, sampleRate: Double) {
        self.bandCount = bandCount
        self.sampleRate = sampleRate
    }

    /// Band levels for the last `windowSize` samples; shorter input is padded with silence.
    public func bands(for samples: [Float]) -> [Double] {
        let windowed = Self.hannWindowed(samples)
        let magnitudes = FFT.magnitudes(of: windowed)
        let fullScale = Double(Self.windowSize) / 4
        let binWidth = sampleRate / Double(Self.windowSize)
        return binRanges(binCount: magnitudes.count).map { range in
            let peak = magnitudes[range].max() ?? 0
            let centre = Double(range.lowerBound + range.upperBound) / 2 * binWidth
            let tilt = tiltDecibelsPerOctave * log2(max(centre, 1) / 1000)
            return peak == 0 ? 0 : normalized(decibels: 20 * log10(max(peak / fullScale, 1e-12)) + tilt)
        }
    }

    /// FFT bin indices for each band, spaced logarithmically and at least one bin wide.
    func binRanges(binCount: Int) -> [ClosedRange<Int>] {
        let binWidth = sampleRate / Double(Self.windowSize)
        let ratio = highestFrequency / lowestFrequency
        var lower = max(Int(lowestFrequency / binWidth), 1)
        return (0..<bandCount).map { band in
            let edge = lowestFrequency * pow(ratio, Double(band + 1) / Double(bandCount))
            let upper = min(max(Int(edge / binWidth), lower), binCount - 1)
            defer { lower = min(upper + 1, binCount - 1) }
            return lower...upper
        }
    }

    private func normalized(decibels: Double) -> Double {
        min(max((decibels - floorDecibels) / -floorDecibels, 0), 1)
    }

    static func hannWindowed(_ samples: [Float]) -> [Double] {
        let size = windowSize
        let recent = samples.suffix(size)
        let padded = [Double](repeating: 0, count: size - recent.count) + recent.map(Double.init)
        return padded.enumerated().map { index, sample in
            sample * 0.5 * (1 - cos(2 * Double.pi * Double(index) / Double(size - 1)))
        }
    }
}

/// Bars rise quickly and fall slowly, the way hardware level meters move.
public struct SpectrumSmoother: Sendable {
    public var attack: Double
    public var release: Double
    public private(set) var levels: [Double]

    public init(bandCount: Int, attack: Double = 0.65, release: Double = 0.14) {
        self.attack = attack
        self.release = release
        levels = Array(repeating: 0, count: bandCount)
    }

    public mutating func update(with target: [Double]) -> [Double] {
        if target.count != levels.count { levels = Array(repeating: 0, count: target.count) }
        levels = zip(levels, target).map { current, next in
            current + (next - current) * (next > current ? attack : release)
        }
        return levels
    }
}

/// True when a buffer holds nothing audible (peaks under -60 dBFS): what a process tap delivers
/// while the audio-capture permission is denied, or while nothing really plays.
public enum AudioSilence {
    public static let threshold: Float = 0.001

    public static func isSilent(_ samples: [Float]) -> Bool {
        !samples.contains { abs($0) > threshold }
    }
}
