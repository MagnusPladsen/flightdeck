import Foundation

/// Where "New agent" puts a new worktree.
public enum WorktreeLocation: String, CaseIterable, Codable, Sendable {
    /// Next to the repository's other worktrees, or in a sibling folder when it has none.
    case automatic
    /// `~/git/shop-worktrees/<name>`, beside the repository.
    case siblingFolder
    /// `~/git/shop/.claude/worktrees/<name>`, where Claude Code puts its own.
    case insideRepository

    public var title: String {
        switch self {
        case .automatic: "Next to the repository's other worktrees"
        case .siblingFolder: "In a <repository>-worktrees folder beside it"
        case .insideRepository: "Inside the repository, in .claude/worktrees"
        }
    }

    /// The folder for a new worktree called `folderName`.
    public func path(for folderName: String, repositoryRoot: String, existingWorktrees: [String]) -> String {
        (parentFolder(repositoryRoot: repositoryRoot, existingWorktrees: existingWorktrees) as NSString).appendingPathComponent(folderName)
    }

    func parentFolder(repositoryRoot: String, existingWorktrees: [String]) -> String {
        switch self {
        case .siblingFolder: Self.siblingFolder(of: repositoryRoot)
        case .insideRepository: (repositoryRoot as NSString).appendingPathComponent(".claude/worktrees")
        case .automatic: Self.commonParent(of: existingWorktrees.filter { $0 != repositoryRoot }) ?? Self.siblingFolder(of: repositoryRoot)
        }
    }

    private static func siblingFolder(of root: String) -> String {
        let name = (root as NSString).lastPathComponent
        return ((root as NSString).deletingLastPathComponent as NSString).appendingPathComponent("\(name)-worktrees")
    }

    /// The folder holding most of the worktrees; ties go to the one listed first.
    private static func commonParent(of paths: [String]) -> String? {
        let parents = paths.map { ($0 as NSString).deletingLastPathComponent }
        let counts = parents.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return parents.max { counts[$0, default: 0] < counts[$1, default: 0] }
    }
}
