import Foundation

/// Dashboard sections that fold down to their header. The state is shared by every layout.
public enum CollapsibleSection: String, CaseIterable, Codable, Sendable {
    case system, nowPlaying

    public static func toggling(_ section: CollapsibleSection, in collapsed: [CollapsibleSection]) -> [CollapsibleSection] {
        collapsed.contains(section) ? collapsed.filter { $0 != section } : allCases.filter { $0 == section || collapsed.contains($0) }
    }
}
