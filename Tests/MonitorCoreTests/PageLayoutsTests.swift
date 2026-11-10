import Foundation
import Testing
@testable import MonitorCore

struct PageLayoutsTests {
    private let base = PageLayouts(pages: [
        .overview: [SectionPlacement(kind: .needsYou), SectionPlacement(kind: .workingAgents), SectionPlacement(kind: .idleAgents)],
        .agents: [SectionPlacement(kind: .agentSessions)],
    ])

    @Test func rowsWrapWhenTheNextSpanDoesNotFit() {
        #expect(GridPacking.rows(spans: [12, 6, 6, 8, 6, 4]) == [[0], [1, 2], [3], [4, 5]])
    }

    @Test func spansSnapToAllowedSteps() {
        #expect(GridPacking.snapped(5) == 4)
        #expect(GridPacking.snapped(7) == 6)
        #expect(GridPacking.snapped(11) == 12)
        #expect(SectionPlacement(kind: .projects, span: 2).span == 3)
    }

    @Test func moveKeepsSpanAndInsertsBeforeTarget() {
        var layouts = base
        layouts.move(.idleAgents, to: .agents, before: .agentSessions)
        #expect(layouts.placements(on: .agents).map(\.kind) == [.idleAgents, .agentSessions])
        #expect(layouts.placements(on: .agents).first?.span == 6)
        #expect(layouts.page(containing: .idleAgents) == .agents)
    }

    @Test func hideThenMoveBringsASectionBack() {
        var layouts = base
        layouts.hide(.needsYou)
        #expect(layouts.page(containing: .needsYou) == nil)
        #expect(layouts.hidden == [.needsYou])
        layouts.move(.needsYou, to: .overview)
        #expect(layouts.hidden.isEmpty)
        #expect(layouts.placements(on: .overview).last?.kind == .needsYou)
    }

    @Test func resizeSnaps() {
        var layouts = base
        layouts.resize(.workingAgents, span: 9)
        #expect(layouts.placements(on: .overview)[1].span == 8)
    }

    @Test func sanitizeDropsRemovedWidgetsAndPlacesNewOnes() {
        let removed = UUID(), added = UUID()
        var layouts = base
        layouts.pages[.widgets] = [SectionPlacement(kind: .widget(removed))]
        layouts.hide(.agentSessions)
        let clean = layouts.sanitized(available: [.needsYou, .workingAgents, .idleAgents, .agentSessions, .projects, .widget(added)])
        #expect(clean.placements(on: .widgets).map(\.kind) == [.widget(added)])
        #expect(clean.hidden == [.agentSessions])
        #expect(clean.placements(on: .overview).map(\.kind) == [.needsYou, .workingAgents, .idleAgents, .projects])
    }

    @Test func sanitizePlacesNowPlayingRightAfterResourcesInSavedLayouts() {
        var layouts = base
        layouts.pages[.overview]?.insert(SectionPlacement(kind: .resources), at: 1)
        layouts.move(.resources, to: .agents, before: .agentSessions)
        let clean = layouts.sanitized(available: [.needsYou, .workingAgents, .idleAgents, .resources, .agentSessions, .nowPlaying])
        #expect(clean.placements(on: .agents).map(\.kind) == [.resources, .nowPlaying, .agentSessions])
    }

    @Test func sanitizePutsNowPlayingOnTheOverviewWhenResourcesAreHidden() {
        var layouts = base
        layouts.hide(.resources)
        let clean = layouts.sanitized(available: [.needsYou, .workingAgents, .idleAgents, .resources, .agentSessions, .nowPlaying])
        #expect(clean.placements(on: .overview).last?.kind == .nowPlaying)
    }

    @Test func sanitizeAddsTheDailyRecapToTheAgentsPageOfSavedLayouts() {
        let clean = base.sanitized(available: [.needsYou, .workingAgents, .idleAgents, .agentSessions, .dailyRecap])
        #expect(clean.placements(on: .agents).map(\.kind) == [.agentSessions, .dailyRecap])
        #expect(clean.placements(on: .agents).last?.span == GridPacking.columns)
    }

    @Test func sanitizePutsPortsBetweenIdleAgentsAndProjects() {
        let clean = base.sanitized(available: [.needsYou, .workingAgents, .idleAgents, .agentSessions, .projects, .portSummary])
        #expect(clean.placements(on: .overview).map(\.kind) == [.needsYou, .workingAgents, .idleAgents, .portSummary, .projects])
    }

    @Test func sanitizeHidesPortsWhenTheOverviewAlreadyListsDevServers() {
        var layouts = base
        layouts.move(.devServers, to: .overview)
        let clean = layouts.sanitized(available: [.needsYou, .workingAgents, .idleAgents, .agentSessions, .projects, .devServers, .portSummary])
        #expect(!clean.placements(on: .overview).contains { $0.kind == .portSummary })
        #expect(clean.hidden.contains(.portSummary))
    }

    @Test func roundTripsThroughJSON() throws {
        var layouts = base
        layouts.pages[.widgets] = [SectionPlacement(kind: .widget(UUID()))]
        layouts.hide(.agentSessions)
        let decoded = try JSONDecoder().decode(PageLayouts.self, from: JSONEncoder().encode(layouts))
        #expect(decoded == layouts)
    }

    @Test func tokensRoundTripForEveryKind() {
        let kinds = SectionKind.builtIn + [.widget(UUID())]
        for kind in kinds {
            #expect(SectionKind(token: kind.token) == kind)
        }
        #expect(SectionKind(token: "nonsense") == nil)
    }
}
