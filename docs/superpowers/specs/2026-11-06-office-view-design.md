# Office view: design

## Intent

A playful, glanceable way to see what every AI agent is doing. The dashboard already lists agents, servers and
resources; the office shows the same live data as a small walkable pixel-art office. You walk a character around,
see who is busy, who is scrolling their phone, and who is tapping their foot waiting for you, then open that
agent's terminal from right there.

Success: you open the Office page, and in a few seconds know which projects are active, which agent needs you, and
roughly how loaded the machine is, without reading a single list. It should feel like a toy that is also useful.

## Goals

- Built from live `MonitorStore` data (`agents`, `ports`, `snapshot`, `usage`), with the demo-mode data driving it
  under `FLIGHTDECK_DEMO=1`.
- Every agent can be opened (Go to terminal) and stopped (Stop, with the existing confirmation) from the office.
- System stats are part of the world, never a HUD overlay. Every stat object explains itself on hover.

## Non-goals

- No game mechanics beyond walking and interacting (no score, no quests, no NPC pathing between rooms).
- No sound.
- No approve or deny from the office (deliberately rejected for the app as a whole).
- No persistence of the player's position between launches.

## Anti-goals

- Art or characters that copy an existing game, or a notification that copies a real social app's branding.
- Stats drawn as bars or numbers floating over the scene.
- A view that burns CPU while hidden: the game loop only runs while the page is on screen.

## Decisions made with Magnus

| Topic | Decision |
|---|---|
| Art | Original pixel art drawn in SwiftUI `Canvas` (no SpriteKit). |
| Controls | Both: WASD/arrow keys walk; clicking a spot or an object walks there. |
| Placement | A dashboard destination ("Office") in both sidebars, plus a **Visualize** toolbar button on every page that jumps there. |
| Rooms | One room per repository (`DevProject.name`). Inside a room, each checkout (main checkout or worktree, keyed by `rootPath`) gets its own **cubicle** separated by low partition walls. Agents in the same checkout share the cubicle. |
| Dev servers | Each dev server is a small server rack **inside the cubicle of the checkout it runs in**. Hover shows the port. |
| CPU | A big server rack in a shared server closet; LED blink speed and colour follow total CPU. Hover shows CPU %. |
| Memory | A water cooler in the hallway; water level is used memory, it bubbles/drips under pressure. Hover shows used/total and pressure. |
| Limits | A wall clock with a battery-style gauge in the hallway, showing usage-limit headroom of `store.limitsAgent`. Hover shows each window's used % and reset time. |
| Needs-you post | Pops for **Needs approval** and **Possibly stuck** agents. Those agents stand up and look impatient. |
| Agent card | Go to terminal + Stop (Stop keeps its confirmation dialog). |

## How it looks and behaves

### World layout

- A tile grid (16 px tiles, drawn at an integer scale that fits the view, minimum 2x; the camera follows the player
  if the map is bigger than the view).
- A horizontal **hallway** runs across the map. Project rooms sit above and below it, each with a door opening onto
  the hallway and a name plate (repo name) on its wall.
- The hallway's left end is a **server closet** (CPU rack, plus racks for ports that have no checkout, e.g. Docker
  containers). The hallway holds the **water cooler** and the **wall clock/battery**.
- A room's width grows with its cubicle count; cubicles are laid out left to right. A cubicle has one desk per agent
  (capped, extra agents stand) and its dev-server racks along the back wall. A label on the partition shows the
  branch (main checkout) or worktree name.
- Room order: alphabetical by repo name, alternating above and below the hallway so the map stays roughly half as
  wide. *(Builder's call: not ordered by state, so rooms don't shuffle while you walk; the layout only changes when
  a project or checkout appears or disappears. The needs-you posts point you to the right room instead.)*
