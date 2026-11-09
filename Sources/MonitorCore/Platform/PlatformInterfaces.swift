import Foundation

/// Everything the collectors need from the OS. Darwin and Linux each provide one implementation,
/// so collectors, project detection and AI tracking stay platform-neutral.
public struct RawProcess: Sendable, Equatable {
    public var pid: Int32
    public var parentPID: Int32
    public var name: String
    /// Total user + system CPU time consumed so far.
    public var cpuTimeNanoseconds: UInt64
    public var memoryBytes: UInt64

    public init(pid: Int32, parentPID: Int32, name: String, cpuTimeNanoseconds: UInt64, memoryBytes: UInt64) {
        self.pid = pid
        self.parentPID = parentPID
        self.name = name
        self.cpuTimeNanoseconds = cpuTimeNanoseconds
        self.memoryBytes = memoryBytes
    }
}

public struct RawListeningSocket: Sendable, Equatable {
    public var pid: Int32
    public var processName: String
    public var port: Int
    public var isLocalOnly: Bool

    public init(pid: Int32, processName: String, port: Int, isLocalOnly: Bool) {
        self.pid = pid
        self.processName = processName
        self.port = port
        self.isLocalOnly = isLocalOnly
    }
}

public struct CPUTicks: Sendable, Equatable {
    public var busy: UInt64
    public var total: UInt64

    public init(busy: UInt64, total: UInt64) {
        self.busy = busy
        self.total = total
    }
}

public struct NetworkCounters: Sendable, Equatable {
    public var bytesIn: UInt64
    public var bytesOut: UInt64

    public init(bytesIn: UInt64, bytesOut: UInt64) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

public protocol ProcessInspector: Sendable {
    /// Processes the current user can inspect.
    func listProcesses() -> [RawProcess]
    func arguments(of pid: Int32) -> [String]
    func workingDirectory(of pid: Int32) -> String?
    func startTime(of pid: Int32) -> Date?
}

public protocol ListeningSocketScanner: Sendable {
    func scanListeningSockets() -> [RawListeningSocket]
}

public protocol SystemMetricsReader: Sendable {
    func hostName() -> String
    func uptime() -> TimeInterval
    func loadAverage() -> [Double]
    func cpuTicksPerCore() -> [CPUTicks]
    func memory() -> MemoryUsage
    func disks() -> [DiskUsage]
    func networkCounters() -> NetworkCounters
    func battery() -> BatteryStatus?
}

public enum PlatformServices {
    public static func makeProcessInspector() -> ProcessInspector {
        #if canImport(Darwin)
        DarwinProcessInspector()
        #else
        LinuxProcessInspector()
        #endif
    }

    public static func makeListeningSocketScanner() -> ListeningSocketScanner {
        #if canImport(Darwin)
        LsofListeningSocketScanner()
        #else
        LinuxListeningSocketScanner()
        #endif
    }

    public static func makeSystemMetricsReader() -> SystemMetricsReader {
        #if canImport(Darwin)
        DarwinSystemMetricsReader()
        #else
        LinuxSystemMetricsReader()
        #endif
    }
}
