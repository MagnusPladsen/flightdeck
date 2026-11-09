import Foundation
import Testing
@testable import MonitorCore

struct ShellQuotingTests {
    @Test func quotesSoTheShellReadsTextBackUnchanged() throws {
        let samples = ["fix the login test", "it's $HOME `whoami` $(rm -rf ~)", #"back\slash and \\ two"#, "semi; colon && pipe | star *", "émoji 🚀 \"double\""]
        for sample in samples {
            let echoed = CommandRunner.run("/bin/sh", ["-c", "printf %s \(ShellQuoting.quote(sample))"])
            #expect(echoed.output == sample)
        }
    }

    @Test func quoteStepsOutForQuotesAndBackslashes() {
        #expect(ShellQuoting.quote("a'b") == #"'a'\''b'"#)
        #expect(ShellQuoting.quote(#"a\b"#) == #"'a'\\'b'"#)
    }

    @Test func appleScriptLiteralEscapesQuotesAndBackslashes() {
        #expect(ShellQuoting.appleScriptLiteral(#"say "hi" \ bye"#) == #""say \"hi\" \\ bye""#)
    }

    @Test func singleLineReplacesControlCharacters() {
        #expect(ShellQuoting.singleLine("one\ntwo\r\nthree\tfour") == "one two three four")
    }
}

struct AgentLaunchCommandTests {
    @Test func buildsCommandWithQuotedPrompt() {
        #expect(AgentLaunchCommand.command(for: .claude, prompt: nil) == "claude")
        #expect(AgentLaunchCommand.command(for: .codex, prompt: "  ") == "codex")
        #expect(AgentLaunchCommand.command(for: .claude, prompt: "fix it's\nbroken") == #"claude 'fix it'\''s broken'"#)
        #expect(AgentLaunchCommand.command(for: .claude, prompt: "-p rm") == "claude -- '-p rm'")
        #expect(AgentLaunchCommand.command(for: .gemini, prompt: "hi") == nil)
    }

    @Test func changesIntoQuotedFolderFirst() {
        #expect(AgentLaunchCommand.inFolder("/Users/a/my repo", run: "claude") == "cd '/Users/a/my repo' && claude")
    }
}

struct BranchNameValidatorTests {
    @Test func acceptsOrdinaryBranchNames() {
        for name in ["feat/search", "fix-123", "claude/brave-turing", "release/2.4", "FRAK-11"] {
            #expect(BranchNameValidator.problem(with: name) == nil, "\(name)")
        }
    }

    @Test func rejectsWhatGitRejects() {
        for name in ["", "has space", "a..b", "-flag", "/lead", "trail/", "end.", "x.lock", "a//b", "a@{b", "@", ".hidden", "feat/.x", "q?", "star*", "co:lon", "til~de", "back\\slash", "tab\tx"] {
            #expect(BranchNameValidator.problem(with: name) != nil, "\(name)")
        }
    }

    @Test func folderNameFlattensSlashes() {
        #expect(BranchNameValidator.folderName(for: "feat/search/v2") == "feat-search-v2")
    }
}

struct WorktreeLocationTests {
    let root = "/Users/a/git/shop"

    @Test func fixedLocations() {
        #expect(WorktreeLocation.siblingFolder.path(for: "x", repositoryRoot: root, existingWorktrees: []) == "/Users/a/git/shop-worktrees/x")
        #expect(WorktreeLocation.insideRepository.path(for: "x", repositoryRoot: root, existingWorktrees: []) == "/Users/a/git/shop/.claude/worktrees/x")
    }

    @Test func automaticFollowsTheMostUsedFolder() {
        let existing = [root, "/Users/a/git/shop/.claude/worktrees/a", "/Users/a/git/shop-worktrees/b", "/Users/a/git/shop/.claude/worktrees/c"]
        #expect(WorktreeLocation.automatic.path(for: "x", repositoryRoot: root, existingWorktrees: existing) == "/Users/a/git/shop/.claude/worktrees/x")
        #expect(WorktreeLocation.automatic.path(for: "x", repositoryRoot: root, existingWorktrees: [root]) == "/Users/a/git/shop-worktrees/x")
    }
}

struct LaunchTerminalChoiceTests {
    let everything: Set<LaunchTerminal> = [.ghostty, .iTerm, .terminalApp, .tmux]

    @Test func automaticPrefersWhereAgentsAlreadyRun() {
        #expect(LaunchTerminalChoice.automatic.resolve(agentHosts: [.otherApp, .tmux, .iTerm], available: everything) == .tmux)
        #expect(LaunchTerminalChoice.automatic.resolve(agentHosts: [.iTerm], available: [.ghostty, .terminalApp]) == .ghostty)
        #expect(LaunchTerminalChoice.automatic.resolve(agentHosts: [], available: [.terminalApp, .tmux]) == .terminalApp)
        #expect(LaunchTerminalChoice.automatic.resolve(agentHosts: [], available: [.tmux]) == nil)
    }

    @Test func explicitChoiceNeedsToBeAvailable() {
        #expect(LaunchTerminalChoice.iTerm.resolve(agentHosts: [.ghostty], available: everything) == .iTerm)
        #expect(LaunchTerminalChoice.tmux.resolve(agentHosts: [], available: [.ghostty]) == nil)
    }
}

struct TerminalLaunchScriptTests {
    let folder = #"/Users/a/my "repo""#
    let command = #"claude 'say "hi"'"#

