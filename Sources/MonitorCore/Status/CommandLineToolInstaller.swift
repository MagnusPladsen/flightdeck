import Foundation

/// Links the bundled `flightdeck` command into a bin folder, preferring one the user can write to without sudo.
public struct CommandLineToolInstaller: Sendable {
    public static let commandName = "flightdeck"

    /// Bin folders to try, best first.
    public var candidateFolders: [String]
    /// The folders on the user's shell PATH.
    public var pathEntries: [String]

    public init(candidateFolders: [String], pathEntries: [String]) {
        self.candidateFolders = candidateFolders
        self.pathEntries = pathEntries
    }

    public static func standardFolders(home: String) -> [String] {
        [home + "/.local/bin", "/usr/local/bin"]
    }

    /// The first writable folder on PATH; otherwise the first writable one, which then needs adding to PATH.
    public func chooseFolder() -> String? {
        let writable = candidateFolders.filter(Self.canWrite)
        return writable.first(where: isOnPath) ?? writable.first
    }

    public func isOnPath(_ folder: String) -> Bool {
        pathEntries.map(Self.standardized).contains(Self.standardized(folder))
    }

    public func install(helper: String) throws(CommandLineToolInstallError) -> CommandLineToolInstallation {
        guard let folder = chooseFolder() else { throw .noWritableFolder(candidateFolders) }
        let link = folder + "/" + Self.commandName
        try Self.replaceLink(at: link, pointingTo: helper, creating: folder)
        return CommandLineToolInstallation(linkPath: link, isOnPath: isOnPath(folder))
    }

    static func replaceLink(at link: String, pointingTo helper: String, creating folder: String) throws(CommandLineToolInstallError) {
        let files = FileManager.default
        if (try? files.destinationOfSymbolicLink(atPath: link)) != nil {
            try? files.removeItem(atPath: link)
        } else if files.fileExists(atPath: link) {
            throw .occupied(link)
        }
        do {
            try files.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try files.createSymbolicLink(atPath: link, withDestinationPath: helper)
        } catch {
            throw .failed(link, error.localizedDescription)
        }
    }

    /// Existing folders must be writable; a missing one counts when its parent is, so `~/.local/bin` can be created.
    static func canWrite(_ folder: String) -> Bool {
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        if files.fileExists(atPath: folder, isDirectory: &isDirectory) { return isDirectory.boolValue && files.isWritableFile(atPath: folder) }
        let parent = (folder as NSString).deletingLastPathComponent
        return parent != folder && canWrite(parent)
    }

    static func standardized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

public struct CommandLineToolInstallation: Sendable, Equatable {
    public var linkPath: String
    public var isOnPath: Bool

    /// The line to add to the shell profile when the folder isn't on PATH yet.
    public var pathInstruction: String? {
        guard !isOnPath else { return nil }
        let folder = (linkPath as NSString).deletingLastPathComponent
        return "export PATH=\"\(folder):$PATH\""
    }
}

public enum CommandLineToolInstallError: Error, Equatable, CustomStringConvertible {
    case noWritableFolder([String])
    case occupied(String)
    case failed(String, String)

    public var description: String {
        switch self {
        case .noWritableFolder(let folders): "None of \(folders.joined(separator: ", ")) can be written to."
        case .occupied(let path): "\(path) already exists and is not a link. Remove it and try again."
        case .failed(let path, let reason): "Could not link \(path): \(reason)"
        }
    }
}
