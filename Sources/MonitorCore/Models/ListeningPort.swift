import Foundation

/// One process listening on one TCP port, enriched with project context.
public struct ListeningPort: Sendable, Identifiable, Hashable {
    public var id: String { "\(pid):\(port)" }
    public var port: Int
    public var pid: Int32
    public var processName: String
    public var isLocalOnly: Bool
    public var commandLine: String
    public var workingDirectory: String?
    public var project: DevProject?
    public var framework: Framework?
    public var containerName: String?

    public init(port: Int, pid: Int32, processName: String, isLocalOnly: Bool, commandLine: String = "", workingDirectory: String? = nil, project: DevProject? = nil, framework: Framework? = nil, containerName: String? = nil) {
        self.port = port
        self.pid = pid
        self.processName = processName
        self.isLocalOnly = isLocalOnly
        self.commandLine = commandLine
        self.workingDirectory = workingDirectory
        self.project = project
        self.framework = framework
        self.containerName = containerName
    }

    /// True for ports that belong to something the user is developing, not system daemons.
    public var isDevServer: Bool {
        project != nil || framework != nil || containerName != nil
    }

    public var title: String {
        if let containerName { return containerName }
        if let project { return project.name }
        return processName
    }
}
