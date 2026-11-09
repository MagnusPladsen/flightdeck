import Foundation
import Testing
@testable import MonitorCore

struct GitChangeParserTests {
    @Test func numstatParsesCountsBinaryFilesAndQuotedPaths() {
        let output = "12\t3\tSources/App.swift\n-\t-\tAssets/logo.png\n1\t0\t\"docs/a \\\"b\\\".md\"\n"
        #expect(GitChangeParser.numstat(output) == [
            FileChange(path: "Sources/App.swift", added: 12, removed: 3),
            FileChange(path: "Assets/logo.png", added: nil, removed: nil),
            FileChange(path: "docs/a \"b\".md", added: 1, removed: 0),
        ])
    }

    @Test func summaryAddsUpLinesAndSkipsBinaryCounts() {
        let files = [FileChange(path: "a", added: 100, removed: 18), FileChange(path: "b", added: nil, removed: nil), FileChange(path: "c", added: 20, removed: 0, isUntracked: true)]
        #expect(ChangeSummary(files: files).text == "3 files · +120 −18")
        #expect(ChangeSummary(files: [files[0]]).text == "1 file · +100 −18")
        #expect(ChangeSummary(files: []).isEmpty)
    }

    @Test func lineCountHandlesMissingTrailingNewlineAndBinary() {
        #expect(GitChangeParser.lineCount(of: Data("a\nb\n".utf8)) == 2)
        #expect(GitChangeParser.lineCount(of: Data("a\nb".utf8)) == 2)
        #expect(GitChangeParser.lineCount(of: Data()) == 0)
        #expect(GitChangeParser.lineCount(of: Data([0x89, 0x50, 0x00, 0x0A])) == nil)
    }

    @Test func diffLinesTagHeadersHunksAndChanges() {
        let diff = """
        diff --git a/x.swift b/x.swift
        index 1111111..2222222 100644
        --- a/x.swift
        +++ b/x.swift
        @@ -1,2 +1,2 @@
         let a = 1
        -let b = 2
        +let b = 3
        --- not a header
        """
        #expect(GitChangeParser.diffLines(diff).map(\.kind) == [.fileHeader, .fileHeader, .fileHeader, .fileHeader, .hunk, .context, .removed, .added, .removed])
    }

    @Test func untrackedDiffShowsEveryLineAsAdded() {
        let diff = GitChangeParser.untrackedDiff(path: "new.txt", contents: "one\ntwo\n")
        #expect(diff.hasSuffix("@@ -0,0 +1,2 @@\n+one\n+two"))
        #expect(GitChangeParser.diffLines(diff).filter { $0.kind == .added }.count == 2)
    }
}

struct AgentChangeCollectorTests {
    @Test func countsCommittedUncommittedAndUntrackedChangesSinceTheAgentStarted() throws {
        let git = try #require(CommandRunner.locate("git"))
        let repository = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: repository + "/sub", withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: repository) }
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        try "one\ntwo\n".write(toFile: repository + "/a.txt", atomically: true, encoding: .utf8)
        try runGit(git, in: repository, ["init", "-q"])
        try commitAll(git, in: repository, at: start.addingTimeInterval(-3600))
        try "one\nTWO\nthree\n".write(toFile: repository + "/a.txt", atomically: true, encoding: .utf8)
        try commitAll(git, in: repository, at: start.addingTimeInterval(600))
        try "x\n".write(toFile: repository + "/b.txt", atomically: true, encoding: .utf8)
        try runGit(git, in: repository, ["add", "b.txt"])
        try "new\nfile\n".write(toFile: repository + "/sub/c.txt", atomically: true, encoding: .utf8)

        let collector = AgentChangeCollector(git: git)
        let baseline = try #require(collector.baseline(forFolder: repository + "/sub", startedAt: start))
        let changes = try #require(collector.changes(since: baseline))
        #expect(changes.summary == ChangeSummary(fileCount: 3, added: 5, removed: 1))
        #expect(changes.files.first { $0.path == "sub/c.txt" }?.isUntracked == true)
        #expect(collector.diff(since: baseline).contains("+++ b/sub/c.txt"))
    }

    @Test func nonGitFolderHasNoBaseline() {
        #expect(AgentChangeCollector().baseline(forFolder: FileManager.default.temporaryDirectory.path, startedAt: Date()) == nil)
    }

    private func commitAll(_ git: String, in folder: String, at date: Date) throws {
        try runGit(git, in: folder, ["add", "-A"])
        try runGit(git, in: folder, ["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-q", "-m", "change"], date: date)
    }

    private func runGit(_ git: String, in folder: String, _ arguments: [String], date: Date? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: git)
        process.arguments = ["-C", folder] + arguments
        var environment = ProcessInfo.processInfo.environment
        if let date { environment["GIT_COMMITTER_DATE"] = "@\(Int(date.timeIntervalSince1970)) +0000" }
        process.environment = environment
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
