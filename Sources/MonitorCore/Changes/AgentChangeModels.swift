import Foundation

/// One file an agent changed since its baseline commit. Line counts are nil for binary files.
public struct FileChange: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public var path: String
    public var added: Int?
    public var removed: Int?
    public var isUntracked: Bool

    public init(path: String, added: Int?, removed: Int?, isUntracked: Bool = false) {
        self.path = path
        self.added = added
        self.removed = removed
        self.isUntracked = isUntracked
    }
}

/// Totals over the changed files, e.g. "4 files · +120 −18".
public struct ChangeSummary: Sendable, Hashable {
    public var fileCount: Int
    public var added: Int
    public var removed: Int

    public init(fileCount: Int, added: Int, removed: Int) {
        self.fileCount = fileCount
        self.added = added
        self.removed = removed
    }

    public init(files: [FileChange]) {
        self.init(fileCount: files.count, added: files.reduce(0) { $0 + ($1.added ?? 0) }, removed: files.reduce(0) { $0 + ($1.removed ?? 0) })
    }

    public var isEmpty: Bool { fileCount == 0 }

    public var filesText: String { fileCount == 1 ? "1 file" : "\(fileCount) files" }

    public var text: String { "\(filesText) · +\(added) −\(removed)" }
}

/// The commit an agent started from, in the repository it works in.
public struct ChangeBaseline: Sendable, Hashable {
    public var repositoryRoot: String
    public var commit: String

    public init(repositoryRoot: String, commit: String) {
        self.repositoryRoot = repositoryRoot
        self.commit = commit
    }
}

/// Everything an agent changed since its baseline: committed, staged, unstaged and untracked.
public struct AgentChanges: Sendable, Hashable {
    public var baseline: ChangeBaseline
    public var files: [FileChange]

    public init(baseline: ChangeBaseline, files: [FileChange]) {
        self.baseline = baseline
        self.files = files
    }

    public var summary: ChangeSummary { ChangeSummary(files: files) }
}

/// A line of a unified diff, tagged so the diff view can colour it.
public struct DiffLine: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case fileHeader, hunk, added, removed, context
    }

    public var id: Int
    public var kind: Kind
    public var text: String

    public init(id: Int, kind: Kind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}
