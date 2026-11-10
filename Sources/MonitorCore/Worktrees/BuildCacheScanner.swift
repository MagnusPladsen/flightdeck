import Foundation

/// Dependency and build folders at the top of a checkout that tools recreate, e.g. `node_modules` and `.build`.
public struct BuildCacheUsage: Sendable, Hashable {
    /// Bytes per folder name, only for folders that exist.
    public var bytesByFolder: [String: UInt64]

    public init(bytesByFolder: [String: UInt64]) {
        self.bytesByFolder = bytesByFolder
    }

    public var totalBytes: UInt64 { bytesByFolder.values.reduce(0, +) }

    /// Folder names, largest first.
    public var folders: [String] { bytesByFolder.sorted { $0.value > $1.value }.map(\.key) }
}

public enum BuildCacheScanner {
    public static let folderNames = ["node_modules", ".build", "DerivedData", "target", ".next", ".turbo", ".venv", "Pods", ".gradle"]

    /// Sizes the cache folders directly inside `checkout`, nil when it has none.
    public static func usage(in checkout: String, fileManager: FileManager = .default) -> BuildCacheUsage? {
        let present = folderNames.filter { isDirectory(checkout + "/" + $0, fileManager: fileManager) }
        guard !present.isEmpty else { return nil }
        let sizes = present.compactMap { name in diskBytes(of: checkout + "/" + name).map { (name, $0) } }
        return sizes.isEmpty ? nil : BuildCacheUsage(bytesByFolder: Dictionary(uniqueKeysWithValues: sizes))
    }

    private static func isDirectory(_ path: String, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// `du` counts allocated blocks, so the number matches what removing the folder frees.
    private static func diskBytes(of path: String) -> UInt64? {
        let result = CommandRunner.run("/usr/bin/du", ["-sk", path], timeout: 30)
        return parseKilobytes(result.output).map { $0 * 1024 }
    }

    static func parseKilobytes(_ duOutput: String) -> UInt64? {
        duOutput.split(whereSeparator: \.isWhitespace).first.flatMap { UInt64($0) }
    }
}
