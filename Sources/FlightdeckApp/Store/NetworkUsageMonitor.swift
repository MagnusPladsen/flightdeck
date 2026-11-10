import Foundation
import MonitorCore
import Observation

/// Download and upload per app from `nettop`, read only while a view showing it is on screen.
@MainActor
@Observable
final class NetworkUsageMonitor {
    static let consumerLimit = 10

    private(set) var consumers: [NetworkConsumer] = []
    private(set) var hasReading = false
    @ObservationIgnored private var viewers = 0
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored var processNames: () -> [Int32: String] = { [:] }

    func viewerAppeared() {
        viewers += 1
        guard loop == nil else { return }
        loop = Task { await run() }
    }

    func viewerDisappeared() {
        viewers = max(viewers - 1, 0)
        guard viewers == 0 else { return }
        loop?.cancel()
        loop = nil
    }

    func showDemo(_ consumers: [NetworkConsumer]) {
        self.consumers = consumers
        hasReading = true
    }

    private func run() async {
        guard !DemoData.isEnabled else { return }
        var previous: (counters: [NetworkCounter], at: Date)?
        while !Task.isCancelled {
            let counters = await Task.detached { Self.readCounters() }.value
            let now = Date()
            if let previous {
                consumers = NetworkBreakdown.consumers(previous: previous.counters, current: counters, seconds: now.timeIntervalSince(previous.at),
                                                       names: processNames(), limit: Self.consumerLimit)
                hasReading = true
            }
            previous = (counters, now)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Takes about five seconds: `nettop` waits a sampling interval before it prints.
    private nonisolated static func readCounters() -> [NetworkCounter] {
        let result = CommandRunner.run("/usr/bin/nettop", ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"], timeout: 15)
        return NetworkBreakdown.parseNettop(result.output)
    }
}
