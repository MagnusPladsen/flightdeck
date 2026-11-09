import Foundation
@testable import MonitorCore
import Testing

struct StatusFormatterTests {
    private func report(working: Int, needsYou: Int, servers: Int = 0) -> StatusReport {
        StatusReport(appVersion: nil, updatedAt: Date(), counts: StatusCounts(working: working, needsYou: needsYou, idle: 3, servers: servers),
                     agents: [], servers: [], system: StatusSystem(cpuPercent: 12, memoryPercent: 58), limits: [])
    }

    @Test func summaryLeavesOutZeroCounts() {
        #expect(StatusFormatter.summary(report(working: 2, needsYou: 1)) == "2 working · 1 needs you")
        #expect(StatusFormatter.summary(report(working: 0, needsYou: 1, servers: 1)) == "1 needs you · 1 server")
        #expect(StatusFormatter.summary(report(working: 0, needsYou: 0, servers: 3)) == "3 servers")
        #expect(StatusFormatter.summary(report(working: 0, needsYou: 0)) == "No active agents")
    }

    @Test func formatFillsPlaceholders() {
        let status = report(working: 2, needsYou: 1)
        #expect(StatusFormatter.format("{needsYou}/{working}", report: status) == "1/2")
        #expect(StatusFormatter.format("CPU {cpu}% MEM {memory}% idle {idle}", report: status) == "CPU 12% MEM 58% idle 3")
        #expect(StatusFormatter.format("{summary}", report: status) == "2 working · 1 needs you")
    }

    @Test func formatKeepsUnknownPlaceholders() {
        #expect(StatusFormatter.format("{nope} {working}", report: report(working: 4, needsYou: 0)) == "{nope} 4")
    }

    @Test func everyPlaceholderNameIsFilled() {
        let names = Set(StatusFormatter.placeholders(for: report(working: 1, needsYou: 1)).keys)
        #expect(names == Set(StatusFormatter.placeholderNames))
    }

    @Test func parsesCommandLine() throws {
        #expect(try StatusCommandLine.parse([]) == .help)
        #expect(try StatusCommandLine.parse(["status"]) == .status(.summary))
        #expect(try StatusCommandLine.parse(["status", "--json"]) == .status(.json))
        #expect(try StatusCommandLine.parse(["status", "--format", "{working}"]) == .status(.format("{working}")))
        #expect(try StatusCommandLine.parse(["status", "--format={needsYou}"]) == .status(.format("{needsYou}")))
        #expect(throws: StatusCommandLineError.unknownCommand("stats")) { try StatusCommandLine.parse(["stats"]) }
        #expect(throws: StatusCommandLineError.badOptions("--json --format")) { try StatusCommandLine.parse(["status", "--json", "--format"]) }
    }
}
