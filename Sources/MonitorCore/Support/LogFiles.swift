import Foundation

/// Small file helpers for reading agent logs without loading whole files.
public enum LogFiles {
    public struct Entry: Sendable, Equatable {
        public var path: String
        public var modified: Date
        public var size: UInt64
    }

    public static func files(in directory: String, withExtension fileExtension: String) -> [Entry] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return names.filter { $0.hasSuffix("." + fileExtension) }.compactMap { entry(at: directory + "/" + $0) }
    }

    public static func newestFile(in directory: String, withExtension fileExtension: String) -> Entry? {
        files(in: directory, withExtension: fileExtension).max { $0.modified < $1.modified }
    }

    public static func entry(at path: String) -> Entry? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return Entry(path: path, modified: modified, size: (attributes[.size] as? NSNumber)?.uint64Value ?? 0)
    }

    public static func readTail(of path: String, maxBytes: UInt64) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > maxBytes ? size - maxBytes : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    public static func readHead(of path: String, maxBytes: Int) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? handle.close() }
        return String(decoding: (try? handle.read(upToCount: maxBytes)) ?? Data(), as: UTF8.self)
    }

    /// Reads bytes appended since `offset`, returning only complete lines and the new offset.
    public static func readNewLines(of path: String, from offset: UInt64) -> (lines: [Substring], nextOffset: UInt64) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return ([], offset) }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = offset > size ? 0 : offset
        try? handle.seek(toOffset: start)
        let data = (try? handle.readToEnd()) ?? Data()
        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return ([], start) }
        let complete = data[data.startIndex...lastNewline]
        let text = String(decoding: complete, as: UTF8.self)
        return (text.split(separator: "\n"), start + UInt64(complete.count))
    }
}
