import Foundation

/// Adds a worktree for a branch with `git worktree add`, reusing the branch when it exists.
/// Blocks on git, so call it off the main thread.
public struct WorktreeCreator: Sendable {
    private let git: String?

    public init(git: String? = CommandRunner.locate("git")) {
        self.git = git
    }

    /// A new branch starts from the main checkout's current commit.
    public func create(branch: String, at path: String, in repositoryRoot: String) -> Result<Void, AgentLaunchError> {
        guard let git else { return .failure(.worktreeFailed("git not found")) }
        if FileManager.default.fileExists(atPath: path) { return .failure(.folderTaken(path: path)) }
        let arguments = branchExists(branch, in: repositoryRoot, git: git) ? [path, branch] : ["-b", branch, path]
        let result = CommandRunner.run(git, ["-C", repositoryRoot, "worktree", "add"] + arguments, timeout: 60)
        return result.exitCode == 0 ? .success(()) : .failure(.worktreeFailed("exit code \(result.exitCode)"))
    }

    private func branchExists(_ branch: String, in repositoryRoot: String, git: String) -> Bool {
        CommandRunner.run(git, ["-C", repositoryRoot, "show-ref", "--verify", "--quiet", "refs/heads/\(branch)"]).exitCode == 0
    }
}
