import Foundation

/// macOS has no public API listing sockets of other processes, so we parse `lsof -F` machine output.
public struct LsofListeningSocketScanner: ListeningSocketScanner {
    public init() {}

    public func scanListeningSockets() -> [RawListeningSocket] {
        let result = CommandRunner.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"])
        return Self.parse(result.output)
    }

    /// Parses lines like `p123`, `cnode`, `f16`, `n*:3000`, merging IPv4/IPv6 duplicates.
    static func parse(_ output: String) -> [RawListeningSocket] {
        var socketsByKey: [String: RawListeningSocket] = [:]
        var order: [String] = []
        var currentPID: Int32 = 0
        var currentCommand = ""

        for line in output.split(separator: "\n") {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())
            switch field {
            case "p": currentPID = Int32(value) ?? 0
            case "c": currentCommand = value
            case "n":
                guard let (host, port) = splitHostPort(value) else { continue }
                let key = "\(currentPID):\(port)"
                let isLocal = isLoopback(host)
                if var existing = socketsByKey[key] {
                    existing.isLocalOnly = existing.isLocalOnly && isLocal
                    socketsByKey[key] = existing
                } else {
                    socketsByKey[key] = RawListeningSocket(pid: currentPID, processName: currentCommand, port: port, isLocalOnly: isLocal)
                    order.append(key)
                }
            default: continue
            }
        }
        return order.compactMap { socketsByKey[$0] }
    }

    static func splitHostPort(_ address: String) -> (String, Int)? {
        guard let colon = address.lastIndex(of: ":"), let port = Int(address[address.index(after: colon)...]) else { return nil }
        return (String(address[..<colon]), port)
    }

    static func isLoopback(_ host: String) -> Bool {
        host.hasPrefix("127.") || host == "[::1]" || host == "localhost"
    }
}
