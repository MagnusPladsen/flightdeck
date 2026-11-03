import Foundation

/// A git checkout that a process is running inside.
public struct DevProject: Sendable, Hashable {
    /// Display name: the main repository's folder name.
    public var name: String
    public var rootPath: String
    public var branch: String?
    public var isWorktree: Bool
    /// Folder name of the worktree checkout when `isWorktree` is true.
    public var worktreeName: String?

    public init(name: String, rootPath: String, branch: String?, isWorktree: Bool, worktreeName: String?) {
        self.name = name
        self.rootPath = rootPath
        self.branch = branch
        self.isWorktree = isWorktree
        self.worktreeName = worktreeName
    }
}

/// A recognised dev server or tool, e.g. Next.js or Vite.
public struct Framework: Sendable, Hashable {
    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
