import Foundation

/// `status.json` in Flightdeck's Application Support folder, written by the app and read by the `flightdeck` command.
public enum StatusFile {
    /// Older than this and the app is taken to have stopped.
    public static let staleAfter: TimeInterval = 30
    public static let pathOverrideVariable = "FLIGHTDECK_STATUS_FILE"

    public static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment[pathOverrideVariable], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flightdeck/status.json")
    }

    public static func encode(_ report: StatusReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    public static func decode(_ data: Data) throws -> StatusReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StatusReport.self, from: data)
    }

    public static func write(_ report: StatusReport, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(report).write(to: url, options: .atomic)
    }

    /// Marks the file as current without rewriting it, so readers know the app is still running.
    public static func touch(_ url: URL, at date: Date = Date()) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    public static func read(from url: URL, now: Date = Date()) throws(StatusFileError) -> StatusReport {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { throw .missing(url.path) }
        let modified = attributes[.modificationDate] as? Date ?? .distantPast
        let age = now.timeIntervalSince(modified)
        guard age <= staleAfter else { throw .stale(seconds: Int(age)) }
        guard let data = try? Data(contentsOf: url), let report = try? decode(data) else { throw .unreadable(url.path) }
        return report
    }
}

public enum StatusFileError: Error, Equatable, CustomStringConvertible {
    case missing(String)
    case stale(seconds: Int)
    case unreadable(String)

    public var description: String {
        switch self {
        case .missing(let path): "No Flightdeck status at \(path). Open Flightdeck.app to start it."
        case .stale(let seconds): "Flightdeck status is \(seconds)s old. Is Flightdeck.app running?"
        case .unreadable(let path): "Could not read the Flightdeck status at \(path)."
        }
    }
}
