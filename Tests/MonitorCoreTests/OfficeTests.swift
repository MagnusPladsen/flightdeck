import Foundation
@testable import MonitorCore
import Testing

struct OfficeTests {
    private func project(_ name: String, worktree: String? = nil, branch: String = "main") -> DevProject {
        let root = "/code/\(name)"
        return DevProject(name: name, rootPath: worktree.map { "\(root)/.claude/worktrees/\($0)" } ?? root, branch: branch, isWorktree: worktree != nil, worktreeName: worktree)
    }

    private func agent(_ pid: Int32, _ project: DevProject?, _ state: AgentState = .working, folder: String = "/tmp/loose") -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: project?.rootPath ?? folder, project: project, state: state, cpuPercent: 0, lastActivity: Date())
    }

    private func port(_ number: Int, _ project: DevProject?) -> ListeningPort {
        ListeningPort(port: number, pid: Int32(number), processName: "node", isLocalOnly: true, project: project)
    }

    @Test func worktreesShareTheRepoRoomInSeparateCubicles() {
        let map = OfficeMap.build(agents: [agent(1, project("shop")), agent(2, project("shop", worktree: "search")), agent(3, project("blog"))], ports: [])
        #expect(map.rooms.map(\.name) == ["blog", "shop"])
        let shop = map.rooms[1]
        #expect(shop.cubicles.map(\.label) == ["main", "search"])
    }

    @Test func agentsInOneCheckoutShareACubicle() {
        let map = OfficeMap.build(agents: [agent(2, project("shop")), agent(1, project("shop"))], ports: [])
        #expect(map.rooms.count == 1)
        #expect(map.rooms[0].cubicles.count == 1)
        #expect(map.rooms[0].cubicles[0].desks.map(\.agentPID) == [1, 2])
    }

    @Test func devServersGoInTheirCheckoutsCubicle() {
        let search = project("shop", worktree: "search")
        let map = OfficeMap.build(agents: [agent(1, search)], ports: [port(3001, search), port(5432, nil)])
        #expect(map.rooms[0].cubicles[0].racks.map(\.port.port) == [3001])
        #expect(map.closetRacks.map(\.port.port) == [5432])
    }

    @Test func serverOnlyProjectGetsRoomWithEmptyDesk() {
        let map = OfficeMap.build(agents: [], ports: [port(5173, project("docs"))])
        #expect(map.rooms.map(\.name) == ["docs"])
        #expect(map.rooms[0].cubicles[0].desks.map(\.agentPID) == [nil])
    }

    @Test func agentWithoutProjectGetsFolderRoom() {
        let map = OfficeMap.build(agents: [agent(7, nil, folder: "/Users/alex/scratch")], ports: [])
        #expect(map.rooms.map(\.name) == ["scratch"])
        #expect(map.desk(of: 7) != nil)
    }

    @Test func roomsAlternateAboveAndBelowTheHallway() {
        let map = OfficeMap.build(agents: ["c", "a", "b"].enumerated().map { agent(Int32($0), project($1)) }, ports: [])
        #expect(map.rooms.map(\.name) == ["a", "b", "c"])
        #expect(map.rooms.map(\.isAboveHallway) == [true, false, true])
    }

    @Test func layoutIgnoresAgentStates() {
        let working = OfficeMap.build(agents: [agent(1, project("shop"), .working)], ports: [])
        let waiting = OfficeMap.build(agents: [agent(1, project("shop"), .needsApproval)], ports: [])
        #expect(working.rooms == waiting.rooms)
        #expect(working.grid == waiting.grid)
        #expect(working.position(of: 1) != waiting.position(of: 1))
    }

    @Test func everyDeskIsReachable() {
        let agents = [agent(1, project("shop")), agent(2, project("shop", worktree: "a")), agent(3, project("api")), agent(4, project("blog")), agent(5, nil)]
        let map = OfficeMap.build(agents: agents, ports: [port(3000, project("shop")), port(6379, nil)])
        for desk in map.desks {
            #expect(OfficePathfinder.path(in: map.grid, from: map.playerStart.tile, to: desk.approach) != nil)
        }
    }

    @Test func emptyOfficeHasWalkableHallway() {
        let map = OfficeMap.build(agents: [], ports: [])
        #expect(map.rooms.isEmpty)
        #expect(map.grid.isWalkable(map.playerStart.tile))
        let farEnd = TilePoint(x: map.hallway.maxX - 1, y: map.hallway.y + 1)
        #expect(OfficePathfinder.path(in: map.grid, from: map.playerStart.tile, to: farEnd) != nil)
    }

    @Test func pathfinderFindsShortestRouteAndRejectsWalls() {
        let map = OfficeMap.build(agents: [], ports: [])
        let start = map.playerStart.tile
        let path = OfficePathfinder.path(in: map.grid, from: start, to: TilePoint(x: start.x + 4, y: start.y))
        #expect(path?.count == 4)
        #expect(OfficePathfinder.path(in: map.grid, from: start, to: TilePoint(x: 0, y: 0)) == nil)
    }

    @Test func motionSlidesAlongWalls() {
        let map = OfficeMap.build(agents: [], ports: [])
        let start = TilePoint(x: 8, y: map.hallway.y).center
        let moved = OfficeMotion.move(start, by: OfficePoint(x: 0.5, y: -0.5), in: map.grid)
        #expect(moved.x == start.x + 0.5)
        #expect(moved.y == start.y)
    }

    @Test func posesFollowAgentState() {
        #expect(OfficePose(state: .working) == .typing)
        #expect(OfficePose(state: .idle) == .phone)
        #expect(OfficePose(state: .needsApproval).isStanding)
        #expect(OfficePose(state: .possiblyStuck).isStanding)
        #expect(!OfficePose(state: .yourTurn).isStanding)
    }

    @Test func feedHasApprovalsAndStuckAgentsOnly() {
        let agents = [agent(1, nil, .needsApproval), agent(2, nil, .possiblyStuck), agent(3, nil, .yourTurn), agent(4, nil, .working)]
        #expect(Set(NeedsYouFeed.agents(in: agents).map(\.pid)) == [1, 2])
    }

    @Test func idleThoughtsRotateAndDifferPerAgent() {
        let date = Date(timeIntervalSinceReferenceDate: 800)
        #expect(IdleThoughts.line(for: 1, at: date) == IdleThoughts.line(for: 1, at: date.addingTimeInterval(1)))
        #expect(IdleThoughts.line(for: 1, at: date) != IdleThoughts.line(for: 1, at: date.addingTimeInterval(IdleThoughts.secondsPerLine)))
        #expect(IdleThoughts.line(for: 1, at: date) != IdleThoughts.line(for: 2, at: date))
    }

    @Test func cameraCentresSmallMapsAndFollowsOnBigOnes() {
        let small = OfficeCamera(mapWidth: 10, mapHeight: 10, viewWidth: 1000, viewHeight: 1000, focus: OfficePoint(x: 1, y: 1))
        #expect(small.scale == 3)
        #expect(small.originX == 260)
        let big = OfficeCamera(mapWidth: 100, mapHeight: 15, viewWidth: 800, viewHeight: 600, focus: OfficePoint(x: 50, y: 7))
        #expect(big.scale == 2)
        #expect(big.originX == 400 - 50 * 32)
        let atStart = OfficeCamera(mapWidth: 100, mapHeight: 15, viewWidth: 800, viewHeight: 600, focus: OfficePoint(x: 1, y: 7))
        #expect(atStart.originX == 0)
    }

    @Test func objectsAreFoundUnderThePointer() {
        let shop = project("shop")
        let map = OfficeMap.build(agents: [agent(1, shop)], ports: [port(3000, shop)])
        let rack = map.rooms[0].cubicles[0].racks[0]
        #expect(map.object(at: rack.tile.center) == .rack(rack.port))
        let seat = map.position(of: 1)!
        #expect(map.object(at: OfficePoint(x: seat.x, y: seat.y - 0.5)) == .agent(1))
        #expect(map.object(at: map.waterCooler.center) == .waterCooler)
        #expect(map.object(at: map.jukebox.center) == .jukebox)
        #expect(map.object(at: TilePoint(x: map.cpuRack.x, y: map.cpuRack.y).center) == .cpuRack)
    }

    @Test func jukeboxSitsInTheHallwayWithoutBlockingDoors() {
        let map = OfficeMap.build(agents: ["a", "b", "c"].enumerated().map { agent(Int32($0), project($1)) }, ports: [])
        #expect(map.hallway.contains(map.jukebox))
        #expect(map.grid[map.jukebox] == .furniture)
        for room in map.rooms {
            #expect(OfficePathfinder.path(in: map.grid, from: map.playerStart.tile, to: room.door) != nil)
        }
    }
}
