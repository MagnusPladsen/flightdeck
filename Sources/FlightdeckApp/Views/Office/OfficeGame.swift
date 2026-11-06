import MonitorCore
import Observation

enum OfficeDirection: Hashable {
    case up, down, left, right

    var delta: OfficePoint {
        switch self {
        case .up: OfficePoint(x: 0, y: -1)
        case .down: OfficePoint(x: 0, y: 1)
        case .left: OfficePoint(x: -1, y: 0)
        case .right: OfficePoint(x: 1, y: 0)
        }
    }
}

/// The player and what they're doing: walking by keys or along a clicked path, and which agent's card is open.
@MainActor
@Observable
final class OfficeGame {
    /// Tiles per second.
    static let walkingSpeed = 4.5
    /// How close the player must be to an agent for its card to open.
    static let talkingDistance = 2.2

    private(set) var map = OfficeMap.build(agents: [], ports: [])
    private(set) var player = OfficePoint(x: 0, y: 0)
    private(set) var isWalking = false
    private(set) var facesLeft = false
    /// The agent picked by clicking it or its post; stays open until the player walks off by key.
    private(set) var selectedPID: Int32?
    /// The agent whose card the player closed with Escape, until they walk away from it.
    private var dismissedPID: Int32?
    private var heldDirections: Set<OfficeDirection> = []
    private var path: [TilePoint] = []
    private var hasPlacedPlayer = false

    /// The agent whose card is showing.
    var cardPID: Int32? {
        if let selectedPID { return selectedPID }
        guard let nearby = nearbyPID, nearby != dismissedPID else { return nil }
        return nearby
    }

    var nearbyPID: Int32? {
        map.desks.compactMap(\.agentPID)
            .compactMap { pid in map.position(of: pid).map { (pid, $0.distance(to: player)) } }
            .filter { $0.1 < Self.talkingDistance }
            .min { $0.1 < $1.1 }?.0
    }

    func update(map newMap: OfficeMap) {
        map = newMap
        if !hasPlacedPlayer {
            player = newMap.playerStart
            hasPlacedPlayer = true
        } else if !OfficeMotion.canStand(at: player, in: newMap.grid) {
            player = newMap.grid.nearestWalkable(to: player.tile)?.center ?? newMap.playerStart
            path = []
        }
        if let selectedPID, newMap.desk(of: selectedPID) == nil { self.selectedPID = nil }
    }

    func press(_ direction: OfficeDirection) {
        heldDirections.insert(direction)
        path = []
        selectedPID = nil
    }

    func release(_ direction: OfficeDirection) {
        heldDirections.remove(direction)
    }

    func releaseAll() {
        heldDirections = []
    }

    /// Walks to the agent's desk and opens its card.
    func select(_ pid: Int32) {
        guard let desk = map.desk(of: pid) else { return }
        selectedPID = pid
        dismissedPID = nil
        walk(to: desk.approach)
    }

    func walk(to tile: TilePoint) {
        guard let goal = map.grid.nearestWalkable(to: tile) else { return }
        path = OfficePathfinder.path(in: map.grid, from: player.tile, to: goal) ?? []
    }

    func closeCard() {
        dismissedPID = cardPID
        selectedPID = nil
    }

    func tick(seconds: Double) {
        let step = Self.walkingSpeed * seconds
        let previous = player
        if !heldDirections.isEmpty { walkByKeys(step) } else { followPath(step) }
        let moved = player != previous
        if isWalking != moved { isWalking = moved }
        if moved, player.x != previous.x { facesLeft = player.x < previous.x }
        if let dismissedPID, nearbyPID != dismissedPID { self.dismissedPID = nil }
    }

    private func walkByKeys(_ step: Double) {
        let sum = heldDirections.map(\.delta).reduce(OfficePoint(x: 0, y: 0), +)
        let length = (sum.x * sum.x + sum.y * sum.y).squareRoot()
        guard length > 0 else { return }
        player = OfficeMotion.move(player, by: OfficePoint(x: sum.x / length * step, y: sum.y / length * step), in: map.grid)
    }

    private func followPath(_ step: Double) {
        guard let next = path.first?.center else { return }
        let distance = player.distance(to: next)
        if distance <= step {
            player = next
            path.removeFirst()
        } else {
            player = OfficePoint(x: player.x + (next.x - player.x) / distance * step, y: player.y + (next.y - player.y) / distance * step)
        }
    }
}
