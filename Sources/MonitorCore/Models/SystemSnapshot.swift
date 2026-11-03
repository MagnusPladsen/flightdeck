import Foundation

public struct CPUUsage: Sendable, Equatable {
    /// Fraction of total CPU capacity in use, 0...1.
    public var total: Double
    public var perCore: [Double]

    public init(total: Double, perCore: [Double]) {
        self.total = total
        self.perCore = perCore
    }

    public static let zero = CPUUsage(total: 0, perCore: [])
}

public enum MemoryPressure: String, Sendable {
    case normal, warning, critical
}

public struct MemoryUsage: Sendable, Equatable {
    public var totalBytes: UInt64
    public var usedBytes: UInt64
    public var wiredBytes: UInt64
    public var compressedBytes: UInt64
    public var swapUsedBytes: UInt64
    public var pressure: MemoryPressure

    public init(totalBytes: UInt64, usedBytes: UInt64, wiredBytes: UInt64, compressedBytes: UInt64, swapUsedBytes: UInt64, pressure: MemoryPressure) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressure = pressure
    }

    public var usedFraction: Double {
        totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes)
    }

    public static let zero = MemoryUsage(totalBytes: 0, usedBytes: 0, wiredBytes: 0, compressedBytes: 0, swapUsedBytes: 0, pressure: .normal)
}

public struct DiskUsage: Sendable, Equatable, Identifiable {
    public var id: String { mountPath }
    public var name: String
    public var mountPath: String
    public var totalBytes: UInt64
    public var availableBytes: UInt64

    public init(name: String, mountPath: String, totalBytes: UInt64, availableBytes: UInt64) {
        self.name = name
        self.mountPath = mountPath
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    public var usedFraction: Double {
        totalBytes == 0 ? 0 : 1 - Double(availableBytes) / Double(totalBytes)
    }
}

public struct NetworkThroughput: Sendable, Equatable {
    public var bytesInPerSecond: Double
    public var bytesOutPerSecond: Double

    public init(bytesInPerSecond: Double, bytesOutPerSecond: Double) {
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
    }

    public static let zero = NetworkThroughput(bytesInPerSecond: 0, bytesOutPerSecond: 0)
}

public struct BatteryStatus: Sendable, Equatable {
    public var percent: Double
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var minutesRemaining: Int?
    public var cycleCount: Int?
    /// Current full-charge capacity relative to design capacity, 0...1.
    public var health: Double?

    public init(percent: Double, isCharging: Bool, isPluggedIn: Bool, minutesRemaining: Int?, cycleCount: Int?, health: Double?) {
        self.percent = percent
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.minutesRemaining = minutesRemaining
        self.cycleCount = cycleCount
        self.health = health
    }
}

public struct ProcessSample: Sendable, Equatable, Identifiable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var parentPID: Int32
    public var name: String
    /// Percent of one core, like Activity Monitor (can exceed 100).
    public var cpuPercent: Double
    public var memoryBytes: UInt64

    public init(pid: Int32, parentPID: Int32, name: String, cpuPercent: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.parentPID = parentPID
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}

public struct SystemSnapshot: Sendable {
    public var timestamp: Date
    public var hostName: String
    public var uptime: TimeInterval
    public var loadAverage: [Double]
    public var cpu: CPUUsage
    public var memory: MemoryUsage
    public var disks: [DiskUsage]
    public var network: NetworkThroughput
    public var battery: BatteryStatus?
    public var processes: [ProcessSample]

    public init(timestamp: Date, hostName: String, uptime: TimeInterval, loadAverage: [Double], cpu: CPUUsage, memory: MemoryUsage, disks: [DiskUsage], network: NetworkThroughput, battery: BatteryStatus?, processes: [ProcessSample]) {
        self.timestamp = timestamp
        self.hostName = hostName
        self.uptime = uptime
        self.loadAverage = loadAverage
        self.cpu = cpu
        self.memory = memory
        self.disks = disks
        self.network = network
        self.battery = battery
        self.processes = processes
    }
}
