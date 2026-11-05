import MonitorCore
import Testing

struct ChangelogTests {
    private let markdown = """
        # Changelog

        Intro text that isn't a release.

        - Not a release item either.

        ## 1.0.10 — 2026-11-06

        - Tenth.

        ## 1.0.9 — 2026-11-05

        - Ninth, first.
        - Ninth, second.

        ## 1.0.8

        - Eighth.
        """

    @Test func parsesReleasesInFileOrder() {
        let entries = Changelog.parse(markdown)
        #expect(entries.map(\.version) == ["1.0.10", "1.0.9", "1.0.8"])
        #expect(entries[0].date == "2026-11-06")
        #expect(entries[1].items == ["Ninth, first.", "Ninth, second."])
        #expect(entries[2].date == "")
    }

    @Test func picksEntriesSinceLastSeenVersion() {
        let entries = Changelog.parse(markdown)
        #expect(Changelog.entries(entries, after: "1.0.8", through: "1.0.10").map(\.version) == ["1.0.10", "1.0.9"])
        #expect(Changelog.entries(entries, after: "1.0.8", through: "1.0.9").map(\.version) == ["1.0.9"])
        #expect(Changelog.entries(entries, after: "1.0.10", through: "1.0.10").isEmpty)
    }

    @Test func comparesVersionsNumerically() {
        #expect(Changelog.isVersion("1.0.10", newerThan: "1.0.9"))
        #expect(!Changelog.isVersion("1.0.9", newerThan: "1.0.10"))
        #expect(!Changelog.isVersion("1.0.8", newerThan: "1.0.8"))
    }
}
