#if canImport(Darwin)
import Darwin
import Foundation

/// Reads process info through libproc and sysctl; no subprocesses.
public struct DarwinProcessInspector: ProcessInspector {
    private static let machTicksToNanoseconds: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    public init() {}

    public func listProcesses() -> [RawProcess] {
        listAllPIDs().compactMap(rawProcess(for:))
    }

    public func arguments(of pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }
        return Self.parseProcArgs(Array(buffer.prefix(size)))
    }

    public func workingDirectory(of pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let expectedSize = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, expectedSize) == expectedSize else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { rawBuffer in
            String(decoding: rawBuffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.isEmpty ? nil : path
    }

    public func startTime(of pid: Int32) -> Date? {
        var info = proc_bsdinfo()
        let expectedSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, expectedSize) == expectedSize else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000)
    }

    /// KERN_PROCARGS2 layout: argc (Int32), exec path, NUL padding, then argc NUL-terminated args.
    static func parseProcArgs(_ buffer: [UInt8]) -> [String] {
        guard buffer.count > 4 else { return [] }
        let argumentCount = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var index = 4
        while index < buffer.count, buffer[index] != 0 { index += 1 }
        while index < buffer.count, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        while arguments.count < argumentCount, index < buffer.count {
            let start = index
            while index < buffer.count, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }

    private func listAllPIDs() -> [Int32] {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(estimatedCount) + 64)
        let byteCount = Int32(pids.count * MemoryLayout<Int32>.size)
        let actualCount = proc_listallpids(&pids, byteCount)
        guard actualCount > 0 else { return [] }
        return Array(pids.prefix(Int(actualCount))).filter { $0 > 0 }
    }

    private func rawProcess(for pid: Int32) -> RawProcess? {
        var bsdInfo = proc_bsdinfo()
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, bsdSize) == bsdSize else { return nil }

        var usage = rusage_info_v2()
        let usageResult = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
        }
        guard usageResult == 0 else { return nil }

        let cpuTicks = Double(usage.ri_user_time + usage.ri_system_time)
        return RawProcess(
            pid: pid,
            parentPID: Int32(bsdInfo.pbi_ppid),
            name: processName(pid: pid, bsdInfo: bsdInfo),
            cpuTimeNanoseconds: UInt64(cpuTicks * Self.machTicksToNanoseconds),
            memoryBytes: usage.ri_phys_footprint
        )
    }

    private func processName(pid: Int32, bsdInfo: proc_bsdinfo) -> String {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
            let path = String(cString: pathBuffer)
            if let appName = Self.appBundleName(fromExecutablePath: path) { return appName }
            return (path as NSString).lastPathComponent
        }
        var info = bsdInfo
        return withUnsafeBytes(of: &info.pbi_name) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    /// "/Applications/Zed.app/Contents/MacOS/zed" -> "Zed"
    static func appBundleName(fromExecutablePath path: String) -> String? {
        guard let range = path.range(of: ".app/Contents/MacOS/") else { return nil }
        let bundlePath = String(path[..<range.lowerBound])
        let executable = String(path[range.upperBound...])
        guard !executable.contains("/") else { return nil }
        return (bundlePath as NSString).lastPathComponent
    }
}
#endif
