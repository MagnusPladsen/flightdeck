import Testing
@testable import MonitorCore

struct NetworkBreakdownTests {
    @Test func parsesNettopLines() {
        let output = ",bytes_in,bytes_out,\nlaunchd.1,0,0,\nProton Mail Hel.1505,2048,512,\ngarbage\n"
        #expect(NetworkBreakdown.parseNettop(output) == [
            NetworkCounter(pid: 1, name: "launchd", bytesIn: 0, bytesOut: 0),
            NetworkCounter(pid: 1505, name: "Proton Mail Hel", bytesIn: 2048, bytesOut: 512),
        ])
    }

    @Test func ratesAreGroupedByAppAndSkipNewProcesses() {
        let previous = [NetworkCounter(pid: 1, name: "Google Chrome", bytesIn: 100, bytesOut: 0),
                        NetworkCounter(pid: 2, name: "Google Chrome H", bytesIn: 0, bytesOut: 0),
                        NetworkCounter(pid: 3, name: "node", bytesIn: 0, bytesOut: 0)]
        let current = [NetworkCounter(pid: 1, name: "Google Chrome", bytesIn: 300, bytesOut: 20),
                       NetworkCounter(pid: 2, name: "Google Chrome H", bytesIn: 200, bytesOut: 0),
                       NetworkCounter(pid: 3, name: "node", bytesIn: 0, bytesOut: 50),
                       NetworkCounter(pid: 4, name: "curl", bytesIn: 9000, bytesOut: 0)]
        let consumers = NetworkBreakdown.consumers(previous: previous, current: current, seconds: 2,
                                                   names: [2: "Google Chrome Helper (Renderer)"], limit: 5)
        #expect(consumers.map(\.name) == ["Google Chrome", "node"])
        #expect(consumers[0].bytesInPerSecond == 200)
        #expect(consumers[0].bytesOutPerSecond == 10)
        #expect(consumers[0].processCount == 2)
        #expect(consumers[1].bytesOutPerSecond == 25)
    }
}
