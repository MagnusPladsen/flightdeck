#if canImport(Darwin)
import Darwin
import Foundation
import IOKit.ps

public struct DarwinSystemMetricsReader: SystemMetricsReader {
    public init() {}

    public func hostName() -> String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    public func uptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    public func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : []
    }

    public func cpuTicksPerCore() -> [CPUTicks] {
        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &coreCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        return (0..<Int(coreCount)).map { core in
            let base = Int(CPU_STATE_MAX) * core
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            return CPUTicks(busy: user + system + nice, total: user + system + nice + idle)
        }
    }

    public func memory() -> MemoryUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return .zero }

        let pageSize = UInt64(vm_kernel_page_size)
        let appMemory = UInt64(stats.internal_page_count - stats.purgeable_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        return MemoryUsage(
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            usedBytes: appMemory + wired + compressed,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapUsedBytes: swapUsed(),
            pressure: memoryPressure()
        )
    }

    public func disks() -> [DiskUsage] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeIsBrowsableKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable == true,
                  let total = values.volumeTotalCapacity, total > 0,
                  let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
            return DiskUsage(name: values.volumeName ?? url.lastPathComponent, mountPath: url.path, totalBytes: UInt64(total), availableBytes: UInt64(available))
        }
    }

    /// Sums 64-bit interface counters from NET_RT_IFLIST2, skipping loopback.
    public func networkCounters() -> NetworkCounters {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0 else { return NetworkCounters(bytesIn: 0, bytesOut: 0) }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return NetworkCounters(bytesIn: 0, bytesOut: 0) }

        let loopbackInterfaceType: UInt8 = 0x18
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let extended = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if extended.ifm_data.ifi_type != loopbackInterfaceType {
                        bytesIn += extended.ifm_data.ifi_ibytes
                        bytesOut += extended.ifm_data.ifi_obytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return NetworkCounters(bytesIn: bytesIn, bytesOut: bytesOut)
    }

    public func battery() -> BatteryStatus? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }

            let minutes = (description[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
            let registry = smartBatteryRegistryValues()
            return BatteryStatus(
                percent: Double(current) / Double(maximum),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                minutesRemaining: minutes,
                cycleCount: registry.cycleCount,
                health: registry.health
            )
        }
        return nil
    }

    private func smartBatteryRegistryValues() -> (cycleCount: Int?, health: Double?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        func property(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
        }
        let maxCapacity = property("AppleRawMaxCapacity") ?? property("NominalChargeCapacity")
        let designCapacity = property("DesignCapacity")
        let health = zip(maxCapacity, designCapacity).flatMap { $1 > 0 ? min(Double($0) / Double($1), 1) : nil }
        return (property("CycleCount"), health)
    }

    private func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        return sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 ? usage.xsu_used : 0
    }

    private func memoryPressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }
}

private func zip<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
    guard let first, let second else { return nil }
    return (first, second)
}
#endif
