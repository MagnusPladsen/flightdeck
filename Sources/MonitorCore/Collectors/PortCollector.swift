import Foundation

/// Lists listening TCP ports and works out which project, worktree and framework each belongs to.
public final class PortCollector: @unchecked Sendable {
    private let scanner: ListeningSocketScanner
    private let processes: ProcessInspector
    private let projects: ProjectResolver
    private let containers: DockerContainerLookup

    public init(scanner: ListeningSocketScanner = PlatformServices.makeListeningSocketScanner(),
                processes: ProcessInspector = PlatformServices.makeProcessInspector(),
                projects: ProjectResolver,
                containers: DockerContainerLookup = DockerContainerLookup()) {
        self.scanner = scanner
        self.processes = processes
        self.projects = projects
        self.containers = containers
    }

    public func collect() -> [ListeningPort] {
        let sockets = scanner.scanListeningSockets()
        let containerNames = sockets.contains(where: { DockerContainerLookup.isDockerProcess($0.processName) }) ? containers.containerNamesByHostPort() : [:]

        return sockets.map { socket in
            let arguments = processes.arguments(of: socket.pid)
            let commandLine = arguments.joined(separator: " ")
            let workingDirectory = processes.workingDirectory(of: socket.pid)
            let project = workingDirectory.flatMap(projects.project(containing:))
            let framework = FrameworkDetector.detect(commandLine: commandLine, processName: socket.processName, projectRoot: project?.rootPath)
            return ListeningPort(
                port: socket.port,
                pid: socket.pid,
                processName: socket.processName,
                isLocalOnly: socket.isLocalOnly,
                commandLine: commandLine,
                workingDirectory: workingDirectory,
                project: project,
                framework: framework,
                containerName: containerNames[socket.port]
            )
        }
        .sorted { lhs, rhs in
            if lhs.isDevServer != rhs.isDevServer { return lhs.isDevServer }
            return lhs.port < rhs.port
        }
    }
}

/// Docker Desktop and OrbStack publish container ports from a single helper process; ask docker which container owns each.
public final class DockerContainerLookup: @unchecked Sendable {
    private var cached: (names: [Int: String], time: Date)?
    private let cacheDuration: TimeInterval = 15
    private let lock = NSLock()

    public init() {}

    static func isDockerProcess(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered.contains("docker") || lowered.contains("vpnkit") || lowered.contains("orbstack")
    }

    public func containerNamesByHostPort() -> [Int: String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached, Date().timeIntervalSince(cached.time) < cacheDuration { return cached.names }
        guard let docker = CommandRunner.locate("docker") else { return [:] }
        let output = CommandRunner.run(docker, ["ps", "--format", "{{.Names}}\t{{.Ports}}"], timeout: 3).output
        let names = Self.parse(output)
        cached = (names, Date())
        return names
    }

    /// Line: `db\t0.0.0.0:5432->5432/tcp, :::5432->5432/tcp`
    static func parse(_ output: String) -> [Int: String] {
        var names: [Int: String] = [:]
        for line in output.split(separator: "\n") {
            let columns = line.split(separator: "\t", maxSplits: 1)
            guard columns.count == 2 else { continue }
            for mapping in columns[1].split(separator: ",") {
                guard let arrow = mapping.range(of: "->") else { continue }
                let hostSide = mapping[..<arrow.lowerBound]
                if let colon = hostSide.lastIndex(of: ":"), let port = Int(hostSide[hostSide.index(after: colon)...]) {
                    names[port] = String(columns[0])
                }
            }
        }
        return names
    }
}
