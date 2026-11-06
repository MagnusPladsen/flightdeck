import Foundation

/// A position in tile units; (0.5, 0.5) is the centre of the top-left tile.
public struct OfficePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var tile: TilePoint { TilePoint(x: Int(x.rounded(.down)), y: Int(y.rounded(.down))) }

    public func distance(to other: OfficePoint) -> Double {
        hypot(other.x - x, other.y - y)
    }

    public static func + (lhs: OfficePoint, rhs: OfficePoint) -> OfficePoint {
        OfficePoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

/// One tile of the office grid.
public struct TilePoint: Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public var center: OfficePoint { OfficePoint(x: Double(x) + 0.5, y: Double(y) + 0.5) }

    var neighbours: [TilePoint] {
        [TilePoint(x: x + 1, y: y), TilePoint(x: x - 1, y: y), TilePoint(x: x, y: y + 1), TilePoint(x: x, y: y - 1)]
    }
}

public struct TileRect: Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Int { x + width }
    public var maxY: Int { y + height }

    public func contains(_ tile: TilePoint) -> Bool {
        tile.x >= x && tile.x < maxX && tile.y >= y && tile.y < maxY
    }
}

public enum OfficeTile: Sendable, Hashable {
    /// Outside the building.
    case void
    case wall
    /// Low cubicle wall.
    case partition
    case roomFloor
    case hallFloor
    case closetFloor
    /// Floor under a desk, rack or water cooler.
    case furniture

    public var isWalkable: Bool {
        switch self {
        case .roomFloor, .hallFloor, .closetFloor: true
        case .void, .wall, .partition, .furniture: false
        }
    }
}

/// The office's tiles, row by row.
public struct OfficeGrid: Hashable, Sendable {
    public let width: Int
    public let height: Int
    private var tiles: [OfficeTile]

    public init(width: Int, height: Int, filling tile: OfficeTile = .void) {
        self.width = width
        self.height = height
        tiles = Array(repeating: tile, count: width * height)
    }

    public subscript(tile: TilePoint) -> OfficeTile {
        get { contains(tile) ? tiles[tile.y * width + tile.x] : .void }
        set { if contains(tile) { tiles[tile.y * width + tile.x] = newValue } }
    }

    public func contains(_ tile: TilePoint) -> Bool {
        tile.x >= 0 && tile.y >= 0 && tile.x < width && tile.y < height
    }

    public func isWalkable(_ tile: TilePoint) -> Bool {
        self[tile].isWalkable
    }

    mutating func fill(_ rect: TileRect, with tile: OfficeTile) {
        for y in rect.y..<rect.maxY {
            for x in rect.x..<rect.maxX { self[TilePoint(x: x, y: y)] = tile }
        }
    }

    /// Fills the rect's border with walls and its inside with floor.
    mutating func room(_ rect: TileRect, floor: OfficeTile) {
        fill(rect, with: .wall)
        fill(TileRect(x: rect.x + 1, y: rect.y + 1, width: rect.width - 2, height: rect.height - 2), with: floor)
    }

    /// The walkable tile closest to `tile`, searching outwards.
    public func nearestWalkable(to tile: TilePoint) -> TilePoint? {
        if isWalkable(tile) { return tile }
        var visited: Set<TilePoint> = [tile]
        var frontier = [tile]
        while !frontier.isEmpty {
            var next: [TilePoint] = []
            for neighbour in frontier.flatMap(\.neighbours) where contains(neighbour) && visited.insert(neighbour).inserted {
                if isWalkable(neighbour) { return neighbour }
                next.append(neighbour)
            }
            frontier = next
        }
        return nil
    }
}
