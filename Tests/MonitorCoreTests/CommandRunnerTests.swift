import Testing
@testable import MonitorCore

struct CommandRunnerTests {
    @Test func gitRunsWithoutOptionalLocks() {
        #expect(CommandRunner.environment(for: "/usr/bin/git", inheriting: [:])["GIT_OPTIONAL_LOCKS"] == "0")
        #expect(CommandRunner.environment(for: "/usr/sbin/lsof", inheriting: [:])["GIT_OPTIONAL_LOCKS"] == nil)
    }

    @Test func searchPathGoesBeforeTheInheritedPath() {
        #expect(CommandRunner.environment(for: "/bin/sh", inheriting: ["PATH": "/custom"])["PATH"] == CommandRunner.searchPath + ":/custom")
    }
}
