import Foundation

/// The last readable lines of a terminal recording: colour codes stripped, carriage-return redraws collapsed.
public enum LogTail {
    private static let escapeSequence = #"\x1B(\[[0-9;?]*[ -/]*[@-~]|\][^\x07\x1B]*(\x07|\x1B\\)|[@-Z\\-_])"#

    public static func lastLines(of text: String, count: Int) -> [String] {
        let plain = text.replacingOccurrences(of: escapeSequence, with: "", options: .regularExpression)
        let lines = plain.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(visibleText(of:))
        return Array(lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.suffix(count))
    }

    /// A line redrawn with `\r` shows only what was written last.
    private static func visibleText(of line: Substring) -> String {
        let redraws = line.split(separator: "\r", omittingEmptySubsequences: true)
        return String(redraws.last ?? "").filter { $0 == "\t" || !($0.asciiValue.map { $0 < 0x20 } ?? false) }
    }
}
