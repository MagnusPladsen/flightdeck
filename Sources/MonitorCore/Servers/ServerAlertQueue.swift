import Foundation

/// Holds crash alerts back while it's quiet; once it isn't, releases those still down along with the new ones.
public struct ServerAlertQueue: Sendable {
    public private(set) var held: [CrashedServer] = []

    public init() {}

    public mutating func deliver(_ newCrashes: [CrashedServer], stillCrashed: [CrashedServer], isQuiet: Bool, handling: QuietAlertHandling) -> [CrashedServer] {
        if isQuiet {
            held = handling == .summarize ? held + newCrashes : []
            return []
        }
        let stillDown = Set(stillCrashed.map(\.id))
        let released = held.filter { stillDown.contains($0.id) }
        held = []
        let releasedIDs = Set(released.map(\.id))
        return released + newCrashes.filter { !releasedIDs.contains($0.id) }
    }

    public mutating func discard() {
        held = []
    }
}
