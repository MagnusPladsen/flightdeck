import Foundation
import MonitorCore
import Testing

struct ServerHealthTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let systemPort = ListeningPort(port: 5000, pid: 1, processName: "ControlCenter", isLocalOnly: false)

    private func server(_ port: Int, pid: Int32, folder: String = "/code/shop") -> ListeningPort {
        let project = DevProject(name: URL(fileURLWithPath: folder).lastPathComponent, rootPath: folder, branch: "main", isWorktree: false, worktreeName: nil)
        return ListeningPort(port: port, pid: pid, processName: "node", isLocalOnly: true, commandLine: "node next dev", workingDirectory: folder, project: project,
                             framework: Framework(id: "nextjs", displayName: "Next.js"))
    }

    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    @Test func vanishedServerCountsAsCrashedAfterTheGracePeriod() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10)], at: at(0))
        #expect(tracker.update([systemPort], at: at(5)).isEmpty)
        #expect(tracker.update([systemPort], at: at(10)).isEmpty)
        let crashed = tracker.update([systemPort], at: at(20))
        #expect(crashed.map(\.id) == [ServerIdentity(folder: "/code/shop", port: 3000)])
        #expect(crashed.first?.stoppedAt == at(5))
        #expect(tracker.crashed.count == 1)
        #expect(tracker.update([systemPort], at: at(25)).isEmpty)
    }

    @Test func serverBackOnTheSamePortWithinTheGraceIsARestart() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10)], at: at(0))
        _ = tracker.update([systemPort], at: at(5))
        _ = tracker.update([systemPort, server(3000, pid: 11)], at: at(10))
        #expect(tracker.update([systemPort, server(3000, pid: 11)], at: at(30)).isEmpty)
        #expect(tracker.crashed.isEmpty)
    }

    @Test func serverBackOnAnotherPortIsStillACrashOfTheFirst() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10)], at: at(0))
        _ = tracker.update([systemPort, server(3001, pid: 11)], at: at(5))
        #expect(tracker.update([systemPort, server(3001, pid: 11)], at: at(20)).map(\.id.port) == [3000])
    }

    @Test func serverStoppedFromFlightdeckIsNotACrash() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10)], at: at(0))
        tracker.noteStoppedByUser(pid: 10, at: at(1))
        _ = tracker.update([systemPort], at: at(5))
        #expect(tracker.update([systemPort], at: at(30)).isEmpty)
        #expect(tracker.crashed.isEmpty)
    }

    @Test func crashedServerClearsWhenItComesBackOrExpires() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10), server(5173, pid: 12, folder: "/code/docs")], at: at(0))
        _ = tracker.update([systemPort], at: at(5))
        _ = tracker.update([systemPort], at: at(20))
        #expect(tracker.crashed.count == 2)
        _ = tracker.update([systemPort, server(3000, pid: 13)], at: at(60))
        #expect(tracker.crashed.map(\.id.port) == [5173])
        _ = tracker.update([systemPort, server(3000, pid: 13)], at: at(5 + ServerHealthTracker.crashLifetime))
        #expect(tracker.crashed.isEmpty)
    }

    @Test func emptyScanIsIgnored() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10)], at: at(0))
        _ = tracker.update([], at: at(5))
        _ = tracker.update([], at: at(30))
        #expect(tracker.update([systemPort, server(3000, pid: 10)], at: at(35)).isEmpty)
        #expect(tracker.crashed.isEmpty)
    }

    @Test func dismissRemovesTheCrashedServer() {
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, server(3000, pid: 10)], at: at(0))
        _ = tracker.update([systemPort], at: at(5))
        _ = tracker.update([systemPort], at: at(20))
        tracker.dismiss(ServerIdentity(folder: "/code/shop", port: 3000))
        #expect(tracker.crashed.isEmpty)
    }

    @Test func containersAndSystemPortsAreNotTracked() {
        var container = ListeningPort(port: 5432, pid: 20, processName: "com.docker.backend", isLocalOnly: false, containerName: "db")
        container.framework = Framework(id: "docker", displayName: "Docker")
        var tracker = ServerHealthTracker()
        _ = tracker.update([systemPort, container], at: at(0))
        _ = tracker.update([ListeningPort(port: 7000, pid: 2, processName: "rapportd", isLocalOnly: false)], at: at(5))
        #expect(tracker.update([ListeningPort(port: 7000, pid: 2, processName: "rapportd", isLocalOnly: false)], at: at(30)).isEmpty)
    }

    @Test func quietAlertsAreHeldAndReleasedWhileStillDown() {
        let shop = CrashedServer(id: ServerIdentity(folder: "/code/shop", port: 3000), server: server(3000, pid: 10), stoppedAt: start)
        let docs = CrashedServer(id: ServerIdentity(folder: "/code/docs", port: 5173), server: server(5173, pid: 11, folder: "/code/docs"), stoppedAt: start)
        var queue = ServerAlertQueue()
        #expect(queue.deliver([shop, docs], stillCrashed: [shop, docs], isQuiet: true, handling: .summarize).isEmpty)
        #expect(queue.deliver([], stillCrashed: [docs], isQuiet: false, handling: .summarize) == [docs])
        #expect(queue.held.isEmpty)
        #expect(queue.deliver([shop], stillCrashed: [shop], isQuiet: true, handling: .drop).isEmpty)
        #expect(queue.deliver([], stillCrashed: [shop], isQuiet: false, handling: .drop).isEmpty)
        #expect(queue.deliver([shop], stillCrashed: [shop], isQuiet: false, handling: .drop) == [shop])
    }
}
