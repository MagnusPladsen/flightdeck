import Foundation

/// Maps a working directory to the git checkout (main repo or worktree) that contains it.
public final class ProjectResolver: @unchecked Sendable {
    private static let projectMarkers = ["package.json", "Cargo.toml", "go.mod", "pyproject.toml", "Gemfile", "composer.json", "Package.swift", "project.godot"]

    private let fileManager: FileManager
    private let homeDirectory: String
    private var cache: [String: DevProject?] = [:]
    private let lock = NSLock()

    public init(fileManager: FileManager = .default, homeDirectory: String = NSHomeDirectory()) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    public func project(containing directory: String) -> DevProject? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[directory] { return cached }
        let resolved = resolve(directory)
        cache[directory] = resolved
        return resolved
    }

    /// Branches change while the app runs; call periodically so they stay fresh.
    public func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    private func resolve(_ directory: String) -> DevProject? {
        guard isInsideUserSpace(directory) else { return nil }
        var markerDirectory: String?
        var current = directory

        while isInsideUserSpace(current) {
            let gitPath = current + "/.git"
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath, isDirectory: &isDirectory) {
                return isDirectory.boolValue ? mainCheckout(at: current) : worktreeCheckout(at: current, gitFile: gitPath)
            }
            if markerDirectory == nil, Self.projectMarkers.contains(where: { fileManager.fileExists(atPath: current + "/" + $0) }) {
                markerDirectory = current
            }
            current = (current as NSString).deletingLastPathComponent
        }

        return markerDirectory.map { DevProject(name: ($0 as NSString).lastPathComponent, rootPath: $0, branch: nil, isWorktree: false, worktreeName: nil) }
    }

    private func isInsideUserSpace(_ path: String) -> Bool {
        path.hasPrefix(homeDirectory + "/") && !path.hasPrefix(homeDirectory + "/Library")
    }

    private func mainCheckout(at root: String) -> DevProject {
        DevProject(name: (root as NSString).lastPathComponent, rootPath: root, branch: Self.branch(fromHeadFile: root + "/.git/HEAD"), isWorktree: false, worktreeName: nil)
    }

    /// A worktree's `.git` is a file: `gitdir: /path/to/main/.git/worktrees/<name>`.
    private func worktreeCheckout(at root: String, gitFile: String) -> DevProject {
        let contents = (try? String(contentsOfFile: gitFile, encoding: .utf8)) ?? ""
        let gitDirectory = Self.parseGitDirectory(contents, relativeTo: root)
        let mainRoot = gitDirectory.flatMap(Self.mainRepositoryRoot(fromWorktreeGitDirectory:))
        let isWorktree = mainRoot != nil
        return DevProject(
            name: ((mainRoot ?? root) as NSString).lastPathComponent,
            rootPath: root,
            branch: gitDirectory.flatMap { Self.branch(fromHeadFile: $0 + "/HEAD") },
            isWorktree: isWorktree,
            worktreeName: isWorktree ? (root as NSString).lastPathComponent : nil
        )
    }

    static func parseGitDirectory(_ gitFileContents: String, relativeTo root: String) -> String? {
        guard let line = gitFileContents.split(separator: "\n").first(where: { $0.hasPrefix("gitdir:") }) else { return nil }
        let path = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        return path.hasPrefix("/") ? path : ((root as NSString).appendingPathComponent(path) as NSString).standardizingPath
    }

    static func mainRepositoryRoot(fromWorktreeGitDirectory gitDirectory: String) -> String? {
        guard let range = gitDirectory.range(of: "/.git/worktrees/") else { return nil }
        return String(gitDirectory[..<range.lowerBound])
    }

    /// `ref: refs/heads/main` -> "main"; a detached HEAD gives the short hash.
    static func branch(fromHeadFile path: String) -> String? {
        guard let head = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if head.hasPrefix("ref: refs/heads/") { return String(head.dropFirst("ref: refs/heads/".count)) }
        return head.isEmpty ? nil : String(head.prefix(7))
    }
}
