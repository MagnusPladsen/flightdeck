#if !canImport(Darwin)
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Reads `/proc` and `/sys`. Untested on real hardware batteries beyond the BAT0 layout.
public struct LinuxSystemMetricsReader: SystemMetricsReader {
    public init() {}

    public func hostName() -> String {
        ProcessInfo.processInfo.hostName
    }

    public func uptime() -> TimeInterval {
        let text = read("/proc/uptime") ?? ""
        return TimeInterval(text.split(separator: " ").first ?? "") ?? ProcessInfo.processInfo.systemUptime
    }

    public func loadAverage() -> [Double] {
        let parts = (read("/proc/loadavg") ?? "").split(separator: " ").prefix(3)
        return parts.compactMap { Double($0) }
    }

    /// Lines `cpuN user nice system idle iowait irq softirq steal`.
    public func cpuTicksPerCore() -> [CPUTicks] {
        (read("/proc/stat") ?? "").split(separator: "\n")
            .filter { $0.hasPrefix("cpu") && !$0.hasPrefix("cpu ") }
            .map { line in
                let values = line.split(separator: " ").dropFirst().compactMap { UInt64($0) }
                let idle = values.count > 4 ? values[3] + values[4] : 0
                let total = values.prefix(8).reduce(0, +)
                return CPUTicks(busy: total - idle, total: total)
            }
    }

    public func memory() -> MemoryUsage {
        var kilobytes: [String: UInt64] = [:]
        for line in (read("/proc/meminfo") ?? "").split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { continue }
            kilobytes[String(parts[0].dropLast())] = UInt64(parts[1])
        }
        let total = (kilobytes["MemTotal"] ?? 0) * 1024
        let available = (kilobytes["MemAvailable"] ?? 0) * 1024
        let swapUsed = ((kilobytes["SwapTotal"] ?? 0) - (kilobytes["SwapFree"] ?? 0)) * 1024
        let usedFraction = total == 0 ? 0 : Double(total - available) / Double(total)
        let pressure: MemoryPressure = usedFraction > 0.95 ? .critical : usedFraction > 0.85 ? .warning : .normal
        return MemoryUsage(totalBytes: total, usedBytes: total - available, wiredBytes: 0, compressedBytes: 0, swapUsedBytes: swapUsed, pressure: pressure)
    }

    public func disks() -> [DiskUsage] {
        var stats = statvfs()
        guard statvfs("/", &stats) == 0 else { return [] }
        let blockSize = UInt64(stats.f_frsize)
        return [DiskUsage(name: "Root", mountPath: "/", totalBytes: UInt64(stats.f_blocks) * blockSize, availableBytes: UInt64(stats.f_bavail) * blockSize)]
    }

    /// `/proc/net/dev`: "  eth0: rxBytes rxPackets ... (8 rx fields) txBytes ...".
    public func networkCounters() -> NetworkCounters {
        var counters = NetworkCounters(bytesIn: 0, bytesOut: 0)
        for line in (read("/proc/net/dev") ?? "").split(separator: "\n").dropFirst(2) {
            let halves = line.split(separator: ":", maxSplits: 1)
            guard halves.count == 2, halves[0].trimmingCharacters(in: .whitespaces) != "lo" else { continue }
            let values = halves[1].split(separator: " ").compactMap { UInt64($0) }
            guard values.count >= 9 else { continue }
            counters.bytesIn += values[0]
            counters.bytesOut += values[8]
        }
        return counters
    }

    public func battery() -> BatteryStatus? {
        let base = "/sys/class/power_supply/BAT0"
        guard let capacity = read("\(base)/capacity").flatMap({ Double($0) }) else { return nil }
        let status = read("\(base)/status") ?? ""
        let full = read("\(base)/energy_full").flatMap { Double($0) }
        let design = read("\(base)/energy_full_design").flatMap { Double($0) }
        let health = (full != nil && design != nil && design! > 0) ? min(full! / design!, 1) : nil
        return BatteryStatus(
            percent: capacity / 100,
            isCharging: status == "Charging",
            isPluggedIn: status != "Discharging",
            minutesRemaining: nil,
            cycleCount: read("\(base)/cycle_count").flatMap { Int($0) },
            health: health
        )
    }

    private func read(_ path: String) -> String? {
        (try? String(contentsOfFile: path, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
