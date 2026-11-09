import Foundation

/// Reads `/proc`. Compiles everywhere; only used on Linux.
public struct LinuxProcessInspector: ProcessInspector {
    static let clockTicksPerSecond: UInt64 = 100
    static let pageSize: UInt64 = 4096

    public init() {}

    public func listProcesses() -> [RawProcess] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: "/proc")) ?? []
        return entries.compactMap(Int32.init).compactMap { pid in
            guard let stat = try? String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8) else { return nil }
            return Self.parseStat(stat, pid: pid)
        }
    }

    public func arguments(of pid: Int32) -> [String] {
        guard let data = FileManager.default.contents(atPath: "/proc/\(pid)/cmdline") else { return [] }
        return data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
    }

    public func workingDirectory(of pid: Int32) -> String? {
        try? FileManager.default.destinationOfSymbolicLink(atPath: "/proc/\(pid)/cwd")
    }

    /// Field 22 of `/proc/<pid>/stat` counts clock ticks from boot; `btime` in `/proc/stat` is the boot time.
    public func startTime(of pid: Int32) -> Date? {
        guard let stat = try? String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8),
              let close = stat.lastIndex(of: ")"),
              let ticks = stat[stat.index(after: close)...].split(separator: " ").dropFirst(19).first.flatMap({ UInt64($0) }),
              let system = try? String(contentsOfFile: "/proc/stat", encoding: .utf8),
              let bootLine = system.split(separator: "\n").first(where: { $0.hasPrefix("btime ") }),
              let bootTime = TimeInterval(bootLine.dropFirst(6)) else { return nil }
        return Date(timeIntervalSince1970: bootTime + TimeInterval(ticks) / TimeInterval(Self.clockTicksPerSecond))
    }

    /// `/proc/<pid>/stat`: "pid (comm) state ppid ... utime(14) stime(15) ... rss(24)".
    static func parseStat(_ stat: String, pid: Int32) -> RawProcess? {
        guard let open = stat.firstIndex(of: "("), let close = stat.lastIndex(of: ")") else { return nil }
        let name = String(stat[stat.index(after: open)..<close])
        let fields = stat[stat.index(after: close)...].split(separator: " ")
        // fields[0] is field 3 (state), so field N lives at index N - 3.
        guard fields.count > 21,
              let parentPID = Int32(fields[1]),
              let userTicks = UInt64(fields[11]),
              let systemTicks = UInt64(fields[12]),
              let residentPages = UInt64(fields[21]) else { return nil }

        let nanosecondsPerTick = 1_000_000_000 / clockTicksPerSecond
        return RawProcess(
            pid: pid,
            parentPID: parentPID,
            name: name,
            cpuTimeNanoseconds: (userTicks + systemTicks) * nanosecondsPerTick,
            memoryBytes: residentPages * pageSize
        )
    }
}

/// Parses `ss -H -ltnp`. Requires iproute2, present on all mainstream distros.
public struct LinuxListeningSocketScanner: ListeningSocketScanner {
    public init() {}

    public func scanListeningSockets() -> [RawListeningSocket] {
        guard let ss = CommandRunner.locate("ss") else { return [] }
        return Self.parse(CommandRunner.run(ss, ["-H", "-ltnp"]).output)
    }

    /// Line: `LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:(("node",pid=1234,fd=20))`
    static func parse(_ output: String) -> [RawListeningSocket] {
        var seen = Set<String>()
        var sockets: [RawListeningSocket] = []
        for line in output.split(separator: "\n") {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 6,
                  let (host, port) = LsofListeningSocketScanner.splitHostPort(String(columns[3])),
                  let usersColumn = columns.last(where: { $0.hasPrefix("users:") }),
                  let pid = extract(#"pid=(\d+)"#, from: String(usersColumn)).flatMap(Int32.init) else { continue }

            let name = extract(#"\(\("([^"]+)""#, from: String(usersColumn)) ?? "?"
            guard seen.insert("\(pid):\(port)").inserted else { continue }
            let isLocal = LsofListeningSocketScanner.isLoopback(host) || host.hasPrefix("[::ffff:127.")
            sockets.append(RawListeningSocket(pid: pid, processName: name, port: port, isLocalOnly: isLocal))
        }
        return sockets
    }

    private static func extract(_ pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
