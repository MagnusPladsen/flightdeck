import Foundation

/// Why a dev server isn't where the user expects it.
public enum PortConflict: Sendable, Hashable {
    /// Another project listens on the same port number, typically one on IPv4 and one on IPv6.
    case sharedPort(otherTitle: String)
    /// The framework moved up from its default port because another project holds it.
    case displaced(wantedPort: Int, holderTitle: String)

    public var summary: String {
        switch self {
        case .sharedPort(let other): "\(other) also listens on this port"
        case .displaced(let wanted, let holder): "Wanted :\(wanted), taken by \(holder)"
        }
    }
}

/// Conflicts between dev servers of different projects, keyed by `ListeningPort.id`.
/// Only flags what the ports show: worktrees of one project bumping each other is expected.
public enum PortConflicts {
    /// How far above its default a framework searches for a free port.
    static let maximumBump = 10

    public static func detect(in ports: [ListeningPort]) -> [String: PortConflict] {
        let servers = ports.filter { $0.serverIdentity != nil }
        var conflicts: [String: PortConflict] = [:]
        for server in servers {
            if let conflict = sharedPort(of: server, among: servers) ?? displacement(of: server, among: servers) {
                conflicts[server.id] = conflict
            }
        }
        return conflicts
    }

    static func sharedPort(of server: ListeningPort, among servers: [ListeningPort]) -> PortConflict? {
        let other = servers.first { $0.port == server.port && $0.pid != server.pid && isDifferentProject($0, server) }
        return other.map { .sharedPort(otherTitle: $0.title) }
    }

    static func displacement(of server: ListeningPort, among servers: [ListeningPort]) -> PortConflict? {
        guard let wanted = FrameworkDefaultPorts.port(for: server.framework),
              (wanted + 1...wanted + maximumBump).contains(server.port),
              !mentionsPort(server.commandLine, server.port),
              let holder = servers.first(where: { $0.port == wanted && isDifferentProject($0, server) })
        else { return nil }
        return .displaced(wantedPort: wanted, holderTitle: holder.title)
    }

    static func isDifferentProject(_ lhs: ListeningPort, _ rhs: ListeningPort) -> Bool {
        (lhs.project?.name ?? lhs.workingDirectory) != (rhs.project?.name ?? rhs.workingDirectory)
    }

    /// A port given on the command line was chosen on purpose, so it isn't a displacement.
    static func mentionsPort(_ commandLine: String, _ port: Int) -> Bool {
        commandLine.split(separator: " ").contains { token in
            token == "--port" || token == "-p" || token.hasPrefix("--port=") || token == "\(port)" || token.hasSuffix(":\(port)")
        }
    }
}

/// The port each framework's dev server starts on when nothing else asks for one.
public enum FrameworkDefaultPorts {
    static let byFrameworkID: [String: Int] = [
        "nextjs": 3000, "nuxt": 3000, "remix": 3000, "cra": 3000, "rails": 3000,
        "vite": 5173, "sveltekit": 5173, "astro": 4321, "angular": 4200, "storybook": 6006,
        "expo": 8081, "metro": 8081, "django": 8000, "fastapi": 8000, "laravel": 8000,
        "flask": 5000, "hugo": 1313, "jekyll": 4000,
    ]

    public static func port(for framework: Framework?) -> Int? {
        framework.flatMap { byFrameworkID[$0.id] }
    }
}
