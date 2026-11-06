import Foundation

/// A desk slot: two desk tiles, a chair behind them and an aisle spot in front.
public struct OfficeDesk: Hashable, Sendable {
    /// Left of the two desk tiles.
    public var desk: TilePoint
    public var agentPID: Int32?
    /// Bottom-centre of a seated agent.
    public var seat: OfficePoint
    /// Bottom-centre of an agent standing up in the aisle.
    public var standSpot: OfficePoint
    /// Where the player walks to talk to this desk's agent.
    public var approach: TilePoint
}

/// A dev server, drawn as a small rack.
public struct OfficeRack: Hashable, Sendable {
    public var port: ListeningPort
    public var tile: TilePoint
}

/// One checkout's corner of a project room.
public struct OfficeCubicle: Hashable, Sendable {
    /// The checkout's folder.
    public var id: String
    /// Branch or worktree name.
    public var label: String
    /// Columns of the cubicle, from the rack row to the desk row.
    public var rect: TileRect
    public var desks: [OfficeDesk]
    public var racks: [OfficeRack]
}

/// One repository's room.
public struct OfficeRoom: Hashable, Sendable {
    public var name: String
    /// Outer rect, walls included.
    public var rect: TileRect
    public var door: TilePoint
    /// Wall tile, on the hallway side, where the name plate starts.
    public var plate: TilePoint
    public var isAboveHallway: Bool
    public var cubicles: [OfficeCubicle]
}

/// Something the player can hover or click.
public enum OfficeObject: Hashable, Sendable {
    case agent(Int32)
    case rack(ListeningPort)
    case cpuRack
    case waterCooler
    case wallClock
    case jukebox
}

/// The whole office, laid out from the current agents and dev servers.
public struct OfficeMap: Hashable, Sendable {
    public var grid: OfficeGrid
    public var rooms: [OfficeRoom]
    public var closet: TileRect
    public var hallway: TileRect
    public var cpuRack: TileRect
    /// Servers that don't belong to a checkout, e.g. Docker containers.
    public var closetRacks: [OfficeRack]
    public var waterCooler: TilePoint
    /// Next to the water cooler; plays whatever the Mac is playing.
    public var jukebox: TilePoint
    /// Wall tile holding the clock; the limits battery hangs on the tile to its right.
    public var wallClock: TilePoint
    public var playerStart: OfficePoint
    public var poses: [Int32: OfficePose]

    public static func build(agents: [AgentSession], ports: [ListeningPort]) -> OfficeMap {
        OfficeMapBuilder(agents: agents, ports: ports).build()
    }

    public var desks: [OfficeDesk] { rooms.flatMap(\.cubicles).flatMap(\.desks) }
    public var racks: [OfficeRack] { closetRacks + rooms.flatMap(\.cubicles).flatMap(\.racks) }

    public func desk(of pid: Int32) -> OfficeDesk? {
        desks.first { $0.agentPID == pid }
    }

    /// Where the agent is drawn: at its desk, or standing in the aisle when it needs you.
    public func position(of pid: Int32) -> OfficePoint? {
        guard let desk = desk(of: pid) else { return nil }
        return poses[pid]?.isStanding == true ? desk.standSpot : desk.seat
    }

    public func room(containing point: OfficePoint) -> OfficeRoom? {
        rooms.first { $0.rect.contains(point.tile) }
    }

    public func object(at point: OfficePoint) -> OfficeObject? {
        if let pid = agent(at: point) { return .agent(pid) }
        let tile = point.tile
        if let rack = racks.first(where: { $0.tile == tile }) { return .rack(rack.port) }
        if cpuRack.contains(tile) { return .cpuRack }
        if tile == waterCooler { return .waterCooler }
        if tile == jukebox { return .jukebox }
        if tile == wallClock || tile == TilePoint(x: wallClock.x + 1, y: wallClock.y) { return .wallClock }
        return nil
    }

    private func agent(at point: OfficePoint) -> Int32? {
        desks.compactMap(\.agentPID).first { pid in
            guard let position = position(of: pid) else { return false }
            return abs(point.x - position.x) < 0.6 && point.y <= position.y + 0.1 && point.y >= position.y - 1.3
        }
    }
}

