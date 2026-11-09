import Foundation
import MonitorCore
import Testing

struct PortConflictTests {
    private func server(_ port: Int, pid: Int32, project name: String, worktree: String? = nil, framework: String = "nextjs", command: String = "node next dev") -> ListeningPort {
        let root = "/code/\(name)" + (worktree.map { "/.claude/worktrees/\($0)" } ?? "")
        let project = DevProject(name: name, rootPath: root, branch: "main", isWorktree: worktree != nil, worktreeName: worktree)
        return ListeningPort(port: port, pid: pid, processName: "node", isLocalOnly: true, commandLine: command, workingDirectory: root, project: project,
                             framework: Framework(id: framework, displayName: framework))
    }

    @Test func projectBumpedOffItsDefaultPortByAnotherProjectIsDisplaced() {
        let shop = server(3000, pid: 1, project: "shop")
        let admin = server(3001, pid: 2, project: "admin")
        let conflicts = PortConflicts.detect(in: [shop, admin])
        #expect(conflicts[admin.id] == .displaced(wantedPort: 3000, holderTitle: "shop"))
        #expect(conflicts[shop.id] == nil)
    }

    @Test func worktreesOfOneProjectBumpingEachOtherAreExpected() {
        let main = server(3000, pid: 1, project: "shop")
        let worktree = server(3001, pid: 2, project: "shop", worktree: "search")
        #expect(PortConflicts.detect(in: [main, worktree]).isEmpty)
    }

    @Test func portGivenOnTheCommandLineIsNotADisplacement() {
        let shop = server(3000, pid: 1, project: "shop")
        for command in ["next dev -p 3001", "next dev --port=3001", "vite --port 3001", "uvicorn app:app --host 127.0.0.1:3001"] {
            let admin = server(3001, pid: 2, project: "admin", command: command)
            #expect(PortConflicts.detect(in: [shop, admin]).isEmpty, "\(command)")
        }
    }

    @Test func portFarFromTheDefaultOrUnknownFrameworkIsNotFlagged() {
        let shop = server(3000, pid: 1, project: "shop")
        #expect(PortConflicts.detect(in: [shop, server(3020, pid: 2, project: "admin")]).isEmpty)
        #expect(PortConflicts.detect(in: [shop, server(3001, pid: 2, project: "admin", framework: "node")]).isEmpty)
    }

    @Test func twoProjectsOnTheSamePortNumberAreFlaggedBothWays() {
        let shop = server(5173, pid: 1, project: "shop", framework: "vite")
        let docs = server(5173, pid: 2, project: "docs", framework: "vite")
        let conflicts = PortConflicts.detect(in: [shop, docs])
        #expect(conflicts[shop.id] == .sharedPort(otherTitle: "docs"))
        #expect(conflicts[docs.id] == .sharedPort(otherTitle: "shop"))
    }

    @Test func workersOfOneServerSharingItsSocketAreNotAConflict() {
        let parent = server(8000, pid: 1, project: "api", framework: "fastapi")
        let worker = server(8000, pid: 2, project: "api", framework: "fastapi")
        #expect(PortConflicts.detect(in: [parent, worker]).isEmpty)
    }

    @Test func summariesNameTheOtherProject() {
        #expect(PortConflict.displaced(wantedPort: 3000, holderTitle: "shop").summary == "Wanted :3000, taken by shop")
        #expect(PortConflict.sharedPort(otherTitle: "docs").summary == "docs also listens on this port")
    }
}
