# Office View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A walkable pixel-art office page in the dashboard, built from live agents, dev servers and system stats.

**Architecture:** Pure layout, pathfinding, motion and camera maths live in `MonitorCore/Office` and are unit
tested. The app draws them with a SwiftUI `Canvas` in a `TimelineView`, with a main-actor `OfficeGame` stepped by a
task loop only while the page is visible. Overlays (needs-you posts, agent card, tooltip) are SwiftUI views.

**Tech Stack:** Swift 6 toolchain (language mode 5), SwiftUI on macOS 14, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-06-office-view-design.md`

## Global Constraints

- Original art only; the needs-you post is a generic social-post card with no real app's branding.
- Functions under 30 lines, self-documenting names, no TODOs.
- Don't touch `README.md`, `site/`, `VERSION`, `CHANGELOG.md`. Don't push.
- Stats are world objects with hover tooltips, never a HUD.
- The game loop runs only while the Office page is on screen.

## Review Focus

1. Office with no agents and no ports: closet and hallway still render and the player can walk (test: `emptyOfficeHasWalkableHallway`).
2. State-only refresh must not move desks (test: `layoutIgnoresAgentStates`).
3. Every agent's approach tile is reachable from the player start (test: `everyDeskIsReachable`).
4. Agent with no project still gets a room (test: `agentWithoutProjectGetsFolderRoom`).
5. Movement into walls slides instead of passing through (test: `motionSlidesAlongWalls`).

---

### Task 1: Office model (MonitorCore)

**Files:**
- Create: `Sources/MonitorCore/Office/OfficeGeometry.swift` (`OfficePoint`, `TilePoint`, `TileRect`, `OfficeTile`, `OfficeGrid`)
- Create: `Sources/MonitorCore/Office/OfficeMap.swift` (`OfficeMap`, `OfficeRoom`, `OfficeCubicle`, `OfficeDesk`, `OfficeRack`, `OfficeObject`, `OfficeMap.build`)
- Create: `Sources/MonitorCore/Office/OfficeNavigation.swift` (`OfficePathfinder`, `OfficeMotion`, `OfficeCamera`)
- Create: `Sources/MonitorCore/Office/OfficeAgents.swift` (`OfficePose`, `IdleThoughts`, `NeedsYouFeed`)
- Test: `Tests/MonitorCoreTests/OfficeTests.swift`

**Interfaces (produces):**
- `OfficeMap.build(agents: [AgentSession], ports: [ListeningPort]) -> OfficeMap`
- `OfficeMap.object(at: OfficePoint) -> OfficeObject?`; `OfficeObject = .agent(Int32) | .rack(ListeningPort) | .cpuRack | .waterCooler | .wallClock`
- `OfficePathfinder.path(in: OfficeGrid, from: TilePoint, to: TilePoint) -> [TilePoint]?`
- `OfficeMotion.move(_ position: OfficePoint, by delta: OfficePoint, in grid: OfficeGrid) -> OfficePoint`
- `OfficeCamera(mapSize:viewSize:focus:)` with `scale: CGFloat`, `origin: CGPoint`
- `OfficePose(state: AgentState)`: `.typing, .relaxed, .impatient, .puzzled, .phone`, `isStanding`
- `IdleThoughts.line(for pid: Int32, at date: Date) -> String` (rotates every 8 s)
- `NeedsYouFeed.agents(in: [AgentSession]) -> [AgentSession]` (needsApproval + possiblyStuck, newest first)

**Layout values:** 16-pixel tiles; room interior 4 rows (racks, seat, desk, aisle) with a walkway column on each
side; desk slot 3 tiles wide; partitions between cubicles on the first three rows; hallway 3 rows; closet at the
left of the upper row with the CPU rack and project-less ports; rooms alphabetical, alternating upper and lower.

- [ ] Write the tests listed in Review Focus plus grouping (repo room, checkout cubicles, shared cubicle), ports in their cubicle, project-less ports in the closet, alphabetical alternation, pathfinder shortest path and blocked target, pose mapping, feed filtering, idle line rotation, camera centring and clamping, `object(at:)` for a rack and an agent.
- [ ] Run `swift test --filter OfficeTests`; expect failures (types missing).
- [ ] Implement the four files.
- [ ] Run `swift test`; expect all pass.
- [ ] Commit.

### Task 2: Sprites and renderer (FlightdeckApp)

**Files:**
- Create: `Sources/FlightdeckApp/Views/Office/PixelSprite.swift` (string-grid sprites → cached `CGImage`)
- Create: `Sources/FlightdeckApp/Views/Office/OfficeCharacters.swift` (pose sprites, player sprite, tool shirt colours, pid-based skin/hair)
- Create: `Sources/FlightdeckApp/Views/Office/OfficeRenderer.swift` (tiles, furniture, stat objects, agents, bubbles, player, painter's order by y)

**Interfaces:** consumes Task 1; produces `OfficeRenderer.draw(in: inout GraphicsContext, scene: OfficeScene, camera: OfficeCamera, date: Date)` where `OfficeScene` bundles map, agents by pid, snapshot, limits windows, player position and focused pid.

- [ ] Implement; build with `swift build`.
- [ ] Commit.

### Task 3: Office page, game loop and overlays

**Files:**
- Create: `Sources/FlightdeckApp/Views/Office/OfficeGame.swift` (`@Observable` player, held keys, path, tick)
- Create: `Sources/FlightdeckApp/Views/Office/OfficePage.swift` (canvas, focus, keys, click, hover)
- Create: `Sources/FlightdeckApp/Views/Office/OfficeOverlays.swift` (`NeedsYouPost`, `OfficeAgentCard`, `OfficeTooltip`, hint line)

- [ ] Implement; `swift build`.
- [ ] Commit.

### Task 4: Navigation

**Files:**
- Modify: `DashboardNavigation.swift` (`.office`, `showOffice()`), `DashboardView.swift` (detail, title, Visualize toolbar button hidden on Office), `PageListSidebar.swift`, `RailSidebar.swift` (Office button above Settings).

- [ ] Implement; `swift build && swift test`.
- [ ] Run the demo, screenshot the Office page, walk to an agent, screenshot the card.
- [ ] Commit.
