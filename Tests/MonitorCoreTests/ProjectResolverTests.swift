import Foundation
import Testing
@testable import MonitorCore

struct ProjectResolverTests {
    let home: String

    init() throws {
        home = NSTemporaryDirectory() + "resolver-\(UUID().uuidString)"
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: home + "/git/shop/.git/worktrees/shop-checkout", withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(toFile: home + "/git/shop/.git/HEAD", atomically: true, encoding: .utf8)
        try fileManager.createDirectory(atPath: home + "/git/shop/apps/web", withIntermediateDirectories: true)

        try fileManager.createDirectory(atPath: home + "/git/shop-worktrees/checkout", withIntermediateDirectories: true)
        try "gitdir: \(home)/git/shop/.git/worktrees/shop-checkout\n".write(toFile: home + "/git/shop-worktrees/checkout/.git", atomically: true, encoding: .utf8)
        try "ref: refs/heads/feature/checkout\n".write(toFile: home + "/git/shop/.git/worktrees/shop-checkout/HEAD", atomically: true, encoding: .utf8)

        try fileManager.createDirectory(atPath: home + "/scratch/tool", withIntermediateDirectories: true)
        try "{}".write(toFile: home + "/scratch/tool/package.json", atomically: true, encoding: .utf8)
    }

    @Test func nestedFolderResolvesToMainRepo() {
        let project = ProjectResolver(homeDirectory: home).project(containing: home + "/git/shop/apps/web")
        #expect(project?.name == "shop")
        #expect(project?.branch == "main")
        #expect(project?.isWorktree == false)
    }

    @Test func worktreeResolvesToMainRepoNameAndOwnBranch() {
        let project = ProjectResolver(homeDirectory: home).project(containing: home + "/git/shop-worktrees/checkout")
        #expect(project?.name == "shop")
        #expect(project?.isWorktree == true)
        #expect(project?.worktreeName == "checkout")
        #expect(project?.branch == "feature/checkout")
    }

    @Test func folderWithManifestButNoGitIsStillAProject() {
        let project = ProjectResolver(homeDirectory: home).project(containing: home + "/scratch/tool")
        #expect(project?.name == "tool")
        #expect(project?.branch == nil)
    }

    @Test func systemFoldersAreNotProjects() {
        #expect(ProjectResolver(homeDirectory: home).project(containing: "/") == nil)
        #expect(ProjectResolver(homeDirectory: home).project(containing: home) == nil)
    }
}