    @Test func ghosttyOpensTabWithFolderAndTypedCommand() throws {
        let script = try #require(TerminalLaunchScript.appleScript(for: .ghostty, folder: folder, command: command))
        #expect(script.contains(#"set initial working directory of config to "/Users/a/my \"repo\"""#))
        #expect(script.contains(#"set initial input of config to "claude 'say \"hi\"'" & linefeed"#))
        #expect(script.contains("new tab in front window with configuration config"))
    }

    @Test func iTermAndTerminalChangeIntoTheFolder() throws {
        let iTerm = try #require(TerminalLaunchScript.appleScript(for: .iTerm, folder: "/r/shop", command: "codex"))
        #expect(iTerm.contains(#"write text "cd '/r/shop' && codex""#))
        let terminal = try #require(TerminalLaunchScript.appleScript(for: .terminalApp, folder: "/r/shop", command: "codex"))
        #expect(terminal.contains(#"do script "cd '/r/shop' && codex""#))
        #expect(TerminalLaunchScript.appleScript(for: .tmux, folder: "/r", command: "x") == nil)
    }

    @Test func tmuxTypesLiterallyThenPressesReturn() {
        #expect(TerminalLaunchScript.tmuxNewWindowArguments(folder: "/r/shop", name: "search") == ["new-window", "-P", "-F", "#{pane_id}\t#{session_name}", "-c", "/r/shop", "-n", "search"])
        let window = TerminalLaunchScript.tmuxNewWindow(fromOutput: "%12\twork session\n")
        #expect(window?.pane == "%12" && window?.session == "work session")
        #expect(TerminalLaunchScript.tmuxNewWindow(fromOutput: "no server running") == nil)
        #expect(TerminalLaunchScript.tmuxTypeArguments(pane: "%4", command: "claude") == [["send-keys", "-t", "%4", "-l", "claude"], ["send-keys", "-t", "%4", "Enter"]])
    }

    @Test func ghosttyFallbackEscapesInput() {
        let arguments = TerminalLaunchScript.ghosttyOpenArguments(folder: "/r", command: #"claude 'a\b'"#)
        #expect(arguments == ["-na", "Ghostty.app", "--args", "--working-directory=/r", #"--input=raw:claude 'a\\b'\n"#])
    }
}

struct AgentLaunchPlannerTests {
    let root = "/r/shop"
    var worktrees: [Worktree] {
        [(root, "main"), ("/r/shop-worktrees/feat-search", "feat/search")].map { path, branch in
            Worktree(repositoryName: "shop", repositoryRoot: root, path: path, branch: branch, isMain: path == root, status: GitStatusSummary(), lastCommitDate: nil, pullRequest: .none)
        }
    }

    func plan(branch: String?, tool: AgentTool = .claude) -> Result<AgentLaunchPlan, AgentLaunchError> {
        AgentLaunchPlanner.plan(tool: tool, repositoryRoot: root, folder: root, newBranch: branch, prompt: "go", worktrees: worktrees, location: .automatic)
    }

    @Test func existingFolderRunsThere() throws {
        let planned = try plan(branch: nil).get()
        #expect(planned.folder == root)
        #expect(planned.command == "claude 'go'")
    }

    @Test func newBranchGoesNextToOtherWorktrees() throws {
        let planned = try plan(branch: " fix/login ").get()
        #expect(planned.target == .newWorktree(branch: "fix/login", path: "/r/shop-worktrees/fix-login"))
    }

    @Test func rejectsBadOrTakenBranches() {
        #expect(throws: AgentLaunchError.branchCheckedOut(path: "/r/shop-worktrees/feat-search")) { try plan(branch: "feat/search").get() }
        #expect(throws: AgentLaunchError.self) { try plan(branch: "bad name").get() }
        #expect(throws: AgentLaunchError.unsupportedTool) { try plan(branch: nil, tool: .aider).get() }
    }
}

struct WorktreeCreatorTests {
    @Test func addsWorktreeForNewAndExistingBranchesInATempRepository() throws {
        guard let git = CommandRunner.locate("git") else { return }
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("flightdeck-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: base) }
        let root = base + "/shop"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        for arguments in [["init", "-q", "-b", "main"], ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "init"], ["branch", "old"]] {
            #expect(CommandRunner.run(git, ["-C", root] + arguments).exitCode == 0)
        }
        let creator = WorktreeCreator(git: git)
        #expect(throws: Never.self) { try creator.create(branch: "feat/new", at: base + "/shop-worktrees/feat-new", in: root).get() }
        #expect(throws: Never.self) { try creator.create(branch: "old", at: base + "/shop-worktrees/old", in: root).get() }
        #expect(throws: AgentLaunchError.folderTaken(path: base + "/shop-worktrees/old")) { try creator.create(branch: "x", at: base + "/shop-worktrees/old", in: root).get() }
        let listed = GitOutputParser.worktreeList(CommandRunner.run(git, ["-C", root, "worktree", "list", "--porcelain"]).output)
        #expect(Set(listed.compactMap(\.branch)) == ["main", "feat/new", "old"])
    }
}
