import Foundation
import Testing
@testable import MonitorCore

struct BuildCacheScannerTests {
    @Test func sizesOnlyKnownCacheFolders() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: root) }
        for folder in ["node_modules/pkg", "src"] {
            try FileManager.default.createDirectory(atPath: root + "/" + folder, withIntermediateDirectories: true)
        }
        try Data(count: 64 * 1024).write(to: URL(fileURLWithPath: root + "/node_modules/pkg/index.js"))
        try Data(count: 64 * 1024).write(to: URL(fileURLWithPath: root + "/src/app.ts"))
        let usage = try #require(BuildCacheScanner.usage(in: root))
        #expect(usage.folders == ["node_modules"])
        #expect(usage.totalBytes >= 64 * 1024)
    }

    @Test func isNilWithoutCacheFolders() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/src", withIntermediateDirectories: true)
        #expect(BuildCacheScanner.usage(in: root) == nil)
    }

    @Test func readsDuOutput() {
        #expect(BuildCacheScanner.parseKilobytes("2048\t/tmp/x/node_modules\n") == 2048)
        #expect(BuildCacheScanner.parseKilobytes("") == nil)
    }
}