/// Places rooms along both sides of a hallway, with a server closet at its start.
private struct OfficeMapBuilder {
    static let roomHeight = 6
    static let hallwayTop = 6
    static let hallwayRows = 3
    static var lowerRoomTop: Int { hallwayTop + hallwayRows }
    static var mapHeight: Int { lowerRoomTop + roomHeight }
    static let slotWidth = 3

    struct Checkout {
        var id: String
        var label: String
        var pids: [Int32] = []
        var ports: [ListeningPort] = []

        var width: Int { max(OfficeMapBuilder.slotWidth * max(pids.count, 1), ports.count + 1, 4) }
    }

    let agents: [AgentSession]
    let ports: [ListeningPort]

    func build() -> OfficeMap {
        let orphans = ports.filter { $0.project == nil }.sorted { $0.port < $1.port }
        let closet = TileRect(x: 0, y: 0, width: max(8, orphans.count + 6), height: Self.roomHeight)
        let plans = roomPlans()
        var upperX = closet.maxX
        var lowerX = 0
        let rooms = plans.enumerated().map { index, plan in
            let isUpper = index.isMultiple(of: 2)
            let room = layOutRoom(plan, x: isUpper ? upperX : lowerX, isUpper: isUpper)
            if isUpper { upperX = room.rect.maxX } else { lowerX = room.rect.maxX }
            return room
        }
        let width = max(upperX, lowerX, closet.maxX + 12)
        return assemble(rooms: rooms, closet: closet, orphans: orphans, width: width)
    }

    /// Rooms by repository, each with its checkouts, alphabetical.
    private func roomPlans() -> [(name: String, checkouts: [Checkout])] {
        var rooms: [String: [String: Checkout]] = [:]
        for agent in agents {
            let name = agent.project?.name ?? URL(fileURLWithPath: agent.workingDirectory).lastPathComponent
            let id = agent.project?.rootPath ?? agent.workingDirectory
            rooms[name, default: [:]][id, default: Checkout(id: id, label: Self.label(agent.project, fallback: name))].pids.append(agent.pid)
        }
        for port in ports {
            guard let project = port.project else { continue }
            rooms[project.name, default: [:]][project.rootPath, default: Checkout(id: project.rootPath, label: Self.label(project, fallback: project.name))].ports.append(port)
        }
        return rooms.sorted { $0.key.lowercased() < $1.key.lowercased() }.map { name, checkouts in
            (name, checkouts.values.sorted { $0.id < $1.id }.map(Self.sortedContents))
        }
    }

    private static func sortedContents(_ checkout: Checkout) -> Checkout {
        var sorted = checkout
        sorted.pids.sort()
        sorted.ports.sort { $0.port < $1.port }
        return sorted
    }

    private static func label(_ project: DevProject?, fallback: String) -> String {
        guard let project else { return fallback }
        if project.isWorktree { return project.worktreeName ?? project.branch ?? "worktree" }
        return project.branch ?? project.name
    }

    /// Walkway, then cubicles divided by partitions, then walkway.
    private func layOutRoom(_ plan: (name: String, checkouts: [Checkout]), x: Int, isUpper: Bool) -> OfficeRoom {
        let top = isUpper ? 0 : Self.lowerRoomTop
        var column = x + 3
        let cubicles = plan.checkouts.map { checkout in
            let cubicle = layOutCubicle(checkout, x: column, top: top + 1)
            column += checkout.width + 1
            return cubicle
        }
        let rect = TileRect(x: x, y: top, width: column + 2 - x, height: Self.roomHeight)
        let wallRow = isUpper ? rect.maxY - 1 : rect.y
        return OfficeRoom(name: plan.name, rect: rect, door: TilePoint(x: x + 1, y: wallRow), plate: TilePoint(x: x + 3, y: wallRow),
                          isAboveHallway: isUpper, cubicles: cubicles)
    }

