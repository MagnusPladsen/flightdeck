import Foundation
import MonitorCore

let usageExitCode: Int32 = 64
let unavailableExitCode: Int32 = 1

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func render(_ output: StatusCommandLine.StatusOutput, of report: StatusReport) throws -> String {
    switch output {
    case .summary: return StatusFormatter.summary(report)
    case .json: return String(decoding: try StatusFile.encode(report), as: UTF8.self)
    case .format(let template): return StatusFormatter.format(template, report: report)
    }
}

func runStatus(_ output: StatusCommandLine.StatusOutput) -> Int32 {
    do {
        let report = try StatusFile.read(from: StatusFile.defaultURL)
        print(try render(output, of: report))
        return 0
    } catch {
        printError("\(error)")
        return unavailableExitCode
    }
}

func run(_ arguments: [String]) -> Int32 {
    do {
        switch try StatusCommandLine.parse(arguments) {
        case .help:
            print(StatusCommandLine.usage)
            return 0
        case .status(let output):
            return runStatus(output)
        }
    } catch {
        printError("\(error)\n\n\(StatusCommandLine.usage)")
        return usageExitCode
    }
}

exit(run(Array(CommandLine.arguments.dropFirst())))
