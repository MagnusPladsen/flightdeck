import Foundation

/// Checks a branch name typed for a new worktree against git's ref-name rules
/// (`git check-ref-format --branch`), and names the worktree folder after it.
public enum BranchNameValidator {
    private static let forbiddenCharacters = CharacterSet(charactersIn: " ~^:?*[\\").union(.controlCharacters)

    /// Why the name can't be a branch, or nil when it can.
    public static func problem(with name: String) -> String? {
        if name.isEmpty { return "Type a branch name." }
        if name.unicodeScalars.contains(where: forbiddenCharacters.contains) { return "Branch names can't contain spaces or ~ ^ : ? * [ \\." }
        if name.hasPrefix("-") || name.hasPrefix("/") || name.hasSuffix("/") { return "Branch names can't start with - or start or end with /." }
        if name.hasSuffix(".") || name.hasSuffix(".lock") { return "Branch names can't end with . or .lock." }
        if name == "@" || ["..", "//", "@{"].contains(where: name.contains) { return "Branch names can't be @ or contain .., // or @{." }
        if name.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { return "No part of a branch name can start with a dot." }
        return nil
    }

    /// `feat/search` -> `feat-search`, so every worktree is one folder deep.
    public static func folderName(for branch: String) -> String {
        branch.replacingOccurrences(of: "/", with: "-")
    }
}
