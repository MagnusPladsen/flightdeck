import Foundation

/// Scores how well a typed query matches a command's text, for the command palette.
public enum FuzzyMatch {
    /// Nil when the query's letters don't appear in order; higher is better. Whole-word and
    /// prefix hits beat letters scattered through the text.
    public static func score(_ query: String, in text: String) -> Int? {
        let query = query.lowercased().filter { !$0.isWhitespace }
        guard !query.isEmpty else { return 0 }
        let text = text.lowercased()
        if text.hasPrefix(query) { return 1000 - text.count }
        if let range = text.range(of: query) {
            let atWordStart = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            return (atWordStart ? 800 : 600) - text.count
        }
        return subsequenceScore(Array(query), Array(text))
    }

    /// Letters in order, with a bonus for each letter that follows the previous one or starts a word.
    private static func subsequenceScore(_ query: [Character], _ text: [Character]) -> Int? {
        var score = 0
        var queryIndex = 0
        var previousMatch: Int?
        for (index, character) in text.enumerated() where queryIndex < query.count && character == query[queryIndex] {
            if previousMatch == index - 1 { score += 8 }
            if index == 0 || !text[index - 1].isLetter { score += 10 }
            score += 1
            previousMatch = index
            queryIndex += 1
        }
        return queryIndex == query.count ? score : nil
    }
}
