import Foundation

/// Measures what an agent changed in its repository since it started. Methods block on git,
/// so call them off the main thread.
public struct AgentChangeCollector: Sendable {
    static let maxUntrackedFiles = 200
    static let maxUntrackedFileBytes = 512 * 1024
    static let maxUntrackedBytesPerRefresh = 4 * 1024 * 1024
    static let maxDiffBytes = 2 * 1024 * 1024

    private let git: String?

    public init(git: String? = CommandRunner.locate("git")) {
        self.git = git
    }

    /// The last commit on HEAD made before the agent started, else HEAD itself. Nil outside a git repository.
    public func baseline(forFolder folder: String, startedAt: Date?) -> ChangeBaseline? {
        guard let root = run(["-C", folder, "rev-parse", "--show-toplevel"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !root.isEmpty else { return nil }
        let before = startedAt.flatMap { run(["-C", root, "rev-list", "-1", "--before=\(Int($0.timeIntervalSince1970))", "HEAD"]) }
        let commit = [before, run(["-C", root, "rev-parse", "HEAD"])].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        return commit.map { ChangeBaseline(repositoryRoot: root, commit: $0) }
    }

    public func changes(since baseline: ChangeBaseline) -> AgentChanges? {
        guard let numstat = run(["-C", baseline.repositoryRoot, "-c", "core.quotepath=off", "diff", "--numstat", "--no-renames", baseline.commit]) else { return nil }
        let untracked = untrackedContents(in: baseline.repositoryRoot).map { path, data in
            let count = data.flatMap(GitChangeParser.lineCount)
            return FileChange(path: path, added: count, removed: count.map { _ in 0 }, isUntracked: true)
        }
        return AgentChanges(baseline: baseline, files: GitChangeParser.numstat(numstat) + untracked)
    }

    /// `git diff <baseline>` followed by a new-file diff for each untracked text file.
    public func diff(since baseline: ChangeBaseline) -> String {
        let tracked = run(["-C", baseline.repositoryRoot, "-c", "core.quotepath=off", "diff", "--no-renames", "--no-color", baseline.commit], timeout: 15) ?? ""
        let untracked = untrackedContents(in: baseline.repositoryRoot).compactMap { path, data -> String? in
            guard let data, !data.contains(0) else { return nil }
            return GitChangeParser.untrackedDiff(path: path, contents: String(decoding: data, as: UTF8.self))
        }
        let diff = ([tracked.trimmingCharacters(in: .newlines)] + untracked).filter { !$0.isEmpty }.joined(separator: "\n")
        return diff.utf8.count > Self.maxDiffBytes ? String(decoding: Data(diff.utf8.prefix(Self.maxDiffBytes)), as: UTF8.self) + "\n… diff truncated" : diff
    }

    private func untrackedPaths(in root: String) -> [String] {
        GitChangeParser.paths(run(["-C", root, "-c", "core.quotepath=off", "ls-files", "--others", "--exclude-standard"]) ?? "")
    }

    /// Untracked files with their contents, nil for those too big, not regular files, or past the byte budget.
    private func untrackedContents(in root: String) -> [(path: String, data: Data?)] {
        var remainingBytes = Self.maxUntrackedBytesPerRefresh
        return untrackedPaths(in: root).prefix(Self.maxUntrackedFiles).map { path in
            let data = contents(of: path, in: root, limit: min(Self.maxUntrackedFileBytes, remainingBytes))
            remainingBytes -= data?.count ?? 0
            return (path, data)
        }
    }

    private func contents(of path: String, in root: String, limit: Int) -> Data? {
        let url = URL(fileURLWithPath: root).appendingPathComponent(path).resolvingSymlinksInPath()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = (attributes[.size] as? NSNumber)?.intValue, size <= limit else { return nil }
        return try? Data(contentsOf: url)
    }

    private func run(_ arguments: [String], timeout: TimeInterval = 5) -> String? {
        guard let git else { return nil }
        let result = CommandRunner.run(git, arguments, timeout: timeout)
        return result.exitCode == 0 && !result.didTimeOut ? result.output : nil
    }
}