    private func layOutCubicle(_ checkout: Checkout, x: Int, top: Int) -> OfficeCubicle {
        let deskSlots = checkout.pids.isEmpty ? [nil] : checkout.pids.map(Optional.some)
        let desks = deskSlots.enumerated().map { index, pid in
            let slotX = x + index * Self.slotWidth
            return OfficeDesk(desk: TilePoint(x: slotX, y: top + 2), agentPID: pid,
                              seat: OfficePoint(x: Double(slotX) + 1, y: Double(top + 2) + 0.35),
                              standSpot: OfficePoint(x: Double(slotX) + 1, y: Double(top + 3) + 0.9),
                              approach: TilePoint(x: slotX + 2, y: top + 3))
        }
        let rackRight = x + checkout.width - 1
        let racks = checkout.ports.enumerated().map { OfficeRack(port: $1, tile: TilePoint(x: rackRight - $0, y: top)) }
        return OfficeCubicle(id: checkout.id, label: checkout.label, rect: TileRect(x: x, y: top, width: checkout.width, height: 3), desks: desks, racks: racks)
    }

    private func assemble(rooms: [OfficeRoom], closet: TileRect, orphans: [ListeningPort], width: Int) -> OfficeMap {
        let hallway = TileRect(x: 1, y: Self.hallwayTop, width: width - 2, height: Self.hallwayRows)
        let cpuRack = TileRect(x: closet.x + 1, y: closet.y + 1, width: 2, height: 2)
        let closetRacks = orphans.enumerated().map { OfficeRack(port: $1, tile: TilePoint(x: closet.x + 4 + $0, y: closet.y + 1)) }
        let map = OfficeMap(
            grid: OfficeGrid(width: width, height: Self.mapHeight), rooms: rooms, closet: closet, hallway: hallway, cpuRack: cpuRack,
            closetRacks: closetRacks, waterCooler: TilePoint(x: closet.maxX - 2, y: hallway.y), jukebox: TilePoint(x: closet.maxX - 1, y: hallway.y), wallClock: TilePoint(x: closet.maxX - 4, y: closet.maxY - 1),
            playerStart: TilePoint(x: closet.x + 3, y: hallway.y + 1).center, poses: Dictionary(agents.map { ($0.pid, OfficePose(state: $0.state)) }, uniquingKeysWith: { first, _ in first }))
        return carved(map)
    }

    /// Fills in the tiles: rooms, hallway, doors, then everything that blocks walking.
    private func carved(_ map: OfficeMap) -> OfficeMap {
        var grid = map.grid
        grid.room(map.closet, floor: .closetFloor)
        for room in map.rooms { carve(room, into: &grid) }
        let hallwayWalls = TileRect(x: 0, y: map.hallway.y - 1, width: grid.width, height: map.hallway.height + 2)
        for y in hallwayWalls.y..<hallwayWalls.maxY {
            for x in 0..<grid.width where grid[TilePoint(x: x, y: y)] == .void { grid[TilePoint(x: x, y: y)] = .wall }
        }
        grid.fill(map.hallway, with: .hallFloor)
        grid[TilePoint(x: map.closet.x + 3, y: map.closet.maxY - 1)] = .closetFloor
        grid.fill(map.cpuRack, with: .furniture)
        for tile in map.closetRacks.map(\.tile) + [map.waterCooler, map.jukebox] { grid[tile] = .furniture }
        var result = map
        result.grid = grid
        return result
    }

    private func carve(_ room: OfficeRoom, into grid: inout OfficeGrid) {
        grid.room(room.rect, floor: .roomFloor)
        grid[room.door] = .roomFloor
        for cubicle in room.cubicles {
            let partitionRows = cubicle.rect.y..<cubicle.rect.maxY
            for y in partitionRows {
                grid[TilePoint(x: cubicle.rect.x - 1, y: y)] = .partition
                grid[TilePoint(x: cubicle.rect.maxX, y: y)] = .partition
            }
            for desk in cubicle.desks {
                grid[desk.desk] = .furniture
                grid[TilePoint(x: desk.desk.x + 1, y: desk.desk.y)] = .furniture
            }
            for rack in cubicle.racks { grid[rack.tile] = .furniture }
        }
    }
}
