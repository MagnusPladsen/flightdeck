import Foundation

/// Shortest walks between tiles, for click-to-walk.
public enum OfficePathfinder {
    /// Tiles to step through after `start`, ending at `goal`; nil when the goal can't be reached.
    public static func path(in grid: OfficeGrid, from start: TilePoint, to goal: TilePoint) -> [TilePoint]? {
        guard grid.isWalkable(goal) else { return nil }
        if start == goal { return [] }
        var cameFrom: [TilePoint: TilePoint] = [:]
        var cost: [TilePoint: Int] = [start: 0]
        var open: Set<TilePoint> = [start]
        while let current = open.min(by: { estimate($0, cost, goal) < estimate($1, cost, goal) }) {
            if current == goal { return route(to: goal, from: start, cameFrom: cameFrom) }
            open.remove(current)
            for neighbour in current.neighbours where grid.isWalkable(neighbour) {
                let stepCost = (cost[current] ?? 0) + 1
                guard stepCost < cost[neighbour, default: .max] else { continue }
                cost[neighbour] = stepCost
                cameFrom[neighbour] = current
                open.insert(neighbour)
            }
        }
        return nil
    }

    private static func estimate(_ tile: TilePoint, _ cost: [TilePoint: Int], _ goal: TilePoint) -> Int {
        (cost[tile] ?? 0) + abs(tile.x - goal.x) + abs(tile.y - goal.y)
    }

    private static func route(to goal: TilePoint, from start: TilePoint, cameFrom: [TilePoint: TilePoint]) -> [TilePoint] {
        var tiles = [goal]
        while let previous = cameFrom[tiles[tiles.count - 1]], previous != start { tiles.append(previous) }
        return tiles.reversed()
    }
}

/// Moves the player with wall collision.
public enum OfficeMotion {
    /// Half the width of the player's footprint, in tiles.
    public static let radius = 0.3

    /// Moves one axis at a time, so walking diagonally into a wall slides along it.
    public static func move(_ position: OfficePoint, by delta: OfficePoint, in grid: OfficeGrid) -> OfficePoint {
        var moved = position
        let alongX = OfficePoint(x: moved.x + delta.x, y: moved.y)
        if canStand(at: alongX, in: grid) { moved = alongX }
        let alongY = OfficePoint(x: moved.x, y: moved.y + delta.y)
        if canStand(at: alongY, in: grid) { moved = alongY }
        return moved
    }

    public static func canStand(at point: OfficePoint, in grid: OfficeGrid) -> Bool {
        let corners = [(-radius, -radius), (radius, -radius), (-radius, radius), (radius, radius)]
        return corners.allSatisfy { grid.isWalkable(OfficePoint(x: point.x + $0.0, y: point.y + $0.1).tile) }
    }
}

/// How the office maps onto the view: the largest whole-number pixel scale that fits the office's height, centred,
/// scrolling sideways with the player when the office is wider than the view.
public struct OfficeCamera: Equatable, Sendable {
    /// Art pixels per tile.
    public static let tilePixels = 16.0

    /// Screen points per art pixel.
    public let scale: Double
    /// Screen position of the map's top-left corner.
    public let originX: Double
    public let originY: Double

    public var tileSize: Double { Self.tilePixels * scale }

    public init(mapWidth: Int, mapHeight: Int, viewWidth: Double, viewHeight: Double, focus: OfficePoint) {
        let fit = viewHeight / (Double(mapHeight) * Self.tilePixels)
        scale = min(3, max(2, fit.rounded(.down)))
        let tileSize = Self.tilePixels * scale
        originX = Self.origin(view: viewWidth, map: Double(mapWidth) * tileSize, focus: focus.x * tileSize)
        originY = Self.origin(view: viewHeight, map: Double(mapHeight) * tileSize, focus: focus.y * tileSize)
    }

    private static func origin(view: Double, map: Double, focus: Double) -> Double {
        if map <= view { return ((view - map) / 2).rounded() }
        return min(0, max(view - map, view / 2 - focus)).rounded()
    }

    public func screenX(_ x: Double) -> Double { originX + x * tileSize }
    public func screenY(_ y: Double) -> Double { originY + y * tileSize }

    public func officePoint(screenX x: Double, screenY y: Double) -> OfficePoint {
        OfficePoint(x: (x - originX) / tileSize, y: (y - originY) / tileSize)
    }
}
