import Foundation

/// Parses the git output behind an agent's changes peek and diff view.
public enum GitChangeParser {
    /// `git diff --numstat`: "added<TAB>removed<TAB>path", with "-" counts for binary files.
    public static func numstat(_ output: String) -> [FileChange] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, !fields[2].isEmpty else { return nil }
            return FileChange(path: unquoted(String(fields[2])), added: Int(fields[0]), removed: Int(fields[1]))
        }
    }

    /// `git ls-files --others`: one path per line.
    public static func paths(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).map { unquoted(String($0)) }
    }

    /// Lines in a text file, or nil when it looks binary.
    public static func lineCount(of data: Data) -> Int? {
        guard !data.contains(0) else { return nil }
        let newlines = data.reduce(0) { $1 == UInt8(ascii: "\n") ? $0 + 1 : $0 }
        return data.last.map { $0 == UInt8(ascii: "\n") ? newlines : newlines + 1 } ?? 0
    }

    /// A new-file diff for an untracked file, matching what `git diff` prints for an added one.
    public static func untrackedDiff(path: String, contents: String) -> String {
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        let body = contents.hasSuffix("\n") ? lines.dropLast() : lines[...]
        let header = ["diff --git a/\(path) b/\(path)", "new file (untracked)", "--- /dev/null", "+++ b/\(path)", "@@ -0,0 +1,\(body.count) @@"]
        return (header + body.map { "+" + $0 }).joined(separator: "\n")
    }

    /// Tags each line of a unified diff; "---" and "+++" only count as headers before a file's first hunk.
    public static func diffLines(_ diff: String) -> [DiffLine] {
        var isInHeader = false
        return diff.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { index, line in
            if line.hasPrefix("diff --git") { isInHeader = true }
            if line.hasPrefix("@@") { isInHeader = false }
            return DiffLine(id: index, kind: kind(of: line, isInHeader: isInHeader), text: String(line))
        }
    }

    private static func kind(of line: Substring, isInHeader: Bool) -> DiffLine.Kind {
        if isInHeader { return .fileHeader }
        if line.hasPrefix("@@") { return .hunk }
        if line.hasPrefix("+") { return .added }
        if line.hasPrefix("-") { return .removed }
        return line.hasPrefix("Binary files") ? .fileHeader : .context
    }

    /// Git wraps paths with unusual characters in double quotes.
    private static func unquoted(_ path: String) -> String {
        guard path.count >= 2, path.hasPrefix("\""), path.hasSuffix("\"") else { return path }
        return String(path.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
    }
}
