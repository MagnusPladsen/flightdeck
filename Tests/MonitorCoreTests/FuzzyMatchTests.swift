import Testing
@testable import MonitorCore

struct FuzzyMatchTests {
    @Test func prefixBeatsWordBeatsScattered() {
        let prefix = FuzzyMatch.score("over", in: "Overview")!
        let word = FuzzyMatch.score("view", in: "Go to view")!
        let scattered = FuzzyMatch.score("ovw", in: "Overview")!
        #expect(prefix > word)
        #expect(word > scattered)
    }

    @Test func lettersMustAppearInOrder() {
        #expect(FuzzyMatch.score("wto", in: "Worktrees") == nil)
        #expect(FuzzyMatch.score("wtr", in: "Worktrees") != nil)
        #expect(FuzzyMatch.score("", in: "Anything") == 0)
    }

    @Test func ignoresCaseAndSpaces() {
        #expect(FuzzyMatch.score("NEW AG", in: "New agent…") != nil)
    }
}
