import Foundation
@testable import MonitorCore
import Testing

struct NeedsYouQueueTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func agent(_ pid: Int32, _ state: AgentState = .needsApproval, lastActivity: Date? = nil) -> AgentSession {
        AgentSession(tool: .claude, pid: pid, workingDirectory: "/code/shop", project: nil, state: state, cpuPercent: 0, lastActivity: lastActivity)
    }

    private func queue(_ agents: [AgentSession], at now: Date) -> NeedsYouQueue {
        var queue = NeedsYouQueue()
        queue.update(agents: agents, now: now)
        return queue
    }

    @Test func freshRequestShowsAsAPost() {
        let agents = [agent(1, lastActivity: start)]
        let layout = queue(agents, at: start).layout(of: agents, now: start.addingTimeInterval(1))
        #expect(layout.posts.map(\.pid) == [1])
        #expect(layout.avatars.isEmpty)
    }

    @Test func postShrinksIntoAnAvatarAfterAWhile() {
        let agents = [agent(1, lastActivity: start)]
        let layout = queue(agents, at: start).layout(of: agents, now: start.addingTimeInterval(NeedsYouQueue.postSeconds + 1))
        #expect(layout.posts.isEmpty)
        #expect(layout.avatars.map(\.pid) == [1])
    }

    @Test func agentThatHasWaitedLongStartsAsAnAvatar() {
        let agents = [agent(1, lastActivity: start.addingTimeInterval(-600))]
        let layout = queue(agents, at: start).layout(of: agents, now: start)
        #expect(layout.avatars.map(\.pid) == [1])
    }

    @Test func shrinkingMovesThePostToTheAvatarRow() {
        let agents = [agent(1, lastActivity: start)]
        var queue = queue(agents, at: start)
        queue.shrink(1)
        let layout = queue.layout(of: agents, now: start)
        #expect(layout.posts.isEmpty)
        #expect(layout.avatars.map(\.pid) == [1])
    }

    @Test func avatarGoesAwayWhenTheAgentNoLongerNeedsYou() {
        var queue = queue([agent(1, lastActivity: start)], at: start)
        queue.shrink(1)
        let working = [agent(1, .working)]
        queue.update(agents: working, now: start.addingTimeInterval(5))
        #expect(queue.layout(of: working, now: start.addingTimeInterval(5)) == NeedsYouLayout(posts: [], avatars: []))
        #expect(queue.shrunk.isEmpty)
    }

    @Test func waitingAgainAfterWorkingShowsAFreshPost() {
        var queue = queue([agent(1, lastActivity: start)], at: start)
        queue.shrink(1)
        let later = start.addingTimeInterval(60)
        queue.update(agents: [agent(1, .working)], now: later)
        let waiting = [agent(1, lastActivity: later)]
        queue.update(agents: waiting, now: later)
        #expect(queue.layout(of: waiting, now: later).posts.map(\.pid) == [1])
    }

    @Test func postsAreNewestFirstAndOverflowBecomesAvatars() {
        let agents = (1...5).map { agent(Int32($0), lastActivity: start.addingTimeInterval(Double($0))) }
        let now = start.addingTimeInterval(6)
        let layout = queue(agents, at: now).layout(of: agents, now: now)
        #expect(layout.posts.map(\.pid) == [5, 4, 3])
        #expect(layout.avatars.map(\.pid) == [1, 2])
    }

    @Test func avatarsAreLongestWaitingFirst() {
        let agents = [agent(3, lastActivity: start.addingTimeInterval(-100)), agent(1, lastActivity: start.addingTimeInterval(-300)),
                      agent(2, .possiblyStuck, lastActivity: start.addingTimeInterval(-200)), agent(4, .working)]
        let layout = queue(agents, at: start).layout(of: agents, now: start)
        #expect(layout.avatars.map(\.pid) == [1, 2, 3])
    }

    @Test func shrinkIgnoresAgentsThatAreNotWaiting() {
        var queue = queue([agent(1, .working)], at: start)
        queue.shrink(1)
        #expect(queue.shrunk.isEmpty)
    }
}
