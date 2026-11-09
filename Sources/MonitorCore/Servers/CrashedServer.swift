import Foundation

/// A dev server as the user thinks of it: the folder it runs in and the port it serves.
public struct ServerIdentity: Sendable, Hashable {
    public var folder: String
    public var port: Int

    public init(folder: String, port: Int) {
        self.folder = folder
        self.port = port
    }
}

extension ListeningPort {
    /// Nil for ports Flightdeck can't watch or relaunch: system daemons, containers and processes without a folder.
    public var serverIdentity: ServerIdentity? {
        guard isDevServer, containerName == nil, let folder = project?.rootPath ?? workingDirectory else { return nil }
        return ServerIdentity(folder: folder, port: port)
    }
}

/// A dev server that stopped listening without the user stopping it from Flightdeck.
public struct CrashedServer: Sendable, Hashable, Identifiable {
    public var id: ServerIdentity
    /// The server as it was last seen, with its command and folder.
    public var server: ListeningPort
    public var stoppedAt: Date

    public init(id: ServerIdentity, server: ListeningPort, stoppedAt: Date) {
        self.id = id
        self.server = server
        self.stoppedAt = stoppedAt
    }
}