- Projects with only dev servers and no agents still get a room (racks, empty desk).
- *(Builder's call)* Agents with no project get a room named after their folder (`displayName`), so every agent is
  reachable. Rooms key on `DevProject.name`; two different repos with the same folder name share a room (rare,
  accepted).
- *(Builder's call)* No cap on rooms or cubicles; the camera follows the player. After a re-layout, a player left
  inside a wall is moved to the nearest walkable tile, and an open card closes if its agent is gone.

### Agents (characters)

Original pixel characters, shirt colour by tool (Claude, Codex, others), small per-pid variation (hair/skin) so two
agents in one cubicle look different.

| State | Pose | Bubble |
|---|---|---|
| Working | Sitting, typing animation | Thought bubble with `actionLine` (verb + detail, truncated) |
| Your turn | Sitting back, arms behind head | Speech bubble with its last line (`actionLine`) |
| Needs approval | Standing by the desk, foot tapping, looking around | "!" bubble + "Waiting for your approval" |
| Possibly stuck | Standing, scratching head, little sweat drop | "?" bubble + `stuckReason.summary` |
| Idle | Sitting, looking down at a phone, thumb scrolling | Rotating funny "scrolling short videos" thought lines |

Idle thought lines: a fixed list of original, light jokes (e.g. "one more video…", "a cat learned to open
doors?!", "why am I watching a man fix a lawnmower"). Each idle agent picks one by pid and rotates every ~8 s.

Bubbles show for the nearest agents and hovered ones; when the player is far away, bubbles shrink to an icon so a
full office stays readable.

### The player

A distinct original character. WASD/arrows walk with wall collision; clicking a floor tile or an object walks
there along a tile path (A* on the walkable grid). Starts in the hallway by the door. Keyboard focus is taken when
the page appears.

### Interacting

- Walking next to an agent (or clicking it) opens its **agent card** floating by the character: tool, project,
  checkout label, state, action line, `resourceText`, and the Go to terminal and Stop buttons (`AgentControlButtons`).
  Space/Return triggers Go to terminal while the card is open; Escape closes it.
- Hovering any object (agent, rack, water cooler, clock, CPU rack) shows a small tooltip. Dev-server rack: port,
  framework, branch/worktree. Clicking a dev-server rack opens `localhost:<port>` in the browser (via
  `store.openInBrowser`).

### Needs-you post

A generic social-post card in the top-left of the office view: round avatar (the agent's pixel face), name
("Claude Code · storefront"), a relative time, and the body ("Waiting for your approval: bun run db:migrate" or
"Possibly stuck: Same Bash call 4 times in a row"). Neutral styling from the app theme, no real app's branding.
It slides in when an agent enters one of those states, stacks up to three, and has a "Walk there" button that
auto-walks the player to the agent and opens its card on arrival; it disappears when the agent leaves the state.
*(Builder's calls: the relative time is from `lastActivity`; beyond three posts a "+N more" line shows; agent
identity is the pid.)*

### Stat objects

- **CPU rack** (closet): LEDs blink at a rate proportional to `snapshot.cpu.total`; green under 50 %, amber under
  80 %, red above. Hover: "CPU 34% · load 4.2".
- **Water cooler**: water level = `memory.usedFraction`; bubbles under `.warning`, drips under `.critical`. Hover:
  "Memory 22 GB of 36 GB · pressure normal".
- **Wall clock/battery**: clock shows the local time; the battery beside it shows the remaining headroom of the
  most-used window of `store.limitsAgent` (100 − usedPercent). Hover: each window's "5h 42% · resets in 2h 24m".
  Hidden if no limits data.
- **Dev-server racks**: one lit rack per port in the cubicle; blinking activity light.

## Architecture

- **MonitorCore/Office** (pure, tested): `OfficeMap` builds rooms, cubicles, desks, racks, stat-object positions and
  a walkable grid from `[AgentSession]` and `[ListeningPort]`; `OfficePathfinder` (A* on the grid);
  `OfficeAgentPose` maps `AgentState` to pose; `IdleThoughts` picks lines; `NeedsYouFeed` decides which agents get a
  post. Tests in `Tests/MonitorCoreTests/OfficeTests.swift`.
- **FlightdeckApp/Views/Office**: `OfficePage` (layout, focus, keys, hover, overlays), an `@Observable OfficeGame`
  (player position, held keys, path, selected agent) stepped by a main-actor loop only while the page is visible,
  `OfficeRenderer` (Canvas drawing), `PixelSprites` (sprites defined as character grids + palettes),
  `NeedsYouPost`, `OfficeAgentCard`, `OfficeTooltip`.
- `DashboardDestination` gets `.office`; `PageListSidebar` and `RailSidebar` get an Office button beside Settings;
  the dashboard toolbar gets a Visualize button. `DashboardPage` and `PageLayouts` are not touched, since the office
  has no sections.

*(Builder's calls)* The Visualize button is hidden while the Office is shown. Movement keys are handled only while
the office canvas has focus, so they never fight text fields or app shortcuts. Verification is the MonitorCore unit
tests plus screenshots of the demo app.

## Left to the builder

Exact sprite designs and palettes, tile dimensions of rooms and furniture, animation timings, idle joke wording,
bubble truncation lengths, and where the agent card sits relative to the character.
