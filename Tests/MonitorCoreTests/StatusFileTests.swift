import Foundation
@testable import MonitorCore
import Testing

struct StatusFileTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("flightdeck-status-\(UUID().uuidString)")
    private var url: URL { folder.appendingPathComponent("Flightdeck/status.json") }
    private let report = StatusReport(appVersion: "1.5.0", updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                      counts: StatusCounts(working: 1, needsYou: 0, idle: 0, servers: 0), agents: [], servers: [], system: nil, limits: [])

    @Test func readsWhatWasWritten() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try StatusFile.write(report, to: url)
        #expect(try StatusFile.read(from: url) == report)
    }

    @Test func missingFileIsReported() {
        #expect(throws: StatusFileError.missing(url.path)) { try StatusFile.read(from: url) }
    }

    @Test func oldFileIsStaleUntilTouched() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Date()
        try StatusFile.write(report, to: url)
        try StatusFile.touch(url, at: now.addingTimeInterval(-45))
        #expect(throws: StatusFileError.stale(seconds: 45)) { try StatusFile.read(from: url, now: now) }
        try StatusFile.touch(url, at: now)
        #expect(try StatusFile.read(from: url, now: now) == report)
    }

    @Test func garbageIsUnreadable() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(throws: StatusFileError.unreadable(url.path)) { try StatusFile.read(from: url) }
    }
}
