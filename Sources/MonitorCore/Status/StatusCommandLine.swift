import Foundation

/// The arguments the `flightdeck` command understands.
public enum StatusCommandLine: Equatable, Sendable {
    case status(StatusOutput)
    case help

    public enum StatusOutput: Equatable, Sendable {
        case summary
        case json
        case format(String)
    }

    public static func parse(_ arguments: [String]) throws(StatusCommandLineError) -> StatusCommandLine {
        guard let command = arguments.first else { return .help }
        switch command {
        case "status": return .status(try parseStatusOptions(Array(arguments.dropFirst())))
        case "help", "-h", "--help": return .help
        default: throw .unknownCommand(command)
        }
    }

    static func parseStatusOptions(_ options: [String]) throws(StatusCommandLineError) -> StatusOutput {
        switch options.count {
        case 0: return .summary
        case 1 where options[0] == "--json": return .json
        case 1 where options[0].hasPrefix("--format="): return .format(String(options[0].dropFirst("--format=".count)))
        case 2 where options[0] == "--format": return .format(options[1])
        default: throw .badOptions(options.joined(separator: " "))
        }
    }

    public static let usage = """
    Usage: flightdeck status [--json | --format TEMPLATE]

      flightdeck status                        One line, e.g. "2 working · 1 needs you"
      flightdeck status --json                 The full status as JSON
      flightdeck status --format '{needsYou}/{working}'

    Placeholders: \(StatusFormatter.placeholderNames.map { "{\($0)}" }.joined(separator: " "))
    Exits with 1 when Flightdeck.app isn't running or its status is older than \(Int(StatusFile.staleAfter))s.
    """
}

public enum StatusCommandLineError: Error, Equatable, CustomStringConvertible {
    case unknownCommand(String)
    case badOptions(String)

    public var description: String {
        switch self {
        case .unknownCommand(let command): "Unknown command \"\(command)\"."
        case .badOptions(let options): "Unknown options \"\(options)\"."
        }
    }
}
