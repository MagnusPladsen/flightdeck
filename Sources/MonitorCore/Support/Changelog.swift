import Foundation

/// One release in CHANGELOG.md: a `## <version> — <date>` heading and its `- ` bullets.
public struct ChangelogEntry: Equatable, Sendable {
    public let version: String
    public let date: String
    public let items: [String]

    public init(version: String, date: String, items: [String]) {
        self.version = version
        self.date = date
        self.items = items
    }
}

public enum Changelog {
    /// The releases in file order, newest first. Text outside a release heading is ignored.
    public static func parse(_ markdown: String) -> [ChangelogEntry] {
        var entries: [ChangelogEntry] = []
        var heading: (version: String, date: String)?
        var items: [String] = []

        func finishEntry() {
            if let heading { entries.append(ChangelogEntry(version: heading.version, date: heading.date, items: items)) }
            items = []
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("## ") {
                finishEntry()
                heading = parseHeading(String(text.dropFirst(3)))
            } else if text.hasPrefix("- "), heading != nil {
                items.append(String(text.dropFirst(2)))
            }
        }
        finishEntry()
        return entries
    }

    /// The entries newer than `lastSeen`, up to and including `current`.
    public static func entries(_ entries: [ChangelogEntry], after lastSeen: String, through current: String) -> [ChangelogEntry] {
        entries.filter { isVersion($0.version, newerThan: lastSeen) && !isVersion($0.version, newerThan: current) }
    }

    /// Compares dotted versions number by number, so 1.0.10 is newer than 1.0.9.
    public static func isVersion(_ version: String, newerThan other: String) -> Bool {
        version.compare(other, options: .numeric) == .orderedDescending
    }

    private static func parseHeading(_ text: String) -> (version: String, date: String) {
        let parts = text.components(separatedBy: "—").map { $0.trimmingCharacters(in: .whitespaces) }
        return (parts[0], parts.count > 1 ? parts[1] : "")
    }
}
