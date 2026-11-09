import Foundation
import MonitorCore

/// Finds the `flightdeck` command shipped with the app and links it into the user's PATH.
enum CommandLineTool {
    /// Inside Flightdeck.app it sits in Contents/Helpers; a `swift build` leaves it next to the app binary.
    static var helperPath: String? {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(CommandLineToolInstaller.commandName)").path
        let built = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("flightdeck-cli").path
        return [bundled, built].compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func install(helper: String) async -> Result<CommandLineToolInstallation, CommandLineToolInstallError> {
        await Task.detached {
            let installer = CommandLineToolInstaller(candidateFolders: CommandLineToolInstaller.standardFolders(home: NSHomeDirectory()), pathEntries: shellPath())
            return Result { () throws(CommandLineToolInstallError) in try installer.install(helper: helper) }
        }.value
    }

    /// The PATH a new terminal gets, which differs from the app's own; markers skip anything the shell profile prints.
    nonisolated static func shellPath() -> [String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let output = CommandRunner.run(shell, ["-ilc", "printf '<path>%s</path>' \"$PATH\""], timeout: 5).output
        guard let start = output.range(of: "<path>"), let end = output.range(of: "</path>", range: start.upperBound..<output.endIndex) else { return [] }
        return output[start.upperBound..<end.lowerBound].split(separator: ":").map(String.init)
    }
}
