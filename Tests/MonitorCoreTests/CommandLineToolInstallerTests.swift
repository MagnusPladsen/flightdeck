import Foundation
@testable import MonitorCore
import Testing

struct CommandLineToolInstallerTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("flightdeck-install-\(UUID().uuidString)").path
    private var helper: String { root + "/Flightdeck.app/Contents/Helpers/flightdeck" }
    private var userBin: String { root + "/home/.local/bin" }
    private var systemBin: String { root + "/usr/local/bin" }

    private func makeFolders(_ folders: String...) throws {
        for folder in folders { try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true) }
        try FileManager.default.createDirectory(atPath: (helper as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: helper, contents: Data("#!/bin/sh\n".utf8))
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(atPath: root)
    }

    @Test func prefersAWritableFolderOnPath() throws {
        defer { cleanUp() }
        try makeFolders(userBin, systemBin)
        let installer = CommandLineToolInstaller(candidateFolders: [userBin, systemBin], pathEntries: ["/usr/bin", systemBin])
        let installation = try installer.install(helper: helper)
        #expect(installation == CommandLineToolInstallation(linkPath: systemBin + "/flightdeck", isOnPath: true))
        #expect(installation.pathInstruction == nil)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: installation.linkPath) == helper)
    }

    @Test func createsTheUserFolderAndExplainsPath() throws {
        defer { cleanUp() }
        try makeFolders(root + "/home")
        let installer = CommandLineToolInstaller(candidateFolders: [userBin, systemBin], pathEntries: ["/usr/bin"])
        let installation = try installer.install(helper: helper)
        #expect(installation.linkPath == userBin + "/flightdeck")
        #expect(installation.pathInstruction == "export PATH=\"\(userBin):$PATH\"")
    }

    @Test func replacesAnOldLinkButNotAFile() throws {
        defer { cleanUp() }
        try makeFolders(userBin)
        let installer = CommandLineToolInstaller(candidateFolders: [userBin], pathEntries: [userBin + "/"])
        try FileManager.default.createSymbolicLink(atPath: userBin + "/flightdeck", withDestinationPath: "/old/flightdeck")
        #expect(try installer.install(helper: helper).isOnPath)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: userBin + "/flightdeck") == helper)
        try FileManager.default.removeItem(atPath: userBin + "/flightdeck")
        FileManager.default.createFile(atPath: userBin + "/flightdeck", contents: Data())
        #expect(throws: CommandLineToolInstallError.occupied(userBin + "/flightdeck")) { try installer.install(helper: helper) }
    }

    @Test func failsWithoutAWritableFolder() throws {
        defer { cleanUp() }
        try makeFolders(root)
        FileManager.default.createFile(atPath: root + "/not-a-folder", contents: Data())
        let blocked = root + "/not-a-folder/bin"
        let installer = CommandLineToolInstaller(candidateFolders: [blocked], pathEntries: [])
        #expect(installer.chooseFolder() == nil)
        #expect(throws: CommandLineToolInstallError.noWritableFolder([blocked])) { try installer.install(helper: helper) }
    }
}
