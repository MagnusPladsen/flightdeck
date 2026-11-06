import Foundation

/// Parses the machine-readable output of the git and gh commands the worktree overview runs.
public enum GitOutputParser {
    /// `git worktree list --porcelain`: blank-line separated blocks of `key value` lines.
    public static func worktreeList(_ output: String) -> [WorktreeListEntry] {
        output.components(separatedBy: "\n\n").compactMap { block in
            worktreeEntry(lines: block.split(separator: "\n").map(String.init))
        }
    }

    private static func worktreeEntry(lines: [String]) -> WorktreeListEntry? {
        guard let first = lines.first, first.hasPrefix("worktree ") else { return nil }
        var entry = WorktreeListEntry(path: String(first.dropFirst("worktree ".count)))
        for line in lines.dropFirst() {
            let (key, value) = splitKey(line)
            switch key {
            case "HEAD": entry.head = value
            case "branch": entry.branch = value.map(shortBranchName)
            case "bare": entry.isBare = true
            case "locked": entry.isLocked = true
            case "prunable": entry.isPrunable = true
            default: break
            }
        }
        return entry
    }

    /// `git status --porcelain=v2 --branch`.
    public static func status(_ output: String) -> GitStatusSummary {
        var summary = GitStatusSummary()
        for line in output.split(separator: "\n").map(String.init) {
            if line.hasPrefix("# branch.upstream ") {
                summary.upstream = String(line.dropFirst("# branch.upstream ".count))
            } else if line.hasPrefix("# branch.ab ") {
                (summary.ahead, summary.behind) = aheadBehind(line.dropFirst("# branch.ab ".count))
            } else if !line.hasPrefix("#") && !line.hasPrefix("!") {
                summary.changedFileCount += 1
            }
        }
        return summary
    }

    /// `git log -1 --format=%ct`: seconds since 1970.
    public static func commitDate(_ output: String) -> Date? {
        TimeInterval(output.trimmingCharacters(in: .whitespacesAndNewlines)).map(Date.init(timeIntervalSince1970:))
    }

    /// `gh pr list --state all --json number,state,headRefName,url`, newest first.
    /// Keeps the newest pull request for each branch.
    public static func pullRequestsByBranch(_ json: String) -> [String: PullRequestInfo]? {
        guard let rows = try? JSONDecoder().decode([PullRequestRow].self, from: Data(json.utf8)) else { return nil }
        var byBranch: [String: PullRequestInfo] = [:]
        for row in rows where byBranch[row.headRefName] == nil {
            byBranch[row.headRefName] = PullRequestInfo(number: row.number, state: row.state, url: row.url)
        }
        return byBranch
    }

    /// `git@github.com:owner/repo.git` and `https://github.com/owner/repo` both count.
    public static func isGitHubRemote(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains("github.com:") || trimmed.contains("github.com/")
    }

    private struct PullRequestRow: Decodable {
        var number: Int
        var state: PullRequestState
        var headRefName: String
        var url: String
    }

    private static func splitKey(_ line: String) -> (String, String?) {
        guard let space = line.firstIndex(of: " ") else { return (line, nil) }
        return (String(line[..<space]), String(line[line.index(after: space)...]))
    }

    private static func shortBranchName(_ ref: String) -> String {
        ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
    }

    /// `+3 -1` -> (3, 1).
    private static func aheadBehind(_ text: Substring) -> (Int, Int) {
        let numbers = text.split(separator: " ").compactMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))) }
        return (numbers.first ?? 0, numbers.dropFirst().first ?? 0)
    }
}
