import Foundation

public struct CommandResult: Sendable {
    public var exitCode: Int32
    public var output: String
    public var didTimeOut: Bool
}

/// Runs short-lived helper commands (lsof, ss, docker, user widget scripts).
public enum CommandRunner {
    static let searchPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    public static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 5, in directory: String? = nil) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory.map { URL(fileURLWithPath: $0) }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = searchPath + ":" + (environment["PATH"] ?? "")
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, output: "", didTimeOut: false)
        }

        let timeoutItem = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let didTimeOut = !timeoutItem.isCancelled && process.terminationReason == .uncaughtSignal
        timeoutItem.cancel()

        return CommandResult(exitCode: process.terminationStatus, output: String(decoding: data, as: UTF8.self), didTimeOut: didTimeOut)
    }

    /// Runs a user-provided shell snippet, e.g. from a custom widget.
    public static func runShell(_ script: String, timeout: TimeInterval = 10) -> CommandResult {
        run("/bin/sh", ["-c", script], timeout: timeout)
    }

    public static func locate(_ tool: String) -> String? {
        searchPath.split(separator: ":")
            .map { "\($0)/\(tool)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
