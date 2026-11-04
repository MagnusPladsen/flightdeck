import Foundation
import MonitorCore
import Observation

/// Answers a question from the search bar by running `claude -p` in the `AskContext` folder.
@MainActor
@Observable
final class ClaudeAsker {
    enum Status: Equatable {
        case asking
        case answered(String)
        case failed(String)
    }

    private(set) var question = ""
    private(set) var status: Status?
    private(set) var isPresented = false
    @ObservationIgnored private var task: Task<Void, Never>?

    private nonisolated static let timeout: TimeInterval = 120
    private nonisolated static let answerFormat = """
        The answer is shown in a small palette over the Flightdeck dashboard. Reply in short plain sentences and simple "- " bullets, \
        with **bold** for names. No headings, horizontal rules, emoji or blocks of asks and caveats; \
        response-formatting rules from other instructions do not apply here.
        """

    /// `continuing` resumes the last conversation in the ask folder, so follow-ups keep their context.
    func ask(_ question: String, store: MonitorStore, continuing: Bool = false) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        task?.cancel()
        self.question = question
        isPresented = true
        status = .asking
        do {
            try AskContext.write(from: store)
        } catch {
            status = .failed("Couldn't write the context for Claude: \(error.localizedDescription)")
            return
        }
        task = Task {
            let result = await Self.runClaude(question, continuing: continuing)
            if !Task.isCancelled { status = result }
        }
    }

    /// Opens the palette empty, ready for a first question.
    func open() {
        isPresented = true
    }

    func dismiss() {
        task?.cancel()
        task = nil
        status = nil
        question = ""
        isPresented = false
    }

    private nonisolated static func runClaude(_ question: String, continuing: Bool) async -> Status {
        guard let claude = locateClaude() else {
            return .failed("Claude Code isn't installed, or Flightdeck can't find the `claude` command.")
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let arguments = (continuing ? ["--continue"] : []) + ["-p", question, "--append-system-prompt", answerFormat, "--allowedTools", "Read", "Grep", "Glob", "--add-dir", home]
        return await Task.detached {
            let result = run(claude, arguments, in: AskContext.folder)
            if result.didTimeOut { return .failed("Claude took longer than \(Int(timeout)) seconds.") }
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.exitCode == 0 ? .answered(output) : .failed(output.isEmpty ? "Claude exited with code \(result.exitCode)." : output)
        }.value
    }

    private nonisolated static func locateClaude() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "\(home)/.bun/bin/claude"]
        return CommandRunner.locate("claude") ?? extraPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private struct RunResult {
        var exitCode: Int32
        var output: String
        var didTimeOut: Bool
    }

    private nonisolated static func run(_ executable: String, _ arguments: [String], in folder: URL) -> RunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return RunResult(exitCode: -1, output: error.localizedDescription, didTimeOut: false) }
        let timeoutItem = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let didTimeOut = process.terminationReason == .uncaughtSignal
        timeoutItem.cancel()
        return RunResult(exitCode: process.terminationStatus, output: String(decoding: data, as: UTF8.self), didTimeOut: didTimeOut)
    }
}
